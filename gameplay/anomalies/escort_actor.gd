extends CharacterBody3D
## Deterministic distance keeper. Collision-safe steering and room-only path
## planning are independent of the authored skeletal animation system.
const Rig = preload("res://gameplay/anomalies/escort_rig.gd")
enum State { WAIT, APPROACH, OBSERVE, RETREAT }
const NEAR := 2.25
const FAR := 2.95
const TARGET := 2.60
const WALK := 1.65
const MAX_RETREAT := 4.6
const ACCEL := 8.0
var state: State = State.WAIT
var hall: Node3D
var rig: Node3D
var agent: NavigationAgent3D
var nav_map: RID
var nav_region: NavigationRegion3D
var nav_mesh: NavigationMesh
var nav_ready := false
var nav_requested := false
var positioned := false
var noticed_time := 0.0
var path_clock := 0.0
var target_position := Vector3.ZERO
var last_motion := Vector3.ZERO
var sidestep := 1.0
var capsule: CollisionShape3D

func configure(room: Node3D) -> bool:
    hall = room
    # The west aisle is the far end of the long casino corridor.
    position = Vector3(-40.2,0.035,-6.3)
    rotation.y = PI*0.5
    collision_layer = 0
    collision_mask = 1
    floor_snap_length = 0.22
    capsule = CollisionShape3D.new()
    var shape: CapsuleShape3D = CapsuleShape3D.new()
    shape.radius = 0.30
    shape.height = 1.79
    capsule.shape = shape
    capsule.position.y = 0.91
    add_child(capsule)
    rig = Rig.new()
    rig.name = "AnimatedGuard"
    add_child(rig)
    if not bool(rig.call("configure")):
        return false
    agent = NavigationAgent3D.new()
    agent.name = "EscortNavigation"
    agent.path_desired_distance = 0.40
    agent.target_desired_distance = 0.55
    agent.radius = 0.35
    agent.height = 1.8
    add_child(agent)
    # Each streamed room is a separate navigation world.
    nav_map = NavigationServer3D.map_create()
    NavigationServer3D.map_set_active(nav_map,true)
    agent.set_navigation_map(nav_map)
    hide()
    set_physics_process(true)
    return true

func _player() -> CharacterBody3D:
    return hall.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(hall) else null

func _plan_navigation() -> void:
    if nav_requested:
        return
    nav_requested = true
    nav_mesh = NavigationMesh.new()
    nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
    nav_mesh.geometry_collision_mask = 1
    nav_mesh.agent_radius = 0.36
    nav_mesh.agent_height = 1.80
    nav_mesh.agent_max_climb = 0.18
    nav_mesh.cell_size = 0.25
    nav_mesh.cell_height = 0.15
    var geometry: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
    NavigationServer3D.parse_source_geometry_data(nav_mesh,geometry,hall)
    if geometry.has_data():
        NavigationServer3D.bake_from_source_geometry_data_async(nav_mesh,geometry,_navigation_baked)

func _navigation_baked() -> void:
    if not is_inside_tree() or not is_instance_valid(hall) or not nav_map.is_valid() or nav_mesh.get_polygon_count() == 0:
        return
    nav_region = NavigationRegion3D.new()
    nav_region.name = "EscortRoomNavigation"
    nav_region.navigation_mesh = nav_mesh
    hall.add_child(nav_region)
    nav_region.set_navigation_map(nav_map)
    nav_ready = true

func _flat(v: Vector3) -> Vector3:
    return Vector3(v.x,0.0,v.z)

func _inside_room(point: Vector3) -> bool:
    # Do not follow through streamed exit gates or into the next hall.
    var p: Vector3 = hall.to_local(point)
    return p.x > -45.0 and p.x < 5.0 and p.z > -12.0 and p.z < 13.6

func _has_floor(point: Vector3) -> bool:
    var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.55,point-Vector3.UP*0.45,1)
    var excluded: Array[RID] = [get_rid()]
    var p: CharacterBody3D = _player()
    if p != null:
        excluded.append(p.get_rid())
    ray.exclude = excluded
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
    return not hit.is_empty() and (hit["normal"] as Vector3).y > 0.7

func _place_initial() -> bool:
    for point in [Vector3(-40.2,0.035,-6.3),Vector3(-38.0,0.035,-6.0),Vector3(-36.0,0.035,-6.6),Vector3(-32.0,0.035,-6.3)]:
        var local: Vector3 = point
        var world_point: Vector3 = hall.to_global(local)
        var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
        query.shape = capsule.shape
        query.transform = Transform3D(Basis.IDENTITY,world_point+Vector3.UP*0.94)
        query.collision_mask = 1
        query.exclude = [get_rid()]
        if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty() and _has_floor(world_point):
            global_position = world_point
            show()
            positioned = true
            return true
    return false

func _visible_to_player(p: CharacterBody3D) -> bool:
    var camera: Camera3D = p.get_node_or_null("Camera3D") as Camera3D
    if camera == null:
        return false
    var chest: Vector3 = global_position+Vector3.UP*1.35
    if not camera.is_position_in_frustum(chest):
        return false
    var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position,chest,1)
    ray.exclude = [p.get_rid(),get_rid()]
    return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func distance_state(distance: float, previous: State) -> State:
    # Hysteresis: close the gap to TARGET, not just the entry threshold.
    if previous == State.APPROACH and distance > TARGET:
        return State.APPROACH
    if previous == State.RETREAT and distance < TARGET:
        return State.RETREAT
    if distance > FAR:
        return State.APPROACH
    if distance < NEAR:
        return State.RETREAT
    return State.OBSERVE

func _direction_clear(direction: Vector3, distance: float) -> bool:
    if direction.length_squared() < 0.0001:
        return false
    var ahead: Vector3 = global_position+direction*distance
    return _inside_room(ahead) and _has_floor(ahead) and not test_move(global_transform,direction*distance)

func _steer(desired: Vector3, away: Vector3, retreating: bool) -> Vector3:
    if desired.length_squared() < 0.0001:
        return Vector3.ZERO
    # Probe real collision shapes, with a stable preferred side. A retreat
    # never chooses a heading toward the player, even when cornered.
    for degrees in [0.0,30.0,-30.0,60.0,-60.0,90.0,-90.0]:
        var angle: float = deg_to_rad(float(degrees)*sidestep)
        var candidate: Vector3 = desired.rotated(Vector3.UP,angle)
        if retreating and candidate.dot(away) < -0.025:
            continue
        if _direction_clear(candidate,0.65):
            return candidate
    return Vector3.ZERO

func _path_direction(desired: Vector3, destination: Vector3, delta: float) -> Vector3:
    if not nav_ready or NavigationServer3D.map_get_iteration_id(nav_map) == 0:
        return desired
    path_clock -= delta
    if path_clock <= 0.0:
        path_clock = 0.22
        target_position = NavigationServer3D.map_get_closest_point(nav_map,destination)
        if target_position.distance_to(destination) < 3.0:
            agent.target_position = target_position
    if agent.is_navigation_finished():
        return desired
    var next: Vector3 = _flat(agent.get_next_path_position()-global_position)
    return next.normalized() if next.length() > 0.10 else desired

func _physics_process(delta: float) -> void:
    if not is_instance_valid(hall) or hall.has_meta("_streaming_standby"):
        velocity = Vector3.ZERO
        return
    var p: CharacterBody3D = _player()
    if p == null:
        return
    if not positioned and not _place_initial():
        return
    if not nav_requested:
        call_deferred("_plan_navigation")
    var offset: Vector3 = _flat(p.global_position-global_position)
    var distance: float = offset.length()
    var toward: Vector3 = offset.normalized() if distance > 0.001 else Vector3.BACK.rotated(Vector3.UP,global_rotation.y)
    var away: Vector3 = -toward
    # +Z is the verified original Security Guard's forward axis.
    global_rotation.y = lerp_angle(global_rotation.y,atan2(toward.x,toward.z),minf(delta*7.0,1.0))
    if state == State.WAIT:
        if _visible_to_player(p) or distance < 3.5:
            noticed_time += delta
            if noticed_time >= 0.5:
                state = distance_state(distance,State.OBSERVE)
        else:
            noticed_time = 0.0
    else:
        state = distance_state(distance,state)
    var desired: Vector3 = Vector3.ZERO
    var speed: float = 0.0
    if state == State.APPROACH:
        desired = toward
        speed = minf(WALK,maxf(0.0,(distance-TARGET)*2.2))
        if not _direction_clear(desired,0.65):
            desired = _path_direction(desired,p.global_position,delta)
    elif state == State.RETREAT:
        desired = away
        var closing: float = maxf(0.0,_flat(p.velocity).dot(away))
        speed = clampf((TARGET-distance)*2.8+closing,0.0,MAX_RETREAT)
        if not _direction_clear(desired,0.65):
            desired = _path_direction(desired,global_position+away*3.0,delta)
            if desired.dot(away) < 0.0:
                desired = away
    if desired.length_squared() > 0.0001:
        desired = _steer(desired,away,state == State.RETREAT)
    var planar: Vector3 = _flat(velocity).move_toward(desired*speed,ACCEL*delta)
    if state == State.OBSERVE or state == State.WAIT:
        planar = planar.move_toward(Vector3.ZERO,ACCEL*delta)
    velocity = planar + Vector3.UP*(0.0 if is_on_floor() else velocity.y-18.0*delta)
    move_and_slide()
    last_motion = _flat(get_real_velocity())
    var facing: Vector3 = global_basis.z.normalized()
    var signed_speed: float = last_motion.length() * (-1.0 if last_motion.dot(facing)<0.0 else 1.0)
    rig.call("drive",signed_speed,delta)

func _exit_tree() -> void:
    if is_instance_valid(nav_region):
        nav_region.set_navigation_map(RID())
        nav_region.queue_free()
    if nav_map.is_valid():
        NavigationServer3D.free_rid(nav_map)
        nav_map = RID()
