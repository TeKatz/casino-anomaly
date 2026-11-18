extends SceneTree

const StateScript = preload("res://gameplay/loop_state.gd")
const DemoScript = preload("res://gameplay/demo_anomalies.gd")

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("Casino anomaly gameplay QA: " + reason)
    quit(1)


func _run() -> void:
    var intro_resource := load("res://gameplay/tutorial.tscn") as PackedScene
    var door_resource := load("res://gameplay/decision_doors.tscn") as PackedScene
    var room_resource := load("res://main.tscn") as PackedScene
    if intro_resource == null or door_resource == null or room_resource == null:
        _fail("One of the three authored scenes cannot load")
        return

    var intro := intro_resource.instantiate() as Node3D
    if intro.get_node_or_null("ExitDoor") == null or intro.get_node_or_null("Player/Camera3D") == null:
        _fail("Tutorial room has no entry door or first-person player")
        return
    intro.free()

    var doors := door_resource.instantiate() as Node3D
    var left := doors.get_node_or_null("LeftDoor") as Node3D
    var right := doors.get_node_or_null("RightDoor") as Node3D
    if left == null or right == null:
        _fail("Two exit choices are required")
        return
    # Facing west at the end of the red runner, +Z is physically left.
    if left.position.z <= right.position.z or left.position.x > -44.0:
        _fail("Exit doors are not arranged left / right at the far western wall")
        return
    doors.free()

    var local := StateScript.new()
    local.save_path = "user://anomaly_loop_logic_qa.cfg"
    local.start_new_run()
    if not local.active or local.tutorial_done or local.round_ready:
        _fail("A new run must always begin in the tutorial")
        return
    local.complete_tutorial()
    if not local.tutorial_done:
        _fail("Tutorial cannot be completed")
        return

    var scene := room_resource.instantiate() as Node3D
    var demo := DemoScript.new()
    var available: Array[String] = demo.available_ids(scene)
    if available.size() < 2:
        _fail("Demo registry cannot find the casino's existing labels")
        return
    var sign := scene.get_node("CornerBar/Sign_MIDNIGHT_BAR") as Label3D
    var original := sign.text
    if not demo.apply(scene, "bar_label") or sign.text == original:
        _fail("Demo anomaly is not visible on the existing bar sign")
        return
    demo.clear()
    if sign.text != original:
        _fail("Resetting an anomaly must restore the artist's text")
        return

    local.prepare_round(available)
    if not local.round_ready:
        _fail("Random round was not prepared")
        return
    var answer_was_anomaly := not local.anomaly_id.is_empty()
    var result: Dictionary = local.decide(answer_was_anomaly)
    if not bool(result.get("correct", false)) or local.correct_streak != 1:
        _fail("Correct left / right answer was not scored")
        return

    local.prepare_round(available)
    local.round_ready = true
    local.anomaly_id = "bar_label"
    local.decide(false)
    if local.correct_streak != 0 or local.mistakes != 1:
        _fail("Wrong answer must reset streak, not the run")
        return

    var restored := StateScript.new()
    restored.save_path = local.save_path
    if not restored.load_run() or restored.visited_loops != 2 or restored.mistakes != 1:
        _fail("Continue save does not survive a new state instance")
        return

    restored.correct_streak = 7
    restored.anomaly_id = ""
    restored.round_ready = true
    var victory: Dictionary = restored.decide(false)
    if not bool(victory.get("finished", false)) or restored.active or restored.has_continue():
        _fail("Eight consecutive correct decisions must end the run")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(local.save_path))

    # Exercise the actual gameplay controller, which is attached at runtime
    # while the designer-authored main.tscn stays byte-for-byte unchanged.
    var state = root.get_node_or_null("LoopState")
    if state == null:
        _fail("LoopState autoload is missing")
        return
    state.save_path = "user://anomaly_loop_runtime_qa.cfg"
    state.start_new_run()
    state.complete_tutorial()
    root.add_child(scene)
    await process_frame
    await process_frame
    await process_frame
    var loop := scene.get_node_or_null("LoopController")
    if loop == null or scene.get_node_or_null("DecisionDoors") == null:
        _fail("Run did not attach visible left/right doors and loop controller")
        return
    if not state.round_ready or loop.get_node_or_null("GameHUD") == null:
        _fail("Gameplay HUD and first random round were not initialized")
        return
    if scene.get_node_or_null("Player/Camera3D") == null:
        _fail("Player camera was lost after starting a run")
        return

    scene.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
    print("Casino Anomaly playable tutorial, save and loop gameplay QA PASS")
    quit(0)
