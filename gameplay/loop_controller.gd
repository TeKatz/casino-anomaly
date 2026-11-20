extends Node3D
## Seamless Exit-8-style spatial streaming.
## At most two authored casino rooms coexist briefly: active + next.
## All edits to walls/doors and all connector meshes are runtime-only.
## The two EXITs turn away from each other behind opaque corners. Once the
## player commits, both exits are sealed behind them, and the selected
## connector stays with the new room after the old hall has been freed.
## No camera teleports, fades or extra button presses.

const DemoAnomalies = preload("res://gameplay/demo_anomalies.gd")
const NeonLevelSign = preload("res://gameplay/neon_level_sign.gd")
const AnomalyDevMenu = preload("res://ui/anomaly_dev_menu.gd")
const StreamPortals = preload("res://gameplay/stream_portals.gd")
const Loc = preload("res://gameplay/localization.gd")
const ROOM = preload("res://main.tscn")

const PRELOAD_AT_X := -31.0
# Prepare GPU-backed baked GI while the next casino is still hidden by the
# opaque L-bend. There is enough corridor before the entrance for upload.
const GI_PREWARM_AT_X := -43.0
const CHOICE_AT_X := -49.10
const HANDOFF_AFTER_TURN := 4.20
const LANE_HALF_WIDTH := 1.07
const TURN_X_TOLERANCE := 1.60
const EXIT_Z_LEFT := -3.70
const EXIT_Z_RIGHT := -9.65

var room: Node3D
var player: CharacterBody3D
var doors: Node3D
var demo: RefCounted
var portals: RefCounted
var staged: Node3D
var staged_environment: Environment
var staged_lane := ""
var staged_gi_warmed := false
var choice_taken := false
var transitioning := false
var finishing := false
var won := false


func _ready() -> void:
    room = get_parent() as Node3D
    player = room.get_node_or_null("Player") as CharacterBody3D
    if player == null:
        push_error("Streaming controller needs the original Player")
        queue_free()
        return
    portals = StreamPortals.new()
    if not portals.prepare_room(room):
        push_error("Could not open the authored casino's exit portals")
        queue_free()
        return
    if not portals.seal_initial_entrance(room):
        push_error("Could not cap the initial casino entrance")
        queue_free()
        return

    demo = DemoAnomalies.new()
    doors = Node3D.new()
    doors.name = "DoorChoices"
    add_child(doors)
    if not _place_markers():
        push_error("Casino needs both original EXIT signs as portal markers")
        queue_free()
        return
    var settings = get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_language_changed)
    var state = get_node_or_null("/root/LoopState")
    if state == null:
        queue_free()
        return
    var available: Array[String] = demo.available_ids(room)
    state.prepare_round(available)
    demo.apply(room, str(state.anomaly_id))
    _update_level_sign(room, int(state.correct_streak), false)
    # Parent to the persistent player so the developer overlay follows all
    # no-teleport room handoffs without ever appearing in the normal HUD.
    if player.get_node_or_null("AnomalyDevMenu") == null:
        var dev_menu := AnomalyDevMenu.new()
        dev_menu.name = "AnomalyDevMenu"
        player.add_child(dev_menu)


func debug_available_ids() -> Array[String]:
    var target_room := staged if staged != null and is_instance_valid(staged) else room
    return demo.available_ids(target_room)


func debug_select_next_anomaly(id: String) -> bool:
    if won or finishing or transitioning:
        return false
    var state = get_node_or_null("/root/LoopState")
    if state == null:
        return false
    var available := debug_available_ids()
    if choice_taken:
        # The next room has already been populated. Replace its effect and
        # saved verdict together, without mutating the current casino room.
        if not state.debug_replace_prepared_round(id, available):
            return false
        return demo.apply(staged, id)
    return state.debug_queue_next_round(id, available)


func debug_restore_random() -> bool:
    if won or finishing or transitioning:
        return false
    var state = get_node_or_null("/root/LoopState")
    if state == null:
        return false
    if choice_taken:
        if not state.debug_reroll_prepared_round(debug_available_ids()):
            return false
        return demo.apply(staged, str(state.anomaly_id))
    state.debug_clear_next_round()
    return true


func _exit_tree() -> void:
    # Prevent a preloaded second hall from remaining in SceneTree if ESC
    # switches to the menu before a player enters a portal.
    if staged != null and is_instance_valid(staged):
        staged.queue_free()
        staged = null


func _place_markers() -> bool:
    for child in doors.get_children():
        child.free()
    var signs: Array[Label3D] = []
    var architecture := room.get_node_or_null("Architecture") as Node3D
    if architecture == null:
        return false
    for part in architecture.get_children():
        if part is Label3D and (part as Label3D).text in ["EXIT", "ANOMALIE", "ANOMALY", "NORMAL"]:
            signs.append(part as Label3D)
    if signs.size() != 2:
        return false
    signs.sort_custom(func(a: Label3D, b: Label3D) -> bool:
        return room.to_local(a.global_position).z > room.to_local(b.global_position).z
    )
    for i in range(2):
        var marker := Marker3D.new()
        marker.name = "LeftDoor" if i == 0 else "RightDoor"
        doors.add_child(marker)
        var local := room.to_local(signs[i].global_position)
        marker.global_position = room.to_global(Vector3(local.x, 1.6, local.z))
    return true


func _on_language_changed(key: String) -> void:
    if key != "language":
        return
    _refresh_exit_signs(room)
    if staged != null and is_instance_valid(staged):
        _refresh_exit_signs(staged)
    var state = get_node_or_null("/root/LoopState")
    if state != null:
        _update_level_sign(room, int(state.correct_streak), won)
        if staged != null and is_instance_valid(staged):
            _update_level_sign(staged, int(state.correct_streak), finishing)


func _update_level_sign(target_room: Node3D, level: int, complete: bool) -> void:
    if target_room == null or not is_instance_valid(target_room):
        return
    var sign := target_room.get_node_or_null("NeonLevelSign") as Node3D
    if sign == null:
        sign = NeonLevelSign.new() as Node3D
        sign.name = "NeonLevelSign"
        target_room.add_child(sign)
    sign.call("set_progress", level, complete,
        Loc.t("world.victory", self) if complete else "")


func _refresh_exit_signs(target_room: Node3D) -> void:
    if target_room == null:
        return
    var architecture := target_room.get_node_or_null("Architecture") as Node3D
    if architecture == null:
        return
    for node in architecture.get_children():
        if node is Label3D and (node.text in ["ANOMALIE", "ANOMALY", "NORMAL"]):
            var left_side: bool = absf(node.position.z - EXIT_Z_LEFT) < 0.6
            node.text = Loc.t("world.anomaly", self) if left_side else Loc.t("world.normal", self)


func _candidate_lane(local_z: float) -> String:
    return "left" if absf(local_z - EXIT_Z_LEFT) <= absf(local_z - EXIT_Z_RIGHT) else "right"


func _lane_z(lane: String) -> float:
    return EXIT_Z_LEFT if lane == "left" else EXIT_Z_RIGHT


func _process(_delta: float) -> void:
    if transitioning or won or room == null or player == null:
        return
    var local := room.to_local(player.global_position)
    if local.x < PRELOAD_AT_X and not choice_taken:
        _stage_next(_candidate_lane(local.z))
    # The second room is still completely out of view here. Enabling its
    # already-loaded VoxelGI data now avoids the obvious post-entry pop.
    if local.x < GI_PREWARM_AT_X and not choice_taken:
        _prewarm_next_gi()

    if not choice_taken:
        var lane := _candidate_lane(local.z)
        if local.x < CHOICE_AT_X and absf(local.z - _lane_z(lane)) <= LANE_HALF_WIDTH:
            _commit_choice(lane)
    elif not staged_lane.is_empty():
        # The player first walks west through an EXIT, then turns left (+Z)
        # or right (-Z). Hand off well inside the NEXT hall, when its
        # entrance is behind the player. Never rely on an X-only threshold.
        var turned_distance: float = (local.z - _lane_z(staged_lane)) * portals.lane_sign(staged_lane)
        if absf(local.x - portals.BEND_X) <= TURN_X_TOLERANCE                 and turned_distance >= portals.TURN_LENGTH + HANDOFF_AFTER_TURN:
            _handoff()


func _stage_transform(lane: String) -> Transform3D:
    # The first leg moves west, then LEFT heads +Z and RIGHT heads -Z
    # in room-local coordinates. Align the new hall's actual entrance
    # to the END of the bent corridor, not the beginning of the turn.
    # A 180-degree rotation sends the left entrance's inward -Z to +Z;
    # the right entrance's inward -Z already points along the right leg.
    var yaw := PI if lane == "left" else 0.0
    var basis := Basis(Vector3.UP, yaw)
    var desired_entrance := Vector3(portals.BEND_X, 0, portals.end_z(lane))
    var offset := desired_entrance - basis * Vector3(0, 0, portals.ENTRY_Z)
    return room.global_transform * Transform3D(basis, offset)


func _stage_next(lane: String) -> void:
    if choice_taken:
        return
    if staged != null and is_instance_valid(staged):
        if staged_lane != lane:
            staged.global_transform = _stage_transform(lane)
            staged_lane = lane
        return

    # Prewarm well ahead of the exits. Godot caches the PackedScene and all
    # shared textures; only the scene nodes/physics are instantiated twice.
    var next := ROOM.instantiate() as Node3D
    if next == null:
        push_error("Cannot preload next casino hall")
        return
    next.set_meta("_streaming_standby", true)
    var duplicate_player := next.get_node_or_null("Player")
    if duplicate_player != null:
        duplicate_player.free()
    if not portals.prepare_room(next):
        next.free()
        return
    # UPDATE_ONCE probes would otherwise capture the next casino's six views
    # while the previous hall is still visible, causing a loading hitch.
    _set_reflections_visible(next, false)
    var environment_node := next.get_node_or_null("WorldEnvironment") as WorldEnvironment
    staged_environment = environment_node.environment if environment_node != null else null
    if environment_node != null:
        environment_node.environment = null
    next.transform = _stage_transform(lane)
    get_tree().root.add_child(next)
    var state = get_node_or_null("/root/LoopState")
    if state != null:
        _update_level_sign(next, int(state.correct_streak), false)
    staged = next
    staged_lane = lane
    staged_gi_warmed = false


func _prewarm_next_gi() -> void:
    if staged_gi_warmed or staged == null or not is_instance_valid(staged):
        return
    var rig := staged.get_node_or_null("VoxelGIRig") as Node3D
    if rig == null:
        return
    # The standby metadata intentionally stays set to suppress the second
    # player, reflection captures and furniture fills. The GI streaming gate
    # is independent: we can render cached probes before the room handoff.
    rig.call("set_streaming_active", true)
    staged_gi_warmed = true


func _set_reflections_visible(target_room: Node3D, enabled: bool) -> void:
    var atmosphere := target_room.get_node_or_null("CasinoAtmosphere") as Node3D
    if atmosphere == null:
        return
    for child in atmosphere.get_children():
        if child is ReflectionProbe:
            (child as ReflectionProbe).visible = enabled


func _activate_reflections_sequentially(target_room: Node3D) -> void:
    var atmosphere := target_room.get_node_or_null("CasinoAtmosphere") as Node3D
    if atmosphere == null:
        return
    for child in atmosphere.get_children():
        if not (child is ReflectionProbe):
            continue
        await get_tree().process_frame
        if not is_instance_valid(target_room) or not target_room.is_inside_tree():
            return
        (child as ReflectionProbe).visible = true


func _commit_choice(lane: String) -> void:
    _stage_next(lane)
    if staged == null or not is_instance_valid(staged):
        return # Keep the current loop safe if staging fails.
    var state = get_node_or_null("/root/LoopState")
    if state == null:
        return
    var verdict: Dictionary = state.decide(lane == "left")
    if not bool(verdict.get("valid", false)):
        return
    # By now the character is safely beyond x=-49.1. Both physical gates
    # appear behind at x=-47.7, closing the chosen path and the other exit.
    # This prevents switching the decision or reaching the void outside a
    # preloaded hall, even if the player immediately turns around.
    if not portals.lock_departure(room, lane):
        push_error("Failed to seal the departure corridors")
        return
    # The player is now behind the departure gates. Ensure the next hall's
    # GI has been initialized even if they rushed past the prewarm trigger.
    _prewarm_next_gi()
    # Avoid keeping four high-resolution GI volumes active simultaneously
    # through the connector. The departure room is no longer in view.
    var departing_rig := room.get_node_or_null("VoxelGIRig") as Node3D
    if departing_rig != null:
        departing_rig.call("set_streaming_active", false)
    choice_taken = true
    demo.clear()
    finishing = bool(verdict.get("finished", false))
    _update_level_sign(staged, int(verdict.get("streak", 0)), finishing)
    if finishing:
        # Enter the final hall naturally; never stop the character inside
        # a connector or cover their view with a victory overlay.
        return

    # Populate the NEXT room while the player is still in the connector.
    # The previous room stays visible behind them until the exit handoff.
    var candidates: Array[String] = demo.available_ids(staged)
    state.prepare_round(candidates)
    demo.apply(staged, str(state.anomaly_id))


func _handoff() -> void:
    if staged == null or not is_instance_valid(staged):
        return
    transitioning = true
    var previous := room
    var upcoming := staged
    # The chosen bent connector must survive the old hall's destruction.
    # Its closed far end remains visible and collidable when looking back
    # from the new hall; no outside-the-level view is ever exposed.
    if not portals.adopt_arrival_connector(previous, upcoming, staged_lane):
        push_error("Failed to retain the sealed arrival corridor")
        transitioning = false
        return
    staged = null
    staged_lane = ""
    staged_gi_warmed = false
    choice_taken = false

    # Preserve the single CharacterBody3D and its live controller.
    # No camera cut, teleport, or orientation change occurs at handoff.
    player.reparent(upcoming, true)
    reparent(upcoming, true)
    room = upcoming
    var environment_node := upcoming.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if environment_node != null:
        environment_node.environment = staged_environment
    if upcoming.has_method("apply_image_contrast"):
        upcoming.call("apply_image_contrast")
    upcoming.remove_meta("_streaming_standby")
    get_tree().current_scene = upcoming
    previous.queue_free()
    # Reuse the ALREADY ACTIVE baked GI. Never turn it off/on at the scene
    # swap: even one deferred frame would create a visible light pop.
    var arrival_rig := upcoming.get_node_or_null("VoxelGIRig") as Node3D
    if arrival_rig != null:
        arrival_rig.call("set_streaming_active", true)
    # Render interior probes only after the old hall is gone. Each capture
    # occurs on a separate frame; no room geometry or camera is teleported.
    _activate_reflections_sequentially(upcoming)
    _place_markers()
    if finishing:
        # Both dead-end connectors are physically closed in the final room.
        # The player is free to look around and see the neon 12.
        portals.lock_departure(upcoming, "left")
        won = true
        finishing = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    transitioning = false
