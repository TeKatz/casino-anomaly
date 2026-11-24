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
    # End the simulated play session as the menu would, releasing all
    # audio players before the headless engine shuts down.
    var sound := root.get_node_or_null("AudioDirector")
    if sound != null:
        sound.call("set_world_ambience_enabled", false)
    for frame in range(5):
        await process_frame
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
    var camera := player.get_node("Camera3D") as Camera3D
    # Real frame-driven reveal, not a direct _enter_backrooms call. The
    # deferred environment swap must preserve the original active camera.
    for frame in range(5):
        await process_frame
        if bool(loop.get("backrooms_active")):
            break
    if not require(current_scene == casino and maze.get_parent() == casino and player.get_parent() == casino and loop.get_parent() == casino and player.global_position.distance_to(pose.origin) < 0.15, "Reveal removed or moved live player/controller"):
        return false
    if not require(root.get_camera_3d() == camera and camera.is_current() and camera.is_inside_tree() and player.can_process() and player.is_physics_processing() and player.is_processing_unhandled_input() and not paused, "Camera or input disabled after reveal"):
        return false
    if not require(bool(player.get("backrooms_mode")) and not maze.has_node("BackroomsArrivalConnector/BackroomsRevealGate_Collision") and maze.has_node("BackroomsArrivalConnector/OneWayGate_Collision"), "Dark traversal mode or blocking wall missing"):
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
    if not require(is_instance_valid(maze) and is_instance_valid(casino) and casino.get_child_count() == 3 and not casino.has_node("Architecture"), "Old casino geometry or controller lifecycle leaked"):
        return false
    if not require(root.get_camera_3d() == camera and player.can_process() and not bool(player.get("interaction_locked")) and not paused, "Camera or input lost after old geometry teardown"):
        return false
    var pickup_light := maze.get_node_or_null("FlashlightPickupLight") as OmniLight3D
    if not require(pickup_light != null and pickup_light.light_energy <= 0.16, "Missing dim pickup light"):
        return false
    var connector := maze.get_node("BackroomsArrivalConnector") as Node3D
    var oak := connector.get_node("TurnFloor") as MeshInstance3D
    var oak_shape := connector.get_node("TurnFloor_Collision/Shape") as CollisionShape3D
    var carpet := maze.get_node("Architecture/Floor/Mesh") as MeshInstance3D
    var edge := carpet.to_global(Vector3(carpet.get_aabb().position.x, 0, Backrooms.ENTRY_Z))
    var oak_end := connector.to_global(Vector3(oak.position.x, 0, oak.position.z + portals.lane_sign(lane) * (oak.mesh as BoxMesh).size.z * 0.5))
    var edge_local := connector.to_local(edge)
    if not require(absf(edge_local.z - connector.to_local(oak_end).z) < 0.001 and (oak.mesh as BoxMesh).size.is_equal_approx((oak_shape.shape as BoxShape3D).size) and not maze.has_node("EntranceJoin/Threshold"), "Oak/carpet seam overlaps, gaps or stale collider"):
        return false
    var env := maze.get_node("Lighting/Environment") as WorldEnvironment
    if not require(env.environment.ambient_light_energy <= 0.0351, "Backrooms ambient light too bright"):
        return false
    # Verify the actual input routing and pause menu remain alive. Push
    # events through the viewport, never directly invoke the menu handler.
    var esc := InputEventKey.new()
    esc.keycode = KEY_ESCAPE
    esc.pressed = true
    root.push_input(esc, true)
    if not require(paused and bool(player.get_node("InGameMenu").get("open")), "Escape no longer opens pause menu"):
        return false
    root.push_input(esc, true)
    if not require(not paused and not bool(player.get_node("InGameMenu").get("open")), "Escape no longer resumes the game"):
        return false
    var pickup := maze.get_node_or_null("FlashlightPickup")
    if not require(pickup != null and maze.has_node("BackroomsHum") and player.get_node_or_null("Camera3D/BackroomsFlashlight") == null, "Initial flashlight or ambience state wrong"):
        return false
    player.global_position = maze.to_global(Vector3(-14.5, 1.02, 0.5))
    await physics_frame
    var hint := pickup.get_node_or_null("PickupHUD/Overlay/PickupPrompt") as Label
    pickup.call("update_prompt", player)
    if not require(hint != null and hint.visible and pickup.find_children("*", "Label3D", true, false).is_empty(), "Pickup hint is not screen-space"):
        return false
    var original_rotation := camera.rotation
    camera.rotation.y += PI
    pickup.call("update_prompt", player)
    if not require(hint.visible, "Pickup hint depends on camera facing direction"):
        return false
    camera.rotation = original_rotation
    var key := InputEventKey.new()
    key.keycode = KEY_E
    key.pressed = true
    root.push_input(key, true)
    if not require(bool(pickup.get("taken")) and not pickup.visible and player.has_node("Camera3D/BackroomsFlashlight"), "E did not collect the nearby torch"):
        return false
    var torch := player.get_node("Camera3D/BackroomsFlashlight") as SpotLight3D
    if not require(not hint.visible and torch.light_energy <= 0.95 and torch.spot_range <= 9.0, "Pickup hint or beam tuning incorrect"):
        return false
    root.push_input(key, true)
    if not require(player.get_node("Camera3D").find_children("BackroomsFlashlight", "SpotLight3D", false, false).size() == 1, "Repeated E duplicated flashlight"):
        return false
    # Stand inside before the exit: next hall is available but unscored.
    player.global_position = maze.to_global(Vector3(Backrooms.EXIT_X - 0.8, 1.02, Backrooms.EXIT_Z))
    loop.call("_process", 0.016)
    var next := loop.get("staged") as Node3D
    if not require(next != null and state.correct_streak == streak and not bool(loop.get("backrooms_scored")), "Approach to exit was scored early"):
        return false
    if not require(maze.to_global(Vector3(Backrooms.RETURN_BEND_X, 0, Backrooms.RETURN_SEAM_Z)).distance_to(next.to_global(Vector3(0, 0, portals.ENTRY_Z))) < 0.01, "Return corridor misses the casino entrance"):
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
    var next_world := next.get_node("WorldEnvironment") as WorldEnvironment
    var destination := loop.get("staged_environment") as Environment
    var original := loop.get("backrooms_environment") as Environment
    if not require(next_world.environment == null and env.environment != destination and not bool(loop.get("backrooms_return_lighting_ready")), "Casino environment activated before return passage"):
        return false
    player.global_position = maze.to_global(Vector3((Backrooms.LIGHT_BLEND_START + Backrooms.LIGHT_BLEND_END) * 0.5, 1.02, Backrooms.EXIT_Z))
    loop.call("_process", 0.016)
    var blended := env.environment
    if not require(blended != null and blended != original and blended != destination and is_equal_approx(blended.ambient_light_energy, lerpf(original.ambient_light_energy, destination.ambient_light_energy, 0.5)) and is_equal_approx(torch.light_energy, 0.475), "Return lighting does not blend continuously on a runtime copy"):
        return false
    player.global_position = maze.to_global(Vector3(Backrooms.LIGHT_BLEND_END + 0.05, 1.02, Backrooms.EXIT_Z))
    loop.call("_process", 0.016)
    if not require(next_world.environment == destination and env.environment == null and bool(loop.get("backrooms_return_lighting_ready")) and Backrooms.LIGHT_BLEND_END < Backrooms.RETURN_BEND_X - Backrooms.HALF_WIDTH and is_zero_approx(torch.light_energy), "Final environment not active before blind bend"):
        return false
    if not require(maze.has_node("BackroomsExitConnector/StraightInnerWall_Collision") and maze.has_node("BackroomsExitConnector/TurnOuterWall_Collision"), "Blind return corridor is missing solid walls"):
        return false
    await process_frame
    await process_frame
    player.global_position = maze.to_global(Vector3(Backrooms.RETURN_BEND_X, 1.02, Backrooms.RETURN_SEAM_Z + 4.5))
    pose = player.global_transform
    loop.call("_process", 0.016)
    if not require(current_scene == next and player.get_parent() == next and loop.get_parent() == next and player.global_transform.is_equal_approx(pose), "Return teleported or replaced player/controller"):
        return false
    if not require(not bool(player.get("backrooms_mode")) and not player.has_node("Camera3D/BackroomsFlashlight") and not bool(loop.get("backrooms_active")) and next.has_node("ArrivalConnector/ExitGate_Collision"), "Traversal-only equipment or gate leaked"):
        return false
    if not require(next_world.environment == destination, "Visible hall environment was replaced at scene handoff"):
        return false
    if not require(state.finished == rotated and bool(loop.get("won")) == rotated and (rotated or state.round_ready), "Victory or ordinary next round missing"):
        return false
    await process_frame
    await process_frame
    if not require(not is_instance_valid(maze) and not is_instance_valid(casino) and is_instance_valid(next), "Old maze/host leaked or return casino freed"):
        return false
    if not require(root.get_camera_3d() == camera and camera.is_current() and player.can_process() and not paused, "Camera or input lost during return handoff"):
        return false
    next.queue_free()
    await process_frame
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
    return true
