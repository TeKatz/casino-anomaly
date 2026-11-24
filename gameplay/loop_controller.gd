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
const Backrooms = preload("res://gameplay/backrooms_traversal.gd")
const FlashlightPickup = preload("res://gameplay/backrooms_flashlight_pickup.gd")
const BACKROOMS_ID := "backrooms"

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
var _stage_spike_frames := 0
# Normal gameplay distributes scene assembly, portal geometry and SceneTree
# activation across consecutive frames instead of forcing all three at the
# invisible threshold. _stage_next() remains the immediate safety fallback.
var _pending_stage: Node3D
var _pending_lane := ""
var _pending_stage_phase := 0
var _pending_stage_start_us := 0
var _pending_instance_ms := 0.0
var backrooms_active := false
var backrooms_maze: Node3D
var backrooms_lane := ""
var backrooms_environment: Environment
var backrooms_exit_connector: Node3D
var backrooms_pickup: Node3D
var backrooms_scored := false
var _pending_portal_ms := 0.0


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
	if backrooms_active:
		return []
	var target_room := staged if staged != null and is_instance_valid(staged) else room
	return demo.available_ids(target_room)


func debug_select_next_anomaly(id: String) -> bool:
	if won or finishing or transitioning or backrooms_active:
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
	if won or finishing or transitioning or backrooms_active:
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
	# Reparenting the persistent controller temporarily exits the tree.
	# Ownership only ends on actual scene teardown, not on a handoff.
	if transitioning:
		return
	if is_instance_valid(backrooms_maze) and backrooms_maze != room:
		backrooms_maze.queue_free()
	if backrooms_active:
		var sound := get_node_or_null("/root/AudioDirector")
		if sound != null:
			sound.call("set_backrooms_mode", false)
	# Both attached standby rooms and not-yet-attached partial instances
	# belong to this controller; leaving for the menu must release both.
	if _pending_stage != null and is_instance_valid(_pending_stage):
		_pending_stage.free()
		_pending_stage = null
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
	if backrooms_active:
		if key == "voxel_gi":
			var settings := get_node_or_null("/root/GameSettings")
			var probe := room.get_node_or_null("Lighting/BackroomsVoxelGI") as VoxelGI
			if probe != null and settings != null:
				probe.visible = bool(settings.get_option("voxel_gi"))
		if key == "language" and is_instance_valid(staged):
			_refresh_exit_signs(staged)
		return
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


func _process(delta: float) -> void:
	# The node creation and deferred setup phases land on separate frames.
	# Report any frame-time spike around staging so a remaining stall can
	# be attributed to the exact phase instead of guessing.
	if _stage_spike_frames > 0:
		if delta > 0.08:
			print("Casino streaming frame spike: %.1f ms (%d frames after staging)" %
				[delta * 1000.0, 13 - _stage_spike_frames])
		_stage_spike_frames -= 1
	if transitioning or won or room == null or player == null:
		return
	if backrooms_active:
		_process_backrooms()
		return
	var local := room.to_local(player.global_position)
	if not choice_taken and _backrooms_selected():
		_process_backrooms_approach(local)
		return
	if local.x < PRELOAD_AT_X and not choice_taken:
		_schedule_stage_next(_candidate_lane(local.z))
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
	if not choice_taken and _backrooms_selected() and not backrooms_active:
		_stage_backrooms(lane)
		return
	# Immediate path for developer/integration calls and for a player who
	# somehow reaches the choice gate before three staging frames have run.
	if choice_taken:
		return
	if staged != null and is_instance_valid(staged):
		if staged_lane != lane:
			staged.global_transform = _stage_transform(lane)
			staged_lane = lane
		return
	for ignored in range(3):
		if staged != null or _pending_stage == null and _pending_stage_phase == 0 and ignored > 0:
			break
		_advance_pending_stage(lane)


func _schedule_stage_next(lane: String) -> void:
	if not choice_taken and _backrooms_selected() and not backrooms_active:
		_stage_backrooms(lane)
		return
	# One bounded stage per _process frame. The threshold is far ahead of
	# the exit gate, so ordinary walking leaves plenty of preparation time.
	if staged != null and is_instance_valid(staged):
		if staged_lane != lane:
			staged.global_transform = _stage_transform(lane)
			staged_lane = lane
		return
	_advance_pending_stage(lane)


func _advance_pending_stage(lane: String) -> void:
	if _pending_stage == null:
		_pending_stage_start_us = Time.get_ticks_usec()
		var next := ROOM.instantiate() as Node3D
		_pending_instance_ms = float(Time.get_ticks_usec() - _pending_stage_start_us) / 1000.0
		if next == null:
			push_error("Cannot preload next casino hall")
			return
		next.set_meta("_streaming_standby", true)
		var duplicate_player := next.get_node_or_null("Player")
		if duplicate_player != null:
			duplicate_player.free()
		_pending_stage = next
		_pending_lane = lane
		_pending_stage_phase = 1
		_stage_spike_frames = 12
		return

	_pending_lane = lane
	if _pending_stage_phase == 1:
		var portal_start_us := Time.get_ticks_usec()
		if not portals.prepare_room(_pending_stage):
			_pending_stage.free()
			_pending_stage = null
			_pending_stage_phase = 0
			staged_environment = null
			return
		_pending_portal_ms = float(Time.get_ticks_usec() - portal_start_us) / 1000.0
		# Prevent expensive one-shot captures and duplicate WorldEnvironment
		# while the room remains invisible beyond the opaque bend.
		_set_reflections_visible(_pending_stage, false)
		var environment_node := _pending_stage.get_node_or_null("WorldEnvironment") as WorldEnvironment
		staged_environment = environment_node.environment if environment_node != null else null
		if environment_node != null:
			environment_node.environment = null
		_pending_stage_phase = 2
		return

	if _pending_stage_phase == 2:
		var next := _pending_stage
		next.transform = _stage_transform(lane)
		var attach_start_us := Time.get_ticks_usec()
		get_tree().root.add_child(next)
		var attach_ms := float(Time.get_ticks_usec() - attach_start_us) / 1000.0
		if _pending_instance_ms >= 16.7 or _pending_portal_ms >= 16.7 or attach_ms >= 16.7:
			print("Casino staging: instantiate=%.1f ms, portals=%.1f ms, attach/ready=%.1f ms (spread across frames)" %
				[_pending_instance_ms, _pending_portal_ms, attach_ms])
		var state = get_node_or_null("/root/LoopState")
		if state != null:
			_update_level_sign(next, int(state.correct_streak), false)
		staged = next
		staged_lane = lane
		staged_gi_warmed = false
		_pending_stage = null
		_pending_lane = ""
		_pending_stage_phase = 0
		_stage_spike_frames = 12


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
	var atmosphere := staged.get_node_or_null("CasinoAtmosphere") as Node3D
	if atmosphere != null and atmosphere.has_method("prewarm_streaming_lights"):
		atmosphere.call("prewarm_streaming_lights")
	staged_gi_warmed = true


func _set_reflections_visible(target_room: Node3D, enabled: bool) -> void:
	var atmosphere := target_room.get_node_or_null("CasinoAtmosphere") as Node3D
	if atmosphere == null:
		return
	for child in atmosphere.get_children():
		if child is ReflectionProbe:
			(child as ReflectionProbe).visible = enabled


func _activate_reflections_sequentially(target_room: Node3D) -> void:
	# This is launched from the committed, still-opaque connector, NEVER
	# from the visible-room handoff. Capture one probe per frame to avoid
	# a two-probe GPU spike when entering the casino.
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
	if choice_taken:
		return
	if _backrooms_selected():
		# The binary choice is not committed at the ordinary threshold.
		# Only the actual blind-corner crossing enters this special round.
		_stage_backrooms(lane)
		return
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
	if not portals.mount_verdict(room, lane, verdict):
		push_warning("Could not mount world-space decision review in chosen passage")
	# The player is now behind the departure gates. Ensure the next hall's
	# GI has been initialized even if they rushed past the prewarm trigger.
	_prewarm_next_gi()
	# Open the new room's spatial soundscape before the visual handoff.
	var soundscape := staged.get_node_or_null("RoomSoundscape") as Node3D
	if soundscape != null:
		soundscape.call("activate")
	# Avoid keeping four high-resolution GI volumes active simultaneously
	# through the connector. The departure room is no longer in view.
	var departing_rig := room.get_node_or_null("VoxelGIRig") as Node3D
	if departing_rig != null:
		departing_rig.call("set_streaming_active", false)
	choice_taken = true
	# Reflection probes used to turn on one/two frames AFTER the handoff;
	# reflected ceiling/bar highlights visibly popped into view. Start
	# their one-shot capture while hidden around the blind L-corner.
	_activate_reflections_sequentially(staged)
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
	if backrooms_active:
		return
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
	upcoming.remove_meta("_streaming_lighting_prepared")
	get_tree().current_scene = upcoming
	previous.queue_free()
	# Reuse the ALREADY ACTIVE baked GI. Never turn it off/on at the scene
	# swap: even one deferred frame would create a visible light pop.
	var arrival_rig := upcoming.get_node_or_null("VoxelGIRig") as Node3D
	if arrival_rig != null:
		arrival_rig.call("set_streaming_active", true)
	# Both reflection captures and all furniture fills were prepared in
	# the blind connector; neither is toggled after the room is visible.
	_place_markers()
	if finishing:
		# Both dead-end connectors are physically closed in the final room.
		# The player is free to look around and see the neon 12.
		portals.lock_departure(upcoming, "left")
		won = true
		finishing = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	transitioning = false


func _backrooms_selected() -> bool:
	var state = get_node_or_null("/root/LoopState")
	return state != null and state.round_ready and str(state.anomaly_id) == BACKROOMS_ID


func _process_backrooms_approach(local: Vector3) -> void:
	if local.x >= PRELOAD_AT_X:
		return
	var lane := _candidate_lane(local.z)
	_stage_backrooms(lane)
	if not is_instance_valid(backrooms_maze):
		return
	var distance: float = (local.z - _lane_z(lane)) * portals.lane_sign(lane)
	if absf(local.x - portals.BEND_X) <= 1.15 and distance >= 2.1:
		_enter_backrooms(lane)


func _stage_backrooms(lane: String) -> void:
	if backrooms_active:
		return
	if is_instance_valid(backrooms_maze):
		if backrooms_lane != lane:
			backrooms_maze.global_transform = Backrooms.entrance_transform(room, portals, lane)
			backrooms_lane = lane
		return
	# A stale normal standby is never allowed to coexist with the maze.
	if is_instance_valid(_pending_stage):
		_pending_stage.free()
		_pending_stage = null
		_pending_stage_phase = 0
	if is_instance_valid(staged):
		staged.free()
		staged = null
		staged_lane = ""
		staged_gi_warmed = false
	var maze := Backrooms.MAZE.instantiate() as Node3D
	if maze == null:
		push_error("Backrooms scene cannot be staged")
		return
	var preview := maze.get_node_or_null("PreviewCamera")
	if preview != null:
		preview.free()
	var env := maze.get_node("Lighting/Environment") as WorldEnvironment
	backrooms_environment = env.environment
	env.environment = null
	var lighting := maze.get_node("Lighting") as Node3D
	lighting.hide()
	maze.transform = Backrooms.entrance_transform(room, portals, lane)
	Backrooms.build_entrance(maze)
	backrooms_exit_connector = Backrooms.build_exit(maze)
	get_tree().root.add_child(maze)
	backrooms_maze = maze
	backrooms_lane = lane


func _enter_backrooms(lane: String) -> void:
	if backrooms_active or not is_instance_valid(backrooms_maze) or backrooms_lane != lane:
		return
	var previous := room
	var connector := portals.get_connector(previous, lane) as Node3D
	if connector == null or not portals.lock_departure(previous, lane):
		return
	transitioning = true
	# Seal immediately behind the corner, not inside the player capsule.
	var direction: float = portals.lane_sign(lane)
	var gate_mat: Material = (connector.get_node("TurnOuterWall") as MeshInstance3D).material_override
	Backrooms.box(connector, "BackroomsRevealGate", Vector3(portals.BEND_X, 1.76, _lane_z(lane) + direction * 0.55),
		Vector3(2.62, 3.52, 0.20), gate_mat)
	for child in connector.get_children():
		if child is Light3D:
			(child as Light3D).hide()
	connector.reparent(backrooms_maze, true)
	connector.name = "BackroomsArrivalConnector"
	var old_env := previous.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if old_env != null:
		old_env.environment = null
	var old_rig := previous.get_node_or_null("VoxelGIRig")
	if old_rig != null:
		old_rig.call("set_streaming_active", false)
	demo.clear()
	backrooms_active = true
	choice_taken = true
	backrooms_scored = false
	player.reparent(backrooms_maze, true)
	reparent(backrooms_maze, true)
	room = backrooms_maze
	get_tree().current_scene = room
	var env := room.get_node("Lighting/Environment") as WorldEnvironment
	env.environment = backrooms_environment
	(room.get_node("Lighting") as Node3D).show()
	var settings := get_node_or_null("/root/GameSettings")
	var probe := room.get_node_or_null("Lighting/BackroomsVoxelGI") as VoxelGI
	if probe != null and settings != null and not bool(settings.get_option("voxel_gi")):
		probe.hide()
	player.call("set_backrooms_mode", true)
	var sound := get_node_or_null("/root/AudioDirector")
	if sound != null:
		sound.call("set_backrooms_mode", true)
		var hum := AudioStreamPlayer.new()
		hum.name = "BackroomsHum"
		hum.stream = sound.call("get_immersion_loop", "backrooms_hum") as AudioStream
		hum.bus = "WORLD"
		hum.volume_db = -15.0
		room.add_child(hum)
		if hum.stream != null:
			hum.play()
	# A small wall-side stand leaves the first passage unobstructed.
	var stand_mat := StandardMaterial3D.new()
	stand_mat.albedo_color = Color(0.27, 0.24, 0.19)
	Backrooms.box(room, "FlashlightStand", Vector3(-14.5, 0.38, -0.52), Vector3(0.42, 0.76, 0.40), stand_mat)
	backrooms_pickup = FlashlightPickup.new() as Node3D
	backrooms_pickup.name = "FlashlightPickup"
	backrooms_pickup.position = Vector3(-14.5, 0.84, -0.52)
	room.add_child(backrooms_pickup)
	previous.hide()
	previous.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	transitioning = false


func _physics_process(_delta: float) -> void:
	if backrooms_active and is_instance_valid(backrooms_pickup):
		backrooms_pickup.call("update_prompt", player)


func _unhandled_input(event: InputEvent) -> void:
	if not backrooms_active or not is_instance_valid(backrooms_pickup):
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
		if bool(backrooms_pickup.call("collect", player)):
			get_viewport().set_input_as_handled()


func _process_backrooms() -> void:
	var local := room.to_local(player.global_position)
	if local.distance_to(Vector3(Backrooms.EXIT_X, local.y, Backrooms.EXIT_Z)) < 10.0:
		_stage_backrooms_return()
	if local.x > Backrooms.EXIT_X + 1.3 and absf(local.z - Backrooms.EXIT_Z) < 1.1 and not backrooms_scored:
		_finish_backrooms()
	if backrooms_scored and local.x > Backrooms.EXIT_X + Backrooms.EXIT_LENGTH + HANDOFF_AFTER_TURN and absf(local.z - Backrooms.EXIT_Z) < 1.6:
		_handoff_backrooms_return()


func _stage_backrooms_return() -> void:
	if is_instance_valid(staged):
		return
	var next := ROOM.instantiate() as Node3D
	if next == null:
		return
	next.set_meta("_streaming_standby", true)
	var duplicate_player := next.get_node_or_null("Player")
	if duplicate_player != null:
		duplicate_player.free()
	if not portals.prepare_room(next):
		next.free()
		return
	_set_reflections_visible(next, false)
	var environment_node := next.get_node_or_null("WorldEnvironment") as WorldEnvironment
	staged_environment = environment_node.environment if environment_node != null else null
	if environment_node != null:
		environment_node.environment = null
	next.transform = Backrooms.return_transform(room, portals.ENTRY_Z)
	get_tree().root.add_child(next)
	staged = next
	staged_gi_warmed = false
	Backrooms.open_return(backrooms_exit_connector)
	var state = get_node_or_null("/root/LoopState")
	if state != null:
		_update_level_sign(next, int(state.correct_streak), false)
	_prewarm_next_gi()


func _finish_backrooms() -> void:
	if not backrooms_active or backrooms_scored:
		return
	_stage_backrooms_return()
	if not is_instance_valid(staged):
		return
	var state = get_node_or_null("/root/LoopState")
	if state == null:
		return
	var verdict: Dictionary = state.complete_backrooms(backrooms_lane == "left")
	if not bool(verdict.get("valid", false)):
		return
	backrooms_scored = true
	Backrooms.seal_exit(backrooms_exit_connector)
	finishing = bool(verdict.get("finished", false))
	_update_level_sign(staged, int(verdict["streak"]), finishing)
	if not finishing:
		var candidates: Array[String] = demo.available_ids(staged)
		state.prepare_round(candidates)
		demo.apply(staged, str(state.anomaly_id))
	var soundscape := staged.get_node_or_null("RoomSoundscape")
	if soundscape != null:
		soundscape.call("activate")
	_activate_reflections_sequentially(staged)


func _handoff_backrooms_return() -> void:
	if not backrooms_active or not backrooms_scored or not is_instance_valid(staged):
		return
	transitioning = true
	var previous := room
	var upcoming := staged
	backrooms_exit_connector.reparent(upcoming, true)
	backrooms_exit_connector.name = "ArrivalConnector"
	player.call("set_backrooms_mode", false)
	var sound := get_node_or_null("/root/AudioDirector")
	if sound != null:
		sound.call("set_backrooms_mode", false)
	var old_env := previous.get_node("Lighting/Environment") as WorldEnvironment
	old_env.environment = null
	var old_probe := previous.get_node_or_null("Lighting/BackroomsVoxelGI") as VoxelGI
	if old_probe != null:
		old_probe.hide()
	player.reparent(upcoming, true)
	reparent(upcoming, true)
	room = upcoming
	var environment_node := upcoming.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node != null:
		environment_node.environment = staged_environment
	if upcoming.has_method("apply_image_contrast"):
		upcoming.call("apply_image_contrast")
	upcoming.remove_meta("_streaming_standby")
	upcoming.remove_meta("_streaming_lighting_prepared")
	get_tree().current_scene = upcoming
	previous.hide()
	previous.queue_free()
	staged = null
	staged_lane = ""
	staged_gi_warmed = false
	choice_taken = false
	backrooms_active = false
	backrooms_scored = false
	backrooms_maze = null
	backrooms_lane = ""
	backrooms_environment = null
	backrooms_exit_connector = null
	backrooms_pickup = null
	_place_markers()
	if finishing:
		portals.lock_departure(upcoming, "left")
		won = true
		finishing = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	transitioning = false
