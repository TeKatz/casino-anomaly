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
    var world: Node3D = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
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
    print("Casino Anomaly Escort native animation and behavior QA PASS")
    quit(0)
