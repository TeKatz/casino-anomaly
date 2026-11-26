extends SceneTree
## Exercise every actual source rig in every seat class, including loop seams.
const Actor = preload("res://gameplay/anomalies/silent_audience_actor.gd")
const Premium = preload("res://gameplay/anomalies/silent_audience_premium.gd")
const Pose = preload("res://gameplay/anomalies/silent_audience_pose.gd")

func _initialize() -> void:
    create_timer(240.0,true,false,true).timeout.connect(func(): _fail("QA watchdog expired"))
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("Silent Audience actor QA: "+reason)
    quit(1)

func _run() -> void:
    if not Premium.models_available():
        _fail("All five production source models must be importable")
        return
    var signatures := {}
    for entry in Premium.PATHS:
        var model := load(entry[1]) as PackedScene
        for kind in ["sofa","bar","table"]:
            var guest := Actor.new()
            root.add_child(guest)
            var height := 0.55 if kind == "sofa" else (0.88 if kind == "bar" else 0.728)
            var site := {"anchor":Vector3(0,height,0),"kind":kind,"yaw":PI*0.37,"floor_y":0.0}
            print("QA seated rig: ",entry[0]," / ",kind)
            if not guest.configure(model, str(entry[0]), site, 2):
                _fail("Could not seat "+str(entry[0])+" / "+kind)
                return
            if guest.physical == null or guest.physical.collision_layer != 1:
                _fail("Guest collision missing")
                return
            if guest.has_method("start_standing"):
                _fail("Removed standing behavior returned")
                return
            for side in ["left","right"]:
                var shoulder: Vector3 = guest._point(side+"_arm")
                var elbow: Vector3 = guest._point(side+"_forearm")
                var thigh: Vector3 = guest._point(side+"_thigh")
                var knee: Vector3 = guest._point(side+"_calf")
                var ankle: Vector3 = guest._point(side+"_foot")
                var toe: Vector3 = guest._point(side+"_toe")
                if (elbow-shoulder).normalized().dot(Vector3.DOWN) < 0.65:
                    _fail("Arm remains in T/A pose: "+str(entry[0]))
                    return
                if (knee-thigh).dot(guest.seat_forward) < 0.12:
                    _fail("Knee points away from seat front: "+str(entry[0]))
                    return
                if (toe-ankle).dot(guest.seat_forward) < 0.01:
                    _fail("Foot faces backwards: "+str(entry[0]))
                    return
                if minf(ankle.y,toe.y) + height < -0.005:
                    _fail("Foot below floor: "+str(entry[0]))
                    return
            var root_position: Vector3 = guest.figure.position
            var start_hip: Vector3 = guest._point("hip")
            guest._sample_loop(0.0)
            var first := Pose.snapshot(guest.skeleton)
            guest._sample_loop(guest.loop_period*0.37)
            var middle := Pose.snapshot(guest.skeleton)
            var moved := false
            for i in range(first.size()):
                if absf((first[i]["q"] as Quaternion).dot(middle[i]["q"])) < 0.999999:
                    moved = true
            if not moved and not guest.reduced_motion:
                _fail("No continuous seated movement: "+str(entry[0]))
                return
            guest._sample_loop(guest.loop_period)
            var last := Pose.snapshot(guest.skeleton)
            for i in range(first.size()):
                if absf((first[i]["q"] as Quaternion).dot(last[i]["q"])) < 0.99999:
                    _fail("Animation loop seam: "+str(entry[0]))
                    return
            guest._process(180.0)
            guest.skeleton.force_update_all_bone_transforms()
            if not guest.figure.position.is_equal_approx(root_position) or not guest._point("hip").is_equal_approx(start_hip):
                _fail("Seated actor drifted or stood up")
                return
            signatures[str(entry[0])] = guest.loop_period
            guest.free()
            await process_frame
    if signatures.size() != 5 or signatures.values().size() != 5:
        _fail("Missing individual performances")
        return
    print("Casino Anomaly silent audience actor QA PASS")
    quit(0)
