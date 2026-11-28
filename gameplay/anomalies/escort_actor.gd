extends CharacterBody3D
## Deterministic distance keeper. Collision-safe steering and room-only path
## planning are independent of the authored skeletal animation system.
const Rig = preload("res://gameplay/anomalies/escort_rig.gd")
enum State { WAIT, APPROACH, OBSERVE, RETREAT, ESCAPE }
const NEAR := 2.25
const FAR := 2.95
const TARGET := 2.60
const WALK := 1.25
const MAX_FOLLOW := 6.3
# Reversed formal walk has a finite believable cadence. Faster evasive
# movement uses a forward jog, never a sped-up backwards glide.
const MAX_RETREAT := 2.20
const MAX_ESCAPE := 5.8
const ACCEL := 8.0
const PLAYER_CLEARANCE := 0.86
const SPRINT_CLOSING := 4.5
const ESCAPE_REPLAN := 0.35
const ESCAPE_MIN_TIME := 0.45
# Recast previously rounded 0.36 m clearance up to 2 cells and
# 0.18 m climb down to 1 cell. Declare those effective dimensions.
const NAV_CELL_SIZE := 0.25
const NAV_CELL_HEIGHT := 0.15
const NAV_RADIUS := 2.0 * NAV_CELL_SIZE
const NAV_CLIMB := NAV_CELL_HEIGHT
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
var escape_path := PackedVector3Array()
var escape_cursor := 0
var escape_clock := 0.0
var escape_age := 0.0
var escape_start := Vector3.ZERO
var stuck_time := 0.0
var requested_motion := Vector3.ZERO
var signed_motion_speed := 0.0

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
    NavigationServer3D.map_set_cell_size(nav_map, NAV_CELL_SIZE)
    NavigationServer3D.map_set_cell_height(nav_map, NAV_CELL_HEIGHT)
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
    nav_mesh.cell_size = NAV_CELL_SIZE
    nav_mesh.cell_height = NAV_CELL_HEIGHT
    nav_mesh.agent_radius = NAV_RADIUS
    nav_mesh.agent_height = 1.80
    nav_mesh.agent_max_climb = NAV_CLIMB
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
    # Select the private map before entering the tree so the region is
    # never briefly registered against the default world map.
    nav_region.set_navigation_map(nav_map)
    # Parent ownership is the actor; top-level transform keeps the mesh
    # fixed in room space even when the character walks.
    add_child(nav_region)
    nav_region.top_level = true
    nav_region.global_transform = hall.global_transform
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
    # get_next_path_position updates the agent's internal path every frame.
    var next: Vector3 = _flat(agent.get_next_path_position()-global_position)
    if agent.is_navigation_finished():
        return desired
    return next.normalized() if next.length() > 0.10 else desired

func _distance_to_segment(point: Vector3, start: Vector3, finish: Vector3) -> float:
    var segment: Vector3 = _flat(finish-start)
    if segment.length_squared() < 0.0001:
        return _flat(point-start).length()
    var fraction: float = clampf(_flat(point-start).dot(segment)/segment.length_squared(),0.0,1.0)
    return _flat(point-start-segment*fraction).length()

func _safe_segment(start: Vector3, finish: Vector3, player_position: Vector3) -> bool:
    # If already too close, permit a route that does not worsen the gap.
    var start_gap: float = _flat(player_position-start).length()
    var allowed: float = minf(PLAYER_CLEARANCE,maxf(0.10,start_gap-0.025))
    return _distance_to_segment(player_position,start,finish) >= allowed

func _begin_escape() -> void:
    if state == State.ESCAPE:
        return
    state = State.ESCAPE
    escape_age = 0.0
    escape_clock = 0.0
    escape_start = global_position
    escape_path.clear()
    escape_cursor = 0

func _escape_route(player_position: Vector3, away: Vector3) -> void:
    # Search a wider fan than normal backpedalling. The player is not an
    # infinite wall: a sideways/partly forward route is valid if it avoids
    # the player and the actual environment. Commit to the selected route
    # until blocked or reached, instead of oscillating left/right.
    var best := PackedVector3Array()
    var best_score: float = -INF
    var has_map: bool = nav_ready and NavigationServer3D.map_get_iteration_id(nav_map)>0
    var start: Vector3 = global_position
    for degrees in [0.0,35.0,-35.0,70.0,-70.0,105.0,-105.0,140.0,-140.0,180.0]:
        var direction: Vector3 = away.rotated(Vector3.UP,deg_to_rad(float(degrees)*sidestep))
        for reach in [3.0,1.35,0.55]:
            var goal: Vector3 = start+direction*float(reach)
            if not _inside_room(goal):
                continue
            var route := PackedVector3Array()
            if _direction_clear(direction,float(reach)):
                route = PackedVector3Array([start,goal])
            elif has_map and float(reach)>1.0:
                var projected: Vector3 = NavigationServer3D.map_get_closest_point(nav_map,goal)
                if _flat(projected-goal).length()>0.85 or not _inside_room(projected):
                    continue
                route = NavigationServer3D.map_get_path(nav_map,start,projected,true)
            if route.size()<2:
                continue
            var first: Vector3 = Vector3.ZERO
            var previous: Vector3 = start
            var length: float = 0.0
            var safe: bool = true
            for waypoint in route:
                var point: Vector3 = waypoint
                var leg: Vector3 = _flat(point-previous)
                if leg.length()<0.08:
                    continue
                if not _inside_room(point) or not _safe_segment(previous,point,player_position):
                    safe = false
                    break
                if first.is_zero_approx():
                    first = leg.normalized()
                    if not _direction_clear(first,minf(0.42,leg.length())):
                        safe = false
                        break
                length += leg.length()
                previous = point
            if not safe or first.is_zero_approx() or length<0.30:
                continue
            var end_gap: float = _flat(previous-player_position).length()
            # Prefer a useful exit over a short shuffle against the wall,
            # but accept a short lateral step when that is the only opening.
            var score: float = minf(end_gap,5.0)*1.6 + minf(length,3.0)*0.8
            score += first.dot(away)*0.55
            score -= maxf(0.0,length-4.0)*0.50
            if score>best_score:
                best_score = score
                best = route
    escape_path = best
    escape_cursor = 0
    escape_clock = ESCAPE_REPLAN

func _escape_direction(player_position: Vector3, away: Vector3, delta: float) -> Vector3:
    escape_clock -= delta
    while escape_cursor<escape_path.size() and _flat(escape_path[escape_cursor]-global_position).length()<0.20:
        escape_cursor += 1
    if escape_cursor<escape_path.size():
        var waypoint: Vector3 = escape_path[escape_cursor]
        var offset: Vector3 = _flat(waypoint-global_position)
        if _safe_segment(global_position,waypoint,player_position) and _direction_clear(offset.normalized(),minf(0.42,offset.length())):
            return offset.normalized()
        escape_path.clear()
        escape_cursor = 0
        escape_clock = 0.0
    if escape_clock<=0.0:
        _escape_route(player_position,away)
        while escape_cursor<escape_path.size() and _flat(escape_path[escape_cursor]-global_position).length()<0.20:
            escape_cursor += 1
        if escape_cursor<escape_path.size():
            return _flat(escape_path[escape_cursor]-global_position).normalized()
    return Vector3.ZERO

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
    var closing: float = maxf(0.0,_flat(p.velocity).dot(away))
    if state == State.WAIT:
        if _visible_to_player(p) or distance < 3.5:
            noticed_time += delta
            if noticed_time >= 0.5:
                state = distance_state(distance,State.OBSERVE)
        else:
            noticed_time = 0.0
    elif state != State.ESCAPE:
        state = distance_state(distance,state)

    # Predict a sprint before contact; no frame-by-frame shove or velocity
    # transfer from the player's body. When the player closes at walking
    # speed, normally retain the backward-facing behavior.
    if state != State.WAIT and state != State.ESCAPE:
        if (closing>SPRINT_CLOSING and distance-closing*0.32<NEAR) or (closing>MAX_RETREAT and distance<1.35):
            _begin_escape()

    var desired: Vector3 = Vector3.ZERO
    var speed: float = 0.0
    if state == State.APPROACH:
        desired = toward
        var leaving: float = maxf(0.0,_flat(p.velocity).dot(toward))
        var pursuit_speed: float = clampf(leaving+0.60,WALK,MAX_FOLLOW)
        speed = minf(pursuit_speed,maxf(0.0,(distance-TARGET)*2.2))
        if not _direction_clear(desired,0.65):
            desired = _path_direction(desired,p.global_position,delta)
        desired = _steer(desired,away,false)
    elif state == State.RETREAT:
        desired = away
        speed = clampf((TARGET-distance)*2.8+closing,0.0,MAX_RETREAT)
        if not _direction_clear(desired,0.65):
            desired = _path_direction(desired,global_position+away*3.0,delta)
            if desired.dot(away)<0.0:
                desired = away
        desired = _steer(desired,away,true)
        if desired.is_zero_approx() or desired.dot(away)<0.36:
            _begin_escape()

    # Also recover from a blocked approach (e.g. wedged behind a pillar).
    # Stalling in OBSERVE is intentional and must not start recovery.
    if state in [State.APPROACH,State.RETREAT] and speed>0.3 and (desired.is_zero_approx() or last_motion.length()<0.12):
        stuck_time += delta
        if stuck_time>0.40:
            _begin_escape()
    else:
        stuck_time = 0.0

    if state == State.ESCAPE:
        escape_age += delta
        desired = _escape_direction(p.global_position,away,delta)
        var travelled: float = _flat(global_position-escape_start).length()
        if escape_age>=ESCAPE_MIN_TIME and travelled>0.45 and distance>=TARGET and closing<MAX_RETREAT:
            state = distance_state(distance,State.OBSERVE)
            escape_path.clear()
            desired = Vector3.ZERO
            speed = 0.0
        else:
            speed = clampf(maxf(1.50,closing+0.35),1.50,MAX_ESCAPE) if not desired.is_zero_approx() else 0.0

    # Preserve direct eye contact on the normal approach/retreat. An
    # emergency escape or side-step is played as a forward movement:
    # rotate into the chosen direction BEFORE accelerating.
    var face: Vector3 = toward
    var forward_escape: bool = state == State.ESCAPE
    if not desired.is_zero_approx():
        if state == State.APPROACH and desired.dot(toward)<0.60:
            forward_escape = true
        elif state == State.RETREAT and desired.dot(away)<0.72:
            forward_escape = true
        if forward_escape:
            face = desired
    global_rotation.y = lerp_angle(global_rotation.y,atan2(face.x,face.z),minf(delta*(12.0 if forward_escape else 7.0),1.0))
    var facing: Vector3 = global_basis.z.normalized()
    if not desired.is_zero_approx():
        var alignment: float = facing.dot(desired)
        if state == State.RETREAT and not forward_escape:
            alignment = -alignment
        # Slow until the feet face the route rather than gliding sideways.
        speed *= smoothstep(0.20,0.88,alignment)

    requested_motion = desired*speed
    var planar: Vector3 = _flat(velocity)
    # Don't keep sliding with momentum into the corner after losing a route.
    if desired.is_zero_approx() or (planar.length()>0.1 and planar.normalized().dot(desired)<0.2):
        planar = planar.move_toward(Vector3.ZERO,ACCEL*2.0*delta)
    else:
        planar = planar.move_toward(requested_motion,ACCEL*delta)
    if state == State.OBSERVE or state == State.WAIT:
        planar = planar.move_toward(Vector3.ZERO,ACCEL*delta)
    # A successful backpedal can never exceed the reverse gait speed cap.
    if not forward_escape and state == State.RETREAT:
        planar = planar.limit_length(MAX_RETREAT)
    velocity = planar + Vector3.UP*(0.0 if is_on_floor() else velocity.y-18.0*delta)
    move_and_slide()
    last_motion = _flat(get_real_velocity())
    signed_motion_speed = last_motion.dot(facing)
    rig.call("drive",signed_motion_speed,delta)

func _exit_tree() -> void:
    if is_instance_valid(nav_region):
        nav_region.set_navigation_map(RID())
        # Owned child is disposed with this actor; detach it from the
        # private map before releasing the RID.
    if nav_map.is_valid():
        NavigationServer3D.free_rid(nav_map)
        nav_map = RID()
