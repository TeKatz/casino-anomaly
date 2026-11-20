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
    var room_resource := load("res://main.tscn") as PackedScene
    if intro_resource == null or room_resource == null:
        _fail("Tutorial or original casino scene cannot load")
        return

    var intro := intro_resource.instantiate() as Node3D
    if intro.get_node_or_null("ExitDoor") == null or intro.get_node_or_null("Player/Camera3D") == null:
        _fail("Tutorial room has no entry door or first-person player")
        return
    intro.free()

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
    var exit_signs: Array[Label3D] = []
    for part in (scene.get_node("Architecture") as Node3D).get_children():
        if part is Label3D and (part as Label3D).text == "EXIT":
            exit_signs.append(part as Label3D)
    if exit_signs.size() != 2:
        _fail("The designer's room must retain exactly two original EXIT doors")
        return
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
    if not local.round_ready or not local.anomaly_id.is_empty():
        _fail("The first playable casino hall must always be anomaly-free")
        return
    # A legacy save with a pre-rolled first anomaly is sanitized as well.
    local.anomaly_id = "bar_label"
    local.prepare_round(available)
    if not local.anomaly_id.is_empty():
        _fail("The baseline first room can never contain an anomaly")
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

    restored.correct_streak = 11
    restored.anomaly_id = ""
    restored.round_ready = true
    var victory: Dictionary = restored.decide(false)
    if not bool(victory.get("finished", false)) or restored.active or restored.has_continue():
        _fail("Twelve consecutive correct decisions must end the run")
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
    var choice_markers := loop.get_node_or_null("DoorChoices") as Node3D
    if loop == null or choice_markers == null:
        _fail("Runtime loop did not attach to original casino EXIT doors")
        return
    var left := choice_markers.get_node_or_null("LeftDoor") as Node3D
    var right := choice_markers.get_node_or_null("RightDoor") as Node3D
    if left == null or right == null or left.global_position.z <= right.global_position.z:
        _fail("Casino exit markers must be physically arranged left / right")
        return
    if not state.round_ready or not state.anomaly_id.is_empty() \
            or loop.get_node_or_null("GameHUD") != null:
        _fail("First round must be anomaly-free and have no gameplay HUD")
        return
    var progress := scene.get_node_or_null("NeonLevelSign") as Node3D
    if progress == null or progress.get_node_or_null("NeonGlow") == null \
            or not (progress.get_node_or_null("Number") is MeshInstance3D) \
            or not ((progress.get_node("Number") as MeshInstance3D).mesh is TextMesh) \
            or ((progress.get_node("Number") as MeshInstance3D).mesh as TextMesh).text != "0":
        _fail("A new run needs a world-space emissive neon zero, not an overlay")
        return
    if scene.get_node_or_null("StreamingPortals/InitialEntryCap/SolidDoor_Collision") == null:
        _fail("First hall entrance is open to the void")
        return
    if scene.get_node_or_null("Player/Camera3D") == null:
        _fail("Player camera was lost after starting a run")
        return

    # First round now streams another casino scene in spatial continuity.
    # Approaching the current far exits opens two real walkable portals.
    if scene.get_node_or_null("StreamingPortals") == null:
        _fail("The gameplay did not open walkable door apertures")
        return
    if (scene.get_node("Architecture/FarExitWall") as MeshInstance3D).visible:
        _fail("The solid far wall still blocks both exits")
        return
    loop.call("_stage_next", "left")
    var staged := loop.get("staged") as Node3D
    if staged == null or staged.get_node_or_null("Player") != null:
        _fail("Next hall was not preloaded as a passive playerless instance")
        return
    loop.call("_commit_choice", "left")
    if state.visited_loops != 1 or not state.round_ready or state.correct_streak != 0:
        _fail("Walking through left in the guaranteed normal first room must reset progress")
        return
    var stage_sign := staged.get_node_or_null("NeonLevelSign/Number") as MeshInstance3D
    if stage_sign == null or (stage_sign.mesh as TextMesh).text != "0":
        _fail("Next room did not receive the updated diegetic progress")
        return

    # The same streamed-room path must deliver a real final room at 12.
    loop.call("_handoff")
    var second := loop.get("room") as Node3D
    state.correct_streak = 11
    state.anomaly_id = ""
    state.round_ready = true
    loop.call("_stage_next", "right")
    loop.call("_commit_choice", "right")
    if not state.finished or not bool(loop.get("finishing")) \
            or loop.get_node_or_null("VictoryOverlay") != null:
        _fail("Victory must trigger on the twelfth decision with no screen-space overlay")
        return
    var final_room := loop.get("staged") as Node3D
    var final_number := final_room.get_node_or_null("NeonLevelSign/Number") as MeshInstance3D
    var final_caption := final_room.get_node_or_null("NeonLevelSign/CompletionText") as MeshInstance3D
    if final_number == null or (final_number.mesh as TextMesh).text != "12" \
            or final_caption == null or (final_caption.mesh as TextMesh).text.is_empty():
        _fail("The final hall must display its completion in world-space neon")
        return
    loop.call("_handoff")
    if not bool(loop.get("won")) or loop.get("room") != final_room \
            or final_room.get_node_or_null("StreamingPortals/Connector_Left/OneWayGate_Collision") == null:
        _fail("Winning must hand off seamlessly into a physically capped final hall")
        return

    scene.queue_free()
    second.queue_free()
    final_room.queue_free()
    await process_frame
    local.free()
    restored.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
    print("Casino Anomaly playable tutorial, save and loop gameplay QA PASS")
    quit(0)
