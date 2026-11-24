extends SceneTree
## Both doors, actual corner threshold, flashlight interaction, continuous
## player/controller, deferred exactly-once score, save and final victory.
const ROOM = preload("res://main.tscn")
const Portals = preload("res://gameplay/stream_portals.gd")
const Backrooms = preload("res://gameplay/backrooms_traversal.gd")
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const StateScript = preload("res://gameplay/loop_state.gd")

func _initialize() -> void:
    call_deferred("_run")

func require(condition: bool, message: String) -> bool:
    if not condition:
        push_error("Backrooms traversal QA: " + message)
    return condition

func _run() -> void:
    if not require(Catalog.discoverable_ids().has("backrooms"), "Missing discoverable catalog entry"):
        quit(1)
        return
    if not await _exercise("right", 1, false):
        quit(1)
        return
    if not await _exercise("left", 11, true):
        quit(1)
        return
    print("Casino Anomaly Backrooms traversal QA PASS")
    quit(0)

func _exercise(lane: String, streak: int, rotated: bool) -> bool:
    var state = root.get_node_or_null("LoopState")
    state.save_path = "user://backrooms_traversal_" + lane + "_qa.cfg"
    state.start_new_run()
    state.complete_tutorial()
    var casino := ROOM.instantiate() as Node3D
    if rotated:
        casino.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(25, 0, 18))
        state.visited_loops = 11
        state.correct_streak = 11
        state.round_ready = true
        state.anomaly_id = "backrooms"
        state.round_debugged = true
    root.add_child(casino)
    current_scene = casino
    await process_frame
    await physics_frame
    var loop := casino.get_node("LoopController")
    var player := casino.get_node("Player") as CharacterBody3D
    var portals := Portals.new()
    if not rotated:
        # Force the next room through the real G-menu path. The normal
        # departure must still enter its staged casino, not jump to the maze.
        if not require(bool(loop.call("debug_select_next_anomaly", "backrooms")), "Developer picker cannot select Backrooms"):
            return false
        loop.call("_stage_next", "right")
        loop.call("_commit_choice", "right")
        if not require(state.anomaly_id == "backrooms" and state.correct_streak == 1, "Special round not selected after reference hall"):
            return false
        var staged := loop.get("staged") as Node3D
        player.global_position = casino.to_global(Vector3(portals.BEND_X, 1.02, portals.end_z("right") - 4.4))
        loop.call("_process", 0.016)
        if not require(current_scene == staged and not bool(loop.get("backrooms_active")), "Next anomaly hijacked previous normal handoff"):
            return false
        casino = staged
        await process_frame
        await physics_frame
    state.save_run()
    var visits: int = state.visited_loops
    var mistakes: int = state.mistakes
    # Both door answers MUST be invalid through the binary scoring API.
    if not require(not bool(state.decide(lane == "left").get("valid", false)) and state.correct_streak == streak, "Binary choice consumed traversal round"):
        return false
    player.global_position = casino.to_global(Vector3(-35.0, 1.02, portals.lane_z(lane)))
    loop.call("_process", 0.016)
    var maze := loop.get("backrooms_maze") as Node3D
    if not require(maze != null and not bool(loop.get("choice_taken")) and loop.get("staged") == null, "Hidden standby maze was not staged"):
        return false
    if not require(not maze.has_node("PreviewCamera") and not maze.has_node("FlashlightPickup") and not (maze.get_node("Lighting") as Node3D).visible, "Hidden maze leaked effects or active camera"):
        return false
    var entry_seam := maze.to_global(Vector3(Backrooms.ENTRY_X, 0, Backrooms.ENTRY_Z))
    var expected_entry := casino.to_global(Vector3(portals.BEND_X, 0, portals.end_z(lane) + portals.lane_sign(lane) * 0.55))
    if not require(entry_seam.distance_to(expected_entry) < 0.01, "Maze entrance does not meet chosen bend"):
        return false
    # The ordinary corridor stays exactly as authored until the blind turn.
    player.global_position = casino.to_global(Vector3(-50.0, 1.02, portals.lane_z(lane)))
    loop.call("_process", 0.016)
    if not require(not bool(loop.get("backrooms_active")) and not portals.get_connector(casino, lane).has_node("OneWayGate") and state.correct_streak == streak, "Premature reveal or verdict"):
        return false
    player.global_position = casino.to_global(Vector3(portals.BEND_X, 1.02, portals.lane_z(lane) + portals.lane_sign(lane) * 2.5))
    var pose := player.global_transform
    loop.call("_process", 0.016)
    if not require(current_scene == maze and player.get_parent() == maze and loop.get_parent() == maze and player.global_transform.is_equal_approx(pose), "Reveal teleported or replaced player/controller"):
        return false
    if not require(bool(player.get("backrooms_mode")) and maze.has_node("BackroomsArrivalConnector/BackroomsRevealGate_Collision") and maze.has_node("BackroomsArrivalConnector/OneWayGate_Collision"), "Dark traversal mode or blocking wall missing"):
        return false
    if not require(state.correct_streak == streak and state.visited_loops == visits and state.mistakes == mistakes and state.anomaly_id == "backrooms", "Entry changed progress"):
        return false
    var saved := StateScript.new()
    saved.save_path = state.save_path
    var safe_save := saved.load_run() and saved.correct_streak == streak and saved.anomaly_id == "backrooms"
    saved.free()
    if not require(safe_save, "Continuing an interrupted maze loses progress"):
        return false
    await process_frame
    await physics_frame
    if not require(is_instance_valid(maze) and not is_instance_valid(casino), "Maze freed during reparent or old casino leaked"):
        return false
    var pickup := maze.get_node_or_null("FlashlightPickup")
    if not require(pickup != null and maze.has_node("BackroomsHum") and player.get_node_or_null("Camera3D/BackroomsFlashlight") == null, "Initial flashlight or ambience state wrong"):
        return false
    player.global_position = maze.to_global(Vector3(-14.5, 1.02, 0.5))
    await physics_frame
    var key := InputEventKey.new()
    key.keycode = KEY_E
    key.pressed = true
    loop.call("_unhandled_input", key)
    if not require(bool(pickup.get("taken")) and not pickup.visible and player.has_node("Camera3D/BackroomsFlashlight"), "E did not collect the nearby torch"):
        return false
    loop.call("_unhandled_input", key)
    if not require(player.get_node("Camera3D").find_children("BackroomsFlashlight", "SpotLight3D", false, false).size() == 1, "Repeated E duplicated flashlight"):
        return false
    # Stand inside before the exit: next hall is available but unscored.
    player.global_position = maze.to_global(Vector3(Backrooms.EXIT_X - 0.8, 1.02, Backrooms.EXIT_Z))
    loop.call("_process", 0.016)
    var next := loop.get("staged") as Node3D
    if not require(next != null and state.correct_streak == streak and not bool(loop.get("backrooms_scored")), "Approach to exit was scored early"):
        return false
    if not require(maze.to_global(Vector3(Backrooms.EXIT_X + Backrooms.EXIT_LENGTH, 0, Backrooms.EXIT_Z)).distance_to(next.to_global(Vector3(0, 0, portals.ENTRY_Z))) < 0.01, "Return corridor misses the casino entrance"):
        return false
    player.global_position = maze.to_global(Vector3(Backrooms.EXIT_X + 1.6, 1.02, Backrooms.EXIT_Z))
    loop.call("_process", 0.016)
    if not require(state.correct_streak == streak + 1 and state.visited_loops == visits + 1 and state.mistakes == mistakes and bool(state.last_verdict.get("correct")) and str(state.last_verdict.get("anomaly_id")) == "backrooms", "Traversal did not award exactly one step without mistakes"):
        return false
    if not require(bool(state.last_verdict.get("choice_anomaly")) == (lane == "left") and maze.has_node("BackroomsExitConnector/ExitGate_Collision"), "Wrong door recorded or missing exit seal"):
        return false
    loop.call("_finish_backrooms")
    if not require(state.correct_streak == streak + 1 and state.visited_loops == visits + 1, "Duplicate completion awarded another step"):
        return false
    player.global_position = maze.to_global(Vector3(Backrooms.EXIT_X + Backrooms.EXIT_LENGTH + 4.5, 1.02, Backrooms.EXIT_Z))
    pose = player.global_transform
    loop.call("_process", 0.016)
    if not require(current_scene == next and player.get_parent() == next and loop.get_parent() == next and player.global_transform.is_equal_approx(pose), "Return teleported or replaced player/controller"):
        return false
    if not require(not bool(player.get("backrooms_mode")) and not player.has_node("Camera3D/BackroomsFlashlight") and not bool(loop.get("backrooms_active")) and next.has_node("ArrivalConnector/ExitGate_Collision"), "Traversal-only equipment or gate leaked"):
        return false
    if not require(state.finished == rotated and bool(loop.get("won")) == rotated and (rotated or state.round_ready), "Victory or ordinary next round missing"):
        return false
    await process_frame
    await process_frame
    if not require(not is_instance_valid(maze) and is_instance_valid(next), "Old maze leaked or return casino freed"):
        return false
    next.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
    return true
