extends SceneTree
## Integration regression: 2 genuine blind L-bends, both locked departures,
## retained arrival-connector after unloading and two consecutive no-teleport
## room swaps. Detects the reported ability to walk into the exterior void.

const ROOM = preload("res://main.tscn")
const Portals = preload("res://gameplay/stream_portals.gd")


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

    var shape = Portals.new()
    var first := ROOM.instantiate() as Node3D
    root.add_child(first)
    current_scene = first
    await process_frame
    await process_frame
    await physics_frame

    var controller := first.get_node_or_null("LoopController")
    var player := first.get_node_or_null("Player") as CharacterBody3D
    if controller == null or player == null:
        _fail("Streaming hall lost its active controller or player")
        return
    var portal := first.get_node_or_null("StreamingPortals") as Node3D
    if portal == null:
        _fail("The casino did not create runtime streaming portals")
        return
    var architecture := first.get_node("Architecture") as Node3D
    var original_gold := architecture.get_node_or_null("ExitFrameTop") as MeshInstance3D
    if original_gold == null or original_gold.visible:
        _fail("Old placeholder gold side/top trim was not removed")
        return
    var wood := architecture.get_node("WoodWainscoting") as MeshInstance3D
    for label in ["Left", "Right"]:
        var frame := portal.get_node_or_null("WoodExitFrame_" + label) as Node3D
        if frame == null or not frame.has_node("Jamb_North") \
                or not frame.has_node("Jamb_South") or not frame.has_node("Header"):
            _fail("A proper two-post wooden %s door frame was not constructed" % label)
            return
        if (frame.get_node("Header") as MeshInstance3D).material_override != wood.material_override:
            _fail("Wooden EXIT frame must reuse the existing wainscoting PBR material")
            return
    var entry := portal.get_node_or_null("EntrySleeve") as Node3D
    if entry == null or not entry.has_node("SideReturn_North_Collision") \
            or not entry.has_node("SideReturn_South_Collision") \
            or not entry.has_node("RoofSoffit_Collision"):
        _fail("The old corridor's entrance still leaks into the exterior void")
        return
    if portal.get_node_or_null("InitialEntryCap/SolidDoor_Collision") == null:
        _fail("Initial casino is missing a closed entry behind the player")
        return
    var signs := {}
    for child in architecture.get_children():
        if child is Label3D and (child.text == "ANOMALY" or child.text == "NORMAL"):
            signs[child.text] = child.position.z
    if signs.size() != 2 or absf(float(signs["ANOMALY"]) - shape.EXIT_Z_LEFT) > 0.5 \
            or absf(float(signs["NORMAL"]) - shape.EXIT_Z_RIGHT) > 0.5:
        _fail("The physical left/right door labels disagree with the game's choices")
        return
    for lane in ["left", "right"]:
        var corridor := shape.get_connector(first, lane)
        if corridor == null:
            _fail("Missing the separate L-shaped %s corridor" % lane)
            return
        for name in [
            "DoorwayFloor", "StraightFloor", "StraightCeiling", "TurnFloor", "TurnCeiling",
            "StraightOuterWall", "StraightInnerWall", "TurnOuterWall", "TurnInnerWall"
        ]:
            if corridor.get_node_or_null(name) == null                     or (name != "DoorwayFloor" and corridor.get_node_or_null(name + "_Collision") == null):
                _fail("%s corridor does not contain collidable %s" % [lane, name])
                return
        var side_wall := corridor.get_node("TurnOuterWall") as MeshInstance3D
        var wall_box := side_wall.mesh as BoxMesh
        var wall_end: float = side_wall.position.z + shape.lane_sign(lane) * wall_box.size.z * 0.5
        if absf(wall_end - (shape.end_z(lane) - shape.lane_sign(lane) * 0.63)) > 0.02:
            _fail("Corridor wall crosses the next room's sleeve: " + lane)
            return
        if corridor.has_node("OneWayGate"):
            _fail("Departure was locked before the player made a decision")
            return

    if (first.get_node("Architecture/FarExitWall") as MeshInstance3D).visible:
        _fail("Original solid wall still blocks the exits")
        return
    var far_collision := first.get_node("Architecture/FarExitWall_Collision") as StaticBody3D
    if far_collision == null:
        _fail("Original far-wall body disappeared")
        return
    for part in far_collision.get_children():
        if part is CollisionShape3D and not (part as CollisionShape3D).disabled:
            _fail("Original full wall's collision is still active")
            return

    # Looking straight through the original door must meet a *solid wall*
    # before the next hall comes into view, for BOTH left and right exits.
    for lane in ["left", "right"]:
        var from_pos := first.to_global(Vector3(-47.15, 1.65, shape.lane_z(lane)))
        var end_pos := first.to_global(Vector3(shape.BEND_X - 3.0, 1.65, shape.lane_z(lane)))
        var ray := PhysicsRayQueryParameters3D.create(from_pos, end_pos)
        ray.exclude = [player.get_rid()]
        var hit: Dictionary = first.get_world_3d().direct_space_state.intersect_ray(ray)
        if hit.is_empty() or not str((hit["collider"] as Node).name).begins_with("TurnOuterWall_Collision"):
            _fail("Direct sightline into the %s next room was not blocked by an opaque corner" % lane)
            return

    controller.call("_stage_next", "left")
    var second := controller.get("staged") as Node3D
    if second == null or second == first or second.get_parent() != root:
        _fail("The next independent hall was not preloaded")
        return
    if second.has_node("StreamingPortals/InitialEntryCap"):
        _fail("Staged rooms must NOT seal their arrival doors")
        return
    var staged_gi := second.get_node_or_null("VoxelGIRig") as Node3D
    if staged_gi == null:
        _fail("Staged hall lost its room-local VoxelGI rig")
        return
    if bool(staged_gi.get("streaming_active")):
        _fail("The preloaded room must defer expensive GI activation until approach")
        return
    for child in staged_gi.get_children():
        if child is VoxelGI and child.visible:
            _fail("Standby hall is rendering VoxelGI before the GI prewarm point")
            return
    var stage_fx := second.get_node_or_null("CasinoAtmosphere") as Node3D
    if stage_fx == null:
        _fail("Staged hall lost its reflection rig")
        return
    for child in stage_fx.get_children():
        if child is ReflectionProbe and child.visible:
            _fail("Standby rooms must not capture reflection probes")
            return
    for child in stage_fx.get_children():
        if child is OmniLight3D and child.name.begins_with("FurnitureFill_") \
                and child.visible:
            _fail("Uncommitted standby furniture fills must remain dark")
            return
    if second.has_node("Player") or second.has_node("LoopController"):
        _fail("Standby hall generated a second player or controller")
        return
    var entry_left := first.to_global(Vector3(shape.BEND_X, 0, shape.end_z("left")))
    if entry_left.distance_to(second.to_global(Vector3(0, 0, shape.ENTRY_Z))) > 0.02:
        _fail("The left bend does not meet the next room entrance")
        return
    var second_transform := second.global_transform

    # The next room remains beyond the L-shaped sightline, but its baked
    # GPU lighting must be prepared BEFORE the player can see its entrance.
    player.global_position = first.to_global(Vector3(-44.0, 1.02, shape.EXIT_Z_LEFT))
    controller.call("_process", 0.016)
    if not bool(staged_gi.get("streaming_active"))             or not bool(controller.get("staged_gi_warmed"))             or bool(controller.get("choice_taken")):
        _fail("Approach did not prewarm next-room VoxelGI before the exit choice")
        return
    await process_frame
    var next_baked: bool = bool(staged_gi.call("has_complete_bake"))
    var gi_setting: bool = bool(root.get_node("GameSettings").get_option("voxel_gi"))
    for probe in staged_gi.get_children():
        if probe is VoxelGI and (probe as VoxelGI).visible != (next_baked and gi_setting):
            _fail("A hidden staged room did not activate available baked GI on approach")
            return
    if not second.has_meta("_streaming_lighting_prepared"):
        _fail("The next hall's furniture and bar lights were not prewarmed")
        return
    for child in stage_fx.get_children():
        if child is OmniLight3D and child.name.begins_with("FurnitureFill_") \
                and not child.visible:
            _fail("A standby furniture light remained dark until room entry")
            return

    controller.call("_commit_choice", "left")
    if state.visited_loops != 1 or not state.round_ready:
        _fail("Crossing the left passage did not prepare the next round")
        return
    if not bool(controller.get("choice_taken")):
        _fail("The left choice was not permanently committed")
        return
    var plaque := shape.get_connector(first, "left").get_node_or_null("VerdictPlaque")
    if plaque == null or not (plaque is Node3D) \
            or plaque.get_node_or_null("NeutralFinding") == null:
        _fail("The chosen connector is missing its physical, neutral verdict plaque")
        return
    if shape.get_connector(first, "right").has_node("VerdictPlaque"):
        _fail("Unchosen corridor unexpectedly contains a verdict plaque")
        return
    if (first.get_node("Architecture") as Node3D).visible or (first.get_node("CasinoAtmosphere") as Node3D).visible or not shape.get_connector(first, "left").visible:
        _fail("Sealed casino still rendering or chosen corridor disappeared")
        return
    if not first.has_node("Architecture/NorthWestWall/StreamingOccluder"):
        _fail("Opaque structural wall is missing its occluder")
        return
    var old_rig := first.get_node("VoxelGIRig") as Node3D
    if bool(old_rig.get("streaming_active")) or not bool(staged_gi.get("streaming_active")):
        _fail("Committed departure must transfer the GI budget to the next room")
        return
    # Captures run across frames while we are still behind the opaque turn.
    await process_frame
    await process_frame
    await process_frame
    var staged_probe_count := 0
    for child in stage_fx.get_children():
        if child is ReflectionProbe:
            staged_probe_count += 1
            if not child.visible:
                _fail("A reflection probe still waits until room entry to switch on")
                return
    if staged_probe_count != 2:
        _fail("Expected both prewarmed casino reflection probes")
        return
    for lane in ["left", "right"]:
        var corridor := shape.get_connector(first, lane)
        var physical_gate := corridor.get_node_or_null("OneWayGate_Collision") as StaticBody3D
        if physical_gate == null or not corridor.has_node("OneWayGate"):
            _fail("Backtracking through the %s exit is still possible" % lane)
            return
        if physical_gate.collision_layer == 0:
            _fail("%s gate has no physical collision" % lane)
            return
        var shape_node := physical_gate.get_node_or_null("Shape") as CollisionShape3D
        if shape_node == null or shape_node.disabled:
            _fail("%s gate has no enabled blocking shape" % lane)
            return
    var score: int = int(state.visited_loops)
    controller.call("_stage_next", "right")
    if state.visited_loops != score or str(controller.get("staged_lane")) != "left"             or not second.global_transform.is_equal_approx(second_transform):
        _fail("A committed player can switch the already selected EXIT")
        return

    var next_anomaly := str(state.anomaly_id)
    player.global_position = first.to_global(
        Vector3(shape.BEND_X, 1.02, shape.end_z("left") + 4.4)
    )
    var old_pose := player.global_transform
    var lit_before_handoff: Array[bool] = []
    for probe in staged_gi.get_children():
        if probe is VoxelGI:
            lit_before_handoff.append((probe as VoxelGI).visible)
    var fills_before: Dictionary = {}
    var reflections_before: Dictionary = {}
    for child in stage_fx.get_children():
        if child is OmniLight3D and child.name.begins_with("FurnitureFill_"):
            fills_before[child.name] = child.visible
        if child is ReflectionProbe:
            reflections_before[child.name] = child.visible
    if fills_before.size() != 23 or reflections_before.size() != 2:
        _fail("Missing prewarmed atmosphere effects")
        return
    controller.call("_handoff")
    if current_scene != second or player.get_parent() != second             or controller.get_parent() != second:
        _fail("The staged room did not take over the original player/controller")
        return
    if player.global_position.distance_to(old_pose.origin) > 0.001:
        _fail("Room handoff teleported the first-person camera")
        return
    if second.get_node_or_null("ArrivalConnector/OneWayGate_Collision") == null:
        _fail("The passage behind the player vanished and exposed the void")
        return
    if second.get_node_or_null("ArrivalConnector/VerdictPlaque") == null:
        _fail("The corridor result was lost during the seamless handoff")
        return
    if second.get_node("WorldEnvironment").environment == null:
        _fail("The new room did not activate its original lighting")
        return
    if not bool(staged_gi.get("streaming_active")):
        _fail("Handoff switched off the prewarmed GI")
        return
    if second.has_meta("_streaming_lighting_prepared"):
        _fail("Temporary streaming light metadata leaked into the active room")
        return
    for child in stage_fx.get_children():
        if child is OmniLight3D and child.name.begins_with("FurnitureFill_") \
                and child.visible != bool(fills_before[child.name]):
            _fail("Bar or furniture light switched on during visible-room handoff")
            return
        if child is ReflectionProbe and child.visible != bool(reflections_before[child.name]):
            _fail("Reflected bar lighting switched on during visible-room handoff")
            return
    var index := 0
    for probe in staged_gi.get_children():
        if probe is VoxelGI:
            if (probe as VoxelGI).visible != lit_before_handoff[index]:
                _fail("VoxelGI visibility jumped exactly when the room was revealed")
                return
            index += 1
    await process_frame
    await process_frame
    await process_frame
    for child in (second.get_node("CasinoAtmosphere") as Node3D).get_children():
        if child is ReflectionProbe and not child.visible:
            _fail("Active hall should restore its reflections after handoff")
            return
    if is_instance_valid(first):
        _fail("The previous full casino room was not freed")
        return
    if str(state.anomaly_id) != next_anomaly:
        _fail("The preselected anomaly was lost during room handoff")
        return

    # Keep this ordinary-hall regression deterministic even when the new
    # traversal anomaly is present in the random catalog.
    state.anomaly_id = ""
    # The new room may have rotated 180 degrees relative to the last one.
    # Test the opposite turn from that new local coordinate system.
    controller.call("_schedule_stage_next", "right")
    if controller.get("staged") != null or controller.get("_pending_stage") == null             or int(controller.get("_pending_stage_phase")) != 1:
        _fail("Incremental staging did not defer portal and SceneTree work")
        return
    await process_frame
    controller.call("_schedule_stage_next", "right")
    if int(controller.get("_pending_stage_phase")) != 2             or controller.get("staged") != null:
        _fail("Incremental staging did not isolate portal preparation")
        return
    await process_frame
    controller.call("_schedule_stage_next", "right")
    var third := controller.get("staged") as Node3D
    if third == null or controller.get("_pending_stage") != null:
        _fail("Incremental staging did not attach the third continuous loop")
        return
    var third_entry := second.to_global(
        Vector3(shape.BEND_X, 0, shape.end_z("right"))
    )
    if third_entry.distance_to(third.to_global(Vector3(0, 0, shape.ENTRY_Z))) > 0.02:
        _fail("Right turn is spatially misaligned after a rotated hall")
        return
    controller.call("_commit_choice", "right")
    var third_rig := third.get_node_or_null("VoxelGIRig") as Node3D
    if third_rig == null or not bool(third_rig.get("streaming_active")):
        _fail("A rapid second loop missed its mandatory GI prewarm")
        return
    if state.visited_loops != 2:
        _fail("The second left/right choice was not counted")
        return
    for lane in ["left", "right"]:
        if not shape.get_connector(second, lane).has_node("OneWayGate_Collision"):
            _fail("Second loop did not close both reverse paths")
            return

    # A player can move sideways immediately after the entrance sleeve.
    # Exercise the actual frame-driven handoff rather than forcing it.
    player.global_position = second.to_global(
        Vector3(shape.BEND_X + 2.1, 1.02, shape.end_z("right") - 1.4)
    )
    var another_pose := player.global_transform
    controller.call("_process", 0.016)
    if current_scene != third or player.global_position.distance_to(another_pose.origin) > 0.001:
        _fail("Second handoff moved the player")
        return
    await process_frame
    await process_frame
    if is_instance_valid(second):
        _fail("Second old hall survived after the next handoff")
        return
    if third.get_node_or_null("ArrivalConnector/OneWayGate_Collision") == null:
        _fail("Third hall still allows looking out through its unloaded predecessor")
        return
    if third.find_children("LoopController", "Node3D", false, false).size() != 1:
        _fail("Multiple loop controllers survived a handoff")
        return

    third.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
    print("Casino Anomaly seamless two-room streaming QA PASS")
    quit(0)
