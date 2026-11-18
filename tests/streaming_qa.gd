extends SceneTree
## Live runtime test for genuine two-instance streaming:
## both rooms occupy distinct adjacent world coordinates; only one Player
## and one controller/HUD survive each handoff, without a teleport/fade.

const ROOM = preload("res://main.tscn")

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("Casino seamless streaming QA: " + message)
    quit(1)


func _run() -> void:
    var state = root.get_node_or_null("LoopState")
    if state == null:
        _fail("Run save autoload is missing")
        return
    state.save_path = "user://casino_streaming_qa.cfg"
    state.start_new_run()
    state.complete_tutorial()
    var first := ROOM.instantiate() as Node3D
    root.add_child(first)
    current_scene = first
    await process_frame
    await process_frame
    await process_frame

    var controller := first.get_node_or_null("LoopController")
    if controller == null:
        _fail("Initial hall has no gameplay controller")
        return
    var player := first.get_node_or_null("Player") as CharacterBody3D
    if player == null:
        _fail("Initial hall has no player")
        return
    var portal := first.get_node_or_null("StreamingPortals") as Node3D
    if portal == null or portal.find_children("ConnectorFloor", "MeshInstance3D", true, false).size() != 2:
        _fail("Both walkable physical connectors were not built")
        return
    if (first.get_node("Architecture/FarExitWall") as MeshInstance3D).visible:
        _fail("Existing solid exit wall is still visible")
        return
    var far_collision := first.get_node("Architecture/FarExitWall_Collision") as StaticBody3D
    if far_collision == null:
        _fail("Original collision body unexpectedly deleted")
        return
    for part in far_collision.get_children():
        if part is CollisionShape3D and not (part as CollisionShape3D).disabled:
            _fail("Original exit wall is still collidable")
            return

    controller.call("_stage_next", "left")
    var second := controller.get("staged") as Node3D
    if second == null or second == first or second.get_parent() != root:
        _fail("Second full hall was not preloaded beside the first")
        return
    if second.get_node_or_null("Player") != null or second.get_node_or_null("LoopController") != null:
        _fail("Standby hall duplicated the player or runtime controller")
        return
    var expected_entry := first.to_global(Vector3(-54.50, 0, -3.70))
    var actual_entry := second.to_global(Vector3(0, 0, 14.18))
    if expected_entry.distance_to(actual_entry) > 0.015:
        _fail("Exit passage and next-room entry are not physically aligned")
        return

    controller.call("_commit_choice", "left")
    if state.visited_loops != 1 or not state.round_ready:
        _fail("Crossing an open portal failed to score/prepare the next round")
        return
    var next_anomaly := str(state.anomaly_id)
    var expected_player_pos := first.to_global(Vector3(-55.10, 1.02, -3.70))
    player.global_position = expected_player_pos
    var saved_pose := player.global_transform
    controller.call("_handoff")
    if current_scene != second:
        _fail("SceneTree did not promote the preloaded hall")
        return
    if not is_instance_valid(player) or player.get_parent() != second:
        _fail("The original Player was not transferred into the new room")
        return
    if controller.get_parent() != second:
        _fail("HUD/controller were not kept alive during the swap")
        return
    if player.global_transform.origin.distance_to(saved_pose.origin) > 0.001:
        _fail("Streaming caused a position teleport")
        return
    if second.get_node("WorldEnvironment").environment == null:
        _fail("New active hall never activated its original environment")
        return
    if not second.has_node("StreamingPortals"):
        _fail("Next hall did not already have its exits and entry opened")
        return
    await process_frame
    await process_frame
    if is_instance_valid(first):
        _fail("Previous room was not unloaded after passing its connector")
        return
    if str(state.anomaly_id) != next_anomaly:
        _fail("Preloaded room lost the already selected round/anomaly")
        return

    # Another loop must work after rotating the whole level by 90 degrees.
    controller.call("_stage_next", "right")
    var third := controller.get("staged") as Node3D
    if third == null:
        _fail("A third loop cannot be preloaded after scene handoff")
        return
    var expected_third_entry := second.to_global(Vector3(-54.50, 0, -9.65))
    if expected_third_entry.distance_to(third.to_global(Vector3(0, 0, 14.18))) > 0.015:
        _fail("Rotated second connector does not meet the third room")
        return
    controller.call("_commit_choice", "right")
    if state.visited_loops != 2:
        _fail("Second decision was not counted")
        return
    player.global_position = second.to_global(Vector3(-55.10, 1.02, -9.65))
    var second_pose := player.global_transform
    controller.call("_handoff")
    if current_scene != third or player.global_position.distance_to(second_pose.origin) > 0.001:
        _fail("Second spatial handoff altered player location")
        return
    await process_frame
    await process_frame
    if is_instance_valid(second):
        _fail("Second room remained resident after leaving it")
        return
    if third.find_children("LoopController", "Node3D", false, false).size() != 1:
        _fail("Repetitions created duplicate gameplay controllers")
        return
    third.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
    print("Casino Anomaly seamless two-room streaming QA PASS")
    quit(0)
