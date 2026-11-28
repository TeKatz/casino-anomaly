extends SceneTree
## Real imported rigs and actual room, not a mock skeleton.
const Adapter = preload("res://gameplay/demo_anomalies.gd")
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const Actor = preload("res://gameplay/anomalies/escort_actor.gd")
const Rig = preload("res://gameplay/anomalies/escort_rig.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("Escort QA: "+message)
    quit(1)

func _run() -> void:
    if not Rig.available():
        _fail("Exact authored animation asset unavailable")
        return
    var world: Node3D = (load("res://gameplay/casino/main.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(world)
    await process_frame
    await process_frame
    await physics_frame
    var adapter: RefCounted = Adapter.new()
    if not Catalog.discoverable_ids().has("the_escort") or not adapter.apply(world,"the_escort"):
        _fail("Could not instantiate real Escort")
        return
    var actor = world.get_node_or_null("AnomalyEscort")
    if actor == null or not actor.rig.ready_to_play:
        _fail("Native animation rig unavailable")
        return
    actor.set_physics_process(false)
    await physics_frame
    if not actor._place_initial():
        _fail("No clear floor spawn in real casino aisle")
        return
    var rig = actor.rig
    if rig.target.find_bone("LeftFoot") < 0 or rig.target.find_bone("RightHand") < 0 or not rig.modifier.is_rotation_enabled():
        _fail("Required humanoid mappings missing")
        return
    if rig.player.get_animation(rig.walk_name).loop_mode != Animation.LOOP_LINEAR:
        _fail("Walk does not loop")
        return
    var clip: Animation = rig.player.get_animation(rig.walk_name)
    if clip.get_track_count() < 20 or clip.length < 1.0:
        _fail("Walk clip lost authored tracks")
        return
    if actor.distance_state(8.0,Actor.State.WAIT) != Actor.State.APPROACH or actor.distance_state(2.6,Actor.State.APPROACH) != Actor.State.OBSERVE or actor.distance_state(1.5,Actor.State.OBSERVE) != Actor.State.RETREAT or actor.distance_state(2.6,Actor.State.RETREAT) != Actor.State.OBSERVE:
        _fail("Distance state machine incorrect")
        return
    # Observe the actual target skeleton in the native modifier's update
    # signal. Sampling outside that signal can see the unmodified rest pose.
    var observed: Array[Quaternion] = []
    var target: Skeleton3D = rig.target
    var thigh: int = target.find_bone("LeftUpperLeg")
    target.skeleton_updated.connect(func(): observed.append(target.get_bone_pose_rotation(thigh)))
    rig.drive(1.65,1.0)
    for i in range(30):
        await process_frame
        await physics_frame
    var changed: bool = false
    for rotation_value in observed:
        if absf(rotation_value.dot(observed[0])) < 0.999:
            changed = true
            break
    if observed.size() < 2 or not changed:
        _fail("Native retarget did not animate actual guard thigh")
        return
    var initial: Vector3 = actor.global_position
    world.set_meta("_streaming_standby",true)
    actor._physics_process(0.2)
    world.remove_meta("_streaming_standby")
    if not actor.global_position.is_equal_approx(initial):
        _fail("Guard moved in standby room")
        return
    # Real body movement and physics, not solely the distance function.
    var avatar: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
    if avatar == null:
        _fail("Room player missing")
        return
    avatar.set_physics_process(false)
    avatar.velocity = Vector3.ZERO
    var axis: Vector3 = world.global_basis.x.normalized()
    if not actor._direction_clear(axis,0.65):
        axis = -axis
    if not actor._direction_clear(axis,0.65):
        _fail("No clear approach lane")
        return
    avatar.global_position = initial+axis*5.0+Vector3.UP*0.95
    actor.state = Actor.State.APPROACH
    actor.set_physics_process(true)
    for frame in range(35):
        await physics_frame
    var approached: Vector3 = actor.global_position
    if (approached-initial).dot(axis) < 0.12:
        _fail("Guard did not walk toward a real player")
        return
    actor.state = Actor.State.OBSERVE
    actor.velocity = Vector3.ZERO
    avatar.global_position = approached+axis*1.4+Vector3.UP*0.95
    for frame in range(35):
        await physics_frame
    var retreated: Vector3 = actor.global_position
    if (retreated-approached).dot(axis) > -0.10:
        _fail("Guard did not retreat from a real player")
        return
    actor.set_physics_process(false)
    adapter.clear()
    if world.has_node("AnomalyEscort"):
        _fail("Actor leaked after anomaly cleanup")
        return
    world.queue_free()
    await process_frame
    if not (await _corner_recovery()):
        return
    print("Casino Anomaly Escort native animation and behavior QA PASS")
    quit(0)

# Real physics fixture with a floor and two perpendicular obstacles. It
# reproduces a corner where every strictly-away heading is blocked.
func _box(parent: Node3D, center: Vector3, size: Vector3) -> void:
    var body: StaticBody3D = StaticBody3D.new()
    body.position = center
    parent.add_child(body)
    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)

func _corner_recovery() -> bool:
    var room: Node3D = Node3D.new()
    room.name = "EscortCornerFixture"
    root.add_child(room)
    _box(room,Vector3(-20,-0.15,-6),Vector3(12,0.30,12))
    _box(room,Vector3(-21.1,1.3,-6),Vector3(0.20,2.6,4.0))
    _box(room,Vector3(-20,1.3,-7.1),Vector3(4.0,2.6,0.20))
    var avatar: CharacterBody3D = CharacterBody3D.new()
    avatar.name = "Player"
    avatar.position = Vector3(-19.55,0.95,-5.55)
    room.add_child(avatar)
    var guard = Actor.new()
    room.add_child(guard)
    if not guard.configure(room):
        _fail("Corner fixture could not load native rig")
        return false
    guard.set_physics_process(false)
    guard.nav_requested = true # exercise the fallback without a baked mesh
    guard.position = Vector3(-20.62,0.035,-6.62)
    guard.positioned = true
    guard.show()
    await physics_frame
    var initial: Vector3 = guard.global_position
    var away: Vector3 = guard._flat(initial-avatar.global_position).normalized()
    if guard._direction_clear(away,0.65):
        _fail("Corner fixture must block the direct retreat")
        return false
    guard.state = Actor.State.RETREAT
    guard.set_physics_process(true)
    var escaped: bool = false
    var entered_escape: bool = false
    for i in range(150):
        await physics_frame
        entered_escape = entered_escape or guard.state == Actor.State.ESCAPE
        if guard._flat(guard.global_position-initial).length()>1.0:
            escaped = true
            break
    if not entered_escape or not escaped:
        _fail("Guard remains cornered despite a clear lateral escape route")
        return false
    # A sprint in an open lane triggers an authored forward escape instead
    # of demanding an impossible backwards animation cadence.
    guard.set_physics_process(false)
    guard.position = Vector3(-18.0,0.035,-4.0)
    avatar.position = Vector3(-18.0,0.95,-1.15)
    avatar.velocity = Vector3(0,0,-6.3)
    guard.velocity = Vector3.ZERO
    guard.last_motion = Vector3.ZERO
    guard.rotation.y = 0.0
    guard.state = Actor.State.OBSERVE
    guard.escape_path.clear()
    await physics_frame
    guard.set_physics_process(true)
    var sprint_escape: bool = false
    for i in range(45):
        await physics_frame
        sprint_escape = sprint_escape or guard.state == Actor.State.ESCAPE
        if guard.signed_motion_speed < -Actor.MAX_RETREAT-0.15:
            _fail("Sprint triggered an excessive reverse gait")
            return false
    if not sprint_escape:
        _fail("Sprint anticipation did not trigger escape")
        return false
    room.queue_free()
    await process_frame
    return true
