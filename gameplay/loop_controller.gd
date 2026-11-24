extends Node3D
const StreamingTrace = preload("res://gameplay/streaming_trace.gd")
## Seamless Exit-8-style spatial streaming.
## At most two authored casino rooms coexist briefly: active + next.
## All edits to walls/doors and all connector meshes are runtime-only.
## The two EXITs turn away from each other behind opaque corners. Once the
## player commits, both exits are sealed behind them, and the selected
## connector stays with the new room after the old hall has been freed.
## No camera teleports, fades or extra button presses.

const RuntimeCache = preload("res://gameplay/runtime_asset_cache.gd")
const RoomAssembly = preload("res://gameplay/room_assembly.gd")
const RoomDisposal = preload("res://gameplay/room_disposal.gd")
const Modes = preload("res://gameplay/run_modes.gd")
const Controls = preload("res://gameplay/input_bindings.gd")
const DemoAnomalies = preload("res://gameplay/demo_anomalies.gd")
const NeonLevelSign = preload("res://gameplay/neon_level_sign.gd")
const AnomalyDevMenu = preload("res://ui/anomaly_dev_menu.gd")
const StreamPortals = preload("res://gameplay/stream_portals.gd")
const Loc = preload("res://gameplay/localization.gd")
const ROOM = preload("res://main.tscn")
const Backrooms = preload("res://gameplay/backrooms_traversal.gd")
const FlashlightPickup = preload("res://gameplay/backrooms_flashlight_pickup.gd")
const BACKROOMS_ID := "backrooms"
const BACKROOMS_REVEAL_DISTANCE := 1.35

const PRELOAD_AT_X := -27.0
const BACKROOMS_RETURN_PRELOAD_RADIUS := 15.0
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
var _perf_trace := false
var _trace_badge: PanelContainer
var _trace_label: Label
var _trace_hide_at := 0
var _perf_elapsed := 0.0
var _perf_worst_ms := 0.0
var _perf_samples: Array[float] = []
const PERF_SAMPLE_LIMIT := 2048
# Normal gameplay distributes scene assembly, portal geometry and SceneTree
# activation across consecutive frames instead of forcing all three at the
# invisible threshold. _stage_next() remains the immediate safety fallback.
var _pending_stage: Node3D
var _assembly: RefCounted
var _disposal := RoomDisposal.new()
var _pending_lane := ""
var _pending_stage_phase := 0
var _pending_return := false
var _pending_maze: Node3D
var _pending_maze_phase := 0
var _pending_stage_start_us := 0
var _pending_instance_ms := 0.0
var backrooms_active := false
# Keep the active scene root and player/camera in the tree during reveal.
# Only its environment children are retired; the root is freed on return.
var backrooms_host: Node3D
var _backrooms_entry_pending := false
var backrooms_maze: Node3D
var backrooms_lane := ""
var backrooms_environment: Environment
var backrooms_exit_connector: Node3D
var backrooms_pickup: Node3D
var backrooms_scored := false
var backrooms_entry_blend: Environment
var _entry_lights: Array[Dictionary] = []
var backrooms_entry_tween: Tween
var backrooms_return_environment: Environment
var backrooms_return_lighting_ready := false
var backrooms_return_light_weight := 0.0
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
		push_error("Casino needs both physical exit connectors")
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
	var run_state := get_node_or_null("/root/LoopState")
	if run_state != null and str(run_state.get("mode")) == "time_trial" and bool(run_state.get("active")):
		run_state.call("save_run")
	if StreamingTrace.enabled:
		StreamingTrace.stop()
	if is_instance_valid(backrooms_maze) and backrooms_maze != room:
		backrooms_maze.queue_free()
	if backrooms_active:
		_stop_backrooms_hum(room)
		var sound := get_node_or_null("/root/AudioDirector")
		if sound != null:
			sound.call("set_backrooms_mode", false)
	# Both attached standby rooms and not-yet-attached partial instances
	# belong to this controller; leaving for the menu must release both.
	if is_instance_valid(_pending_maze):
		_pending_maze.free()
		_pending_maze = null
	_cancel_pending_stage()
	_disposal.clear()
	if staged != null and is_instance_valid(staged):
		staged.queue_free()
		staged = null


func _place_markers() -> bool:
	# The portal geometry is the source of truth. Text labels (even a
	# missing or edited visual plaque) must never control room streaming.
	for lane in ["left", "right"]:
		if not is_instance_valid(portals.get_connector(room, lane)):
			return false
	for child in doors.get_children():
		child.free()
	for lane in ["left", "right"]:
		var marker := Marker3D.new()
		marker.name = "LeftDoor" if lane == "left" else "RightDoor"
		doors.add_child(marker)
		marker.global_position = room.to_global(Vector3(portals.EXIT_X, 1.6, portals.lane_z(lane)))
	return true


func _on_language_changed(key: String) -> void:
	var graphics := get_node_or_null("/root/GameSettings")
	if graphics != null and key in ["image_contrast", "brightness", "saturation", "fog_quality", "ssao_quality", "ssil", "bloom", "bloom_strength"]:
		graphics.call("apply_environment", staged_environment, [key])
		graphics.call("apply_environment", backrooms_environment, [key])
		if backrooms_active and backrooms_return_environment != null and staged_environment != null:
			Backrooms.blend_return_environment(backrooms_environment, staged_environment, backrooms_return_environment, backrooms_return_light_weight)
	if backrooms_active:
		if key == "image_contrast" and staged_environment != null:
			var contrast_settings := get_node_or_null("/root/GameSettings")
			if contrast_settings != null:
				staged_environment.adjustment_enabled = true
				staged_environment.adjustment_contrast = float(contrast_settings.get_option("image_contrast"))
		if key == "voxel_gi" and not backrooms_scored:
			var settings := get_node_or_null("/root/GameSettings")
			var probe := room.get_node_or_null("Lighting/BackroomsVoxelGI") as VoxelGI
			if probe != null and settings != null:
				probe.visible = bool(settings.get_option("voxel_gi"))
		if key in ["language", "door_symbols"] and is_instance_valid(staged):
			_refresh_exit_signs(staged)
		return
	if key not in ["language", "door_symbols"]:
		return
	_refresh_exit_signs(room)
	if staged != null and is_instance_valid(staged):
		_refresh_exit_signs(staged)
	if key != "language":
		return
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
	var caption := Loc.t("world.victory", self) if complete else ""
	var state := get_node_or_null("/root/LoopState")
	if state != null:
		var mode_id := str(state.get("mode"))
		if mode_id != "classic":
			level = int(state.call("progress_number"))
			if complete:
				var verdict: Dictionary = state.get("last_verdict")
				var de := str(Controls.pref(self, "language", "en")) == "de"
				caption = ("SERIE BEENDET" if de else "RUN ENDED") if bool(verdict.get("failed", false)) else ("ABGESCHLOSSEN" if de else "COMPLETED")
	sign.call("set_progress", level, complete, caption)


func _refresh_exit_signs(target_room: Node3D) -> void:
	if target_room == null:
		return
	var architecture := target_room.get_node_or_null("Architecture") as Node3D
	if architecture == null:
		return
	for node in architecture.get_children():
		if node is Label3D:
			var lane := StreamPortals.exit_lane(node as Label3D)
			if not lane.is_empty():
				node.set_meta("_exit_lane", lane)
				var caption := StreamPortals.choice_label(self, lane == "left")
				if node.text != caption:
					node.text = caption


func _candidate_lane(local_z: float) -> String:
	return "left" if absf(local_z - EXIT_Z_LEFT) <= absf(local_z - EXIT_Z_RIGHT) else "right"


func _lane_z(lane: String) -> float:
	return EXIT_Z_LEFT if lane == "left" else EXIT_Z_RIGHT


func _process(delta: float) -> void:
	if _trace_hide_at > 0 and Time.get_ticks_msec() >= _trace_hide_at:
		_trace_hide_at = 0
		if is_instance_valid(_trace_badge):
			_trace_badge.hide()
	if _perf_trace:
		var trace_local := room.to_local(player.global_position) if is_instance_valid(room) and is_instance_valid(player) else Vector3.ZERO
		var trace_phase := "backrooms_return" if backrooms_active and backrooms_scored else ("backrooms" if backrooms_active else ("connector" if choice_taken else "casino"))
		StreamingTrace.sample(delta, trace_phase, trace_local, _pending_stage_phase, is_instance_valid(staged))
		_sample_streaming_performance(delta)
	# The node creation and deferred setup phases land on separate frames.
	# Report any frame-time spike around staging so a remaining stall can
	# be attributed to the exact phase instead of guessing.
	if _stage_spike_frames > 0:
		if delta > 0.08:
			print("Casino streaming frame spike: %.1f ms (%d frames after staging)" %
				[delta * 1000.0, 13 - _stage_spike_frames])
		_stage_spike_frames -= 1
	if not transitioning:
		_disposal.advance()
	if transitioning or won or room == null or player == null:
		return
	var run_state := get_node_or_null("/root/LoopState")
	if run_state != null:
		run_state.call("tick_play_time", delta)
	if backrooms_active:
		_process_backrooms()
		return
	var local := room.to_local(player.global_position)
	if not choice_taken and _backrooms_selected():
		_process_backrooms_approach(local)
		return
	if (local.x < PRELOAD_AT_X or is_instance_valid(_pending_stage)) and not choice_taken:
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
		# Use the destination entrance plane. Once the player is inside the
		# new hall, sideways movement must not strand the previous scene.
		if is_instance_valid(staged) and turned_distance >= portals.TURN_LENGTH + 0.75:
			var arrival := staged.to_local(player.global_position)
			if arrival.z <= portals.ENTRY_Z - 0.75:
				_handoff()


func _sample_streaming_performance(delta: float) -> void:
	_perf_elapsed += delta
	_perf_worst_ms = maxf(_perf_worst_ms, delta * 1000.0)
	if _perf_samples.size() < PERF_SAMPLE_LIMIT:
		_perf_samples.append(delta * 1000.0)
	if _perf_elapsed < 1.0:
		return
	var phase := "casino"
	if backrooms_active:
		phase = "backrooms_return" if backrooms_scored else "backrooms"
	elif choice_taken:
		phase = "casino_connector"
	var local := room.to_local(player.global_position) if is_instance_valid(room) and is_instance_valid(player) else Vector3.ZERO
	print("[StreamingPerf] %s fps=%d worst_frame=%.1fms process=%.1fms physics=%.1fms draws=%d objects=%d primitives=%d staged=%s pending=%d maze_pending=%d position=%s" % [
		phase, Engine.get_frames_per_second(), _perf_worst_ms,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		str(is_instance_valid(staged)), _pending_stage_phase, _pending_maze_phase, str(local)])
	_perf_samples.sort()
	var p99 := _perf_samples[clampi(ceili(_perf_samples.size() * 0.99) - 1, 0, _perf_samples.size() - 1)] if not _perf_samples.is_empty() else 0.0
	print("[StreamingPerfResources] phase=%s p99=%.2fms static_mb=%.1f video_mb=%.1f nodes=%d resources=%d orphans=%d cache=%s" % [
		phase, p99, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), str(RuntimeCache.counts())])
	_perf_samples.clear()
	_perf_elapsed = 0.0
	_perf_worst_ms = 0.0


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
	# somehow reaches the choice gate before all budgeted staging steps finish.
	if choice_taken:
		return
	if staged != null and is_instance_valid(staged):
		if staged_lane != lane:
			staged.global_transform = _stage_transform(lane)
			staged_lane = lane
		return
	for ignored in range(6):
		if staged != null or _pending_stage == null and _pending_stage_phase == 0 and ignored > 0:
			break
		_advance_pending_stage(lane, false, true)


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


func _cancel_pending_stage() -> void:
	if is_instance_valid(_assembly):
		_assembly.cancel()
		_assembly = null
	if is_instance_valid(_pending_stage):
		if _pending_stage.is_inside_tree():
			_pending_stage.hide()
			_pending_stage.process_mode = Node.PROCESS_MODE_DISABLED
			_pending_stage.queue_free()
		else:
			_pending_stage.free()
	_pending_stage = null
	_pending_stage_phase = 0
	_pending_return = false
	_pending_lane = ""
	staged_environment = null


func _advance_pending_stage(lane: String, returning: bool = false, immediate: bool = false) -> void:
	if _pending_stage == null:
		_pending_return = returning
		_pending_stage_start_us = Time.get_ticks_usec()
		var trace_start := StreamingTrace.begin()
		var next := ROOM.instantiate() as Node3D
		StreamingTrace.finish("casino.instantiate", trace_start)
		_pending_instance_ms = float(Time.get_ticks_usec() - _pending_stage_start_us) / 1000.0
		if next == null:
			push_error("Cannot preload next casino hall")
			return
		next.set_meta("_streaming_standby", true)
		_pending_stage = next
		_pending_lane = lane
		_pending_stage_phase = 1
		_stage_spike_frames = 12
		return

	_pending_lane = lane
	if _pending_stage_phase == 1:
		# Do not create and destroy the duplicate player in the same frame
		# as the large PackedScene instantiation. It never enters the tree.
		var trace_cleanup := StreamingTrace.begin()
		var duplicate_player := _pending_stage.get_node_or_null("Player")
		if duplicate_player != null:
			duplicate_player.free()
		StreamingTrace.finish("casino.remove_duplicate_player", trace_cleanup)
		var portal_start_us := Time.get_ticks_usec()
		var trace_portal := StreamingTrace.begin()
		if not portals.prepare_room(_pending_stage):
			_pending_stage.free()
			_pending_stage = null
			_pending_stage_phase = 0
			staged_environment = null
			return
		StreamingTrace.finish("casino.prepare_portals", trace_portal)
		_pending_portal_ms = float(Time.get_ticks_usec() - portal_start_us) / 1000.0
		var trace_environment := StreamingTrace.begin()
		# Prevent expensive one-shot captures and duplicate WorldEnvironment
		# while the room remains invisible beyond the opaque bend.
		_set_reflections_visible(_pending_stage, false)
		var environment_node := _pending_stage.get_node_or_null("WorldEnvironment") as WorldEnvironment
		staged_environment = environment_node.environment if environment_node != null else null
		var graphics := get_node_or_null("/root/GameSettings")
		if staged_environment != null:
			staged_environment.set_meta("_casino_contrast", true)
		if graphics != null:
			graphics.call("apply_environment", staged_environment)
		if environment_node != null:
			environment_node.environment = null
		StreamingTrace.finish("casino.prepare_environment", trace_environment)
		_pending_stage_phase = 2
		return

	if _pending_stage_phase == 2:
		var next := _pending_stage
		if _assembly == null:
			next.transform = Backrooms.return_transform(room, portals.ENTRY_Z) if _pending_return else _stage_transform(lane)
			_assembly = RoomAssembly.new()
			_assembly.begin(next)
		if not _assembly.advance(get_tree().root, immediate):
			return
		_assembly = null
		next.remove_meta("_streaming_assembly")
		var trace_init := StreamingTrace.begin()
		# Room scripts must see the complete authored hierarchy, including
		# restored owners, before they schedule their normal runtime setup.
		for section in next.get_children():
			if section.has_method("advance_streaming_population"):
				section.call("initialize_room_section", true)
			elif section.has_method("initialize_room_section"):
				section.call("initialize_room_section")
		next.call("initialize_streamed_hall")
		StreamingTrace.finish("casino.initialize_hall", trace_init)
		_pending_stage_phase = 3
		if not immediate:
			return

	if _pending_stage_phase == 3:
		var next := _pending_stage
		var models := next.get_node_or_null("ModelInteriors")
		if models != null and models.has_method("advance_streaming_population"):
			if not bool(models.call("advance_streaming_population", immediate)):
				return
		if not _pending_return:
			var destination := _stage_transform(lane)
			if next.global_transform != destination:
				next.global_transform = destination
		var trace_signs := StreamingTrace.begin()
		_refresh_exit_signs(next)
		var state = get_node_or_null("/root/LoopState")
		if state != null:
			_update_level_sign(next, int(state.correct_streak), false)
		StreamingTrace.finish("casino.exit_and_level_signs", trace_signs)
		staged = next
		staged_lane = "" if _pending_return else lane
		staged_gi_warmed = false
		if _pending_return:
			var settings := get_node_or_null("/root/GameSettings")
			if staged_environment != null and settings != null:
				staged_environment.adjustment_enabled = true
				staged_environment.adjustment_contrast = float(settings.get_option("image_contrast"))
			Backrooms.open_return(backrooms_exit_connector)
		_pending_return = false
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
	var trace_gi := StreamingTrace.begin()
	rig.call("set_streaming_active", true)
	var atmosphere := staged.get_node_or_null("CasinoAtmosphere") as Node3D
	if atmosphere != null and atmosphere.has_method("prewarm_streaming_lights"):
		atmosphere.call("prewarm_streaming_lights")
	staged_gi_warmed = true
	StreamingTrace.finish("casino.prewarm_gi", trace_gi)


func _set_reflections_visible(target_room: Node3D, enabled: bool) -> void:
	var atmosphere := target_room.get_node_or_null("CasinoAtmosphere") as Node3D
	if atmosphere == null:
		return
	for child in atmosphere.get_children():
		if child is ReflectionProbe:
			var settings := get_node_or_null("/root/GameSettings")
			if settings != null:
				settings.call("reflection_requested", child, enabled)
			else:
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
		if not is_instance_valid(child):
			continue
		var trace_reflection := StreamingTrace.begin()
		var settings := get_node_or_null("/root/GameSettings")
		if settings != null:
			settings.call("reflection_requested", child, true)
		else:
			(child as ReflectionProbe).visible = true
		StreamingTrace.finish("casino.reflection." + str(child.name), trace_reflection)


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
	var trace_retire := StreamingTrace.begin()
	_retire_departing_casino(room, lane)
	StreamingTrace.finish("casino.retire_departing", trace_retire)
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
	var trace_anomaly := StreamingTrace.begin()
	var candidates: Array[String] = demo.available_ids(staged)
	state.prepare_round(candidates)
	demo.apply(staged, str(state.anomaly_id))
	StreamingTrace.finish("casino.apply_anomaly", trace_anomaly)


func _retire_departing_casino(target: Node3D, lane: String) -> void:
	# Both gates are already closed. Keep the chosen connector and the
	# global environment, but stop submitting the inaccessible old hall.
	for child in target.get_children():
		if child == player or child == self or child.name == "StreamingPortals":
			continue
		if child is Node3D:
			(child as Node3D).hide()
			child.process_mode = Node.PROCESS_MODE_DISABLED
	var generated := target.get_node_or_null("StreamingPortals")
	var chosen := portals.get_connector(target, lane) as Node3D
	if generated != null:
		for child in generated.get_children():
			if child != chosen and child is Node3D:
				(child as Node3D).hide()
				child.process_mode = Node.PROCESS_MODE_DISABLED


func _handoff() -> void:
	if backrooms_active:
		return
	if staged == null or not is_instance_valid(staged):
		return
	var trace_handoff := StreamingTrace.begin()
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
	player.call("begin_streaming_handoff")
	player.reparent(upcoming, true)
	reparent(upcoming, true)
	player.call("end_streaming_handoff")
	room = upcoming
	var old_environment := previous.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if old_environment != null:
		old_environment.environment = null
	var environment_node := upcoming.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node != null:
		environment_node.environment = staged_environment
	if upcoming.has_method("apply_image_contrast"):
		upcoming.call("apply_image_contrast")
	upcoming.remove_meta("_streaming_standby")
	upcoming.remove_meta("_streaming_lighting_prepared")
	get_tree().current_scene = upcoming
	_disposal.enqueue(previous)
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
	player.call("restore_streaming_view")
	transitioning = false
	StreamingTrace.finish("casino.handoff_queue_free", trace_handoff)


func _backrooms_selected() -> bool:
	var state = get_node_or_null("/root/LoopState")
	return state != null and state.round_ready and str(state.anomaly_id) == BACKROOMS_ID


func _process_backrooms_approach(local: Vector3) -> void:
	if local.x >= PRELOAD_AT_X:
		return
	var lane := _candidate_lane(local.z)
	_schedule_backrooms(lane)
	if not is_instance_valid(backrooms_maze):
		return
	var distance: float = (local.z - _lane_z(lane)) * portals.lane_sign(lane)
	if absf(local.x - portals.BEND_X) <= 1.15 and distance >= BACKROOMS_REVEAL_DISTANCE and not _backrooms_entry_pending:
		_backrooms_entry_pending = true
		# The real frame callback must finish before retiring scene children.
		call_deferred("_enter_backrooms", lane)


func _stage_backrooms(lane: String) -> void:
	# Immediate safety fallback for direct calls, not the normal frame path.
	for phase in range(3):
		_schedule_backrooms(lane)
		if is_instance_valid(backrooms_maze):
			return


func _schedule_backrooms(lane: String) -> void:
	if backrooms_active:
		return
	if is_instance_valid(backrooms_maze):
		if backrooms_lane != lane:
			backrooms_maze.global_transform = Backrooms.entrance_transform(room, portals, lane)
			backrooms_lane = lane
		return
	if is_instance_valid(_pending_stage):
		_cancel_pending_stage()
	if is_instance_valid(staged):
		staged.free()
		staged = null
		staged_lane = ""
		staged_gi_warmed = false
	var started := Time.get_ticks_usec()
	if not is_instance_valid(_pending_maze):
		_pending_maze = Backrooms.MAZE.instantiate() as Node3D
		if _pending_maze == null:
			push_error("Backrooms scene cannot be staged")
			return
		_pending_maze_phase = 1
	elif _pending_maze_phase == 1:
		var preview := _pending_maze.get_node_or_null("PreviewCamera")
		if preview != null:
			preview.free()
		var env := _pending_maze.get_node("Lighting/Environment") as WorldEnvironment
		backrooms_environment = env.environment
		var graphics := get_node_or_null("/root/GameSettings")
		if graphics != null:
			graphics.call("apply_environment", backrooms_environment)
		env.environment = null
		(_pending_maze.get_node("Lighting") as Node3D).hide()
		var passage := portals.get_connector(room, lane) as Node3D
		var roof := passage.get_node_or_null("TurnCeiling") as MeshInstance3D if passage != null else null
		Backrooms.build_entrance(_pending_maze, roof.material_override if roof != null else null)
		backrooms_exit_connector = Backrooms.build_exit(_pending_maze)
		Backrooms.Occlusion.maze_walls(_pending_maze)
		_pending_maze_phase = 2
	else:
		_pending_maze.transform = Backrooms.entrance_transform(room, portals, lane)
		get_tree().root.add_child(_pending_maze)
		backrooms_maze = _pending_maze
		backrooms_lane = lane
		_pending_maze = null
		_pending_maze_phase = 0
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	if elapsed_ms >= 16.7:
		print("Backrooms staging phase: %.1f ms" % elapsed_ms)
	_stage_spike_frames = 12


func _enter_backrooms(lane: String) -> void:
	_backrooms_entry_pending = false
	if backrooms_active or not is_instance_valid(backrooms_maze) or backrooms_lane != lane:
		return
	var previous := room
	var connector := portals.get_connector(previous, lane) as Node3D
	if connector == null or not portals.lock_departure(previous, lane):
		return
	transitioning = true
	# The original lock_departure gate already seals the route. Do not add
	# another wall at the bend. Butt the oak floor against the carpet edge.
	Backrooms.fit_entrance_floor(connector, backrooms_maze, portals.lane_sign(lane))
	# Keep the actual corridor light at its current energy on the reveal
	# frame. Fade the direct light alongside the environment, not just fog.
	_entry_lights.clear()
	for child in connector.get_children():
		if child is OmniLight3D:
			var passage_light := child as OmniLight3D
			_entry_lights.append({"light": passage_light, "energy": passage_light.light_energy,
				"color": passage_light.light_color, "fog": passage_light.light_volumetric_fog_energy})
	connector.reparent(backrooms_maze, true)
	connector.name = "BackroomsArrivalConnector"
	var old_env := previous.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var arrival_source: Environment = old_env.environment if old_env != null else null
	if old_env != null:
		old_env.environment = null
	var old_rig := previous.get_node_or_null("VoxelGIRig")
	if old_rig != null:
		old_rig.call("set_streaming_active", false)
	demo.clear()
	backrooms_active = true
	choice_taken = true
	backrooms_scored = false
	backrooms_return_environment = null
	backrooms_return_lighting_ready = false
	backrooms_return_light_weight = 0.0
	# Do not reparent the live player, Camera3D, pause CanvasLayer or
	# controller here. The active SceneTree root remains the casino shell.
	# The maze joins that shell at its existing world-space transform.
	backrooms_host = previous
	backrooms_maze.reparent(backrooms_host, true)
	room = backrooms_maze
	var env := room.get_node("Lighting/Environment") as WorldEnvironment
	(room.get_node("Lighting") as Node3D).show()
	var settings := get_node_or_null("/root/GameSettings")
	# This transition belongs to the scene, irrespective of accessibility.
	# Soft light transitions simply lengthens it further.
	var soft := settings != null and bool(settings.call("get_option", "soft_light_transitions"))
	if arrival_source != null and backrooms_environment != null:
		backrooms_entry_blend = backrooms_environment.duplicate() as Environment
		env.set_meta("_return_blend", true)
		Backrooms.blend_return_environment(arrival_source, backrooms_environment, backrooms_entry_blend, 0.0)
		env.environment = backrooms_entry_blend
	else:
		env.environment = backrooms_environment
	backrooms_entry_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	backrooms_entry_tween.tween_method(_blend_entry.bind(arrival_source, env), 0.0, 1.0, 2.0 if soft else 1.35)
	backrooms_entry_tween.tween_callback(_finish_entry_blend.bind(env))
	var probe := room.get_node_or_null("Lighting/BackroomsVoxelGI") as VoxelGI
	if probe != null:
		# Old local bakes can still be present after pulling this update.
		# Cap indirect light immediately, without rewriting the bake file.
		if probe.data != null:
			probe.data.energy = minf(probe.data.energy, 0.18)
		if settings != null and not bool(settings.get_option("voxel_gi")):
			probe.hide()
	player.call("set_backrooms_mode", true)
	var sound := get_node_or_null("/root/AudioDirector")
	if sound != null:
		sound.call("set_backrooms_mode", true)
		var hum := AudioStreamPlayer.new()
		hum.name = "BackroomsHum"
		hum.stream = sound.call("get_immersion_loop", "backrooms_hum") as AudioStream
		hum.bus = "HORROR"
		hum.volume_db = -60.0
		room.add_child(hum)
		if hum.stream != null:
			hum.play()
			hum.create_tween().tween_property(hum, "volume_db", -15.0, 0.55)
	# A small wall-side stand leaves the first passage unobstructed.
	var stand_mat := StandardMaterial3D.new()
	stand_mat.albedo_color = Color(0.27, 0.24, 0.19)
	Backrooms.box(room, "FlashlightStand", Vector3(-14.5, 0.38, -0.52), Vector3(0.42, 0.76, 0.40), stand_mat)
	backrooms_pickup = FlashlightPickup.new() as Node3D
	backrooms_pickup.name = "FlashlightPickup"
	backrooms_pickup.position = Vector3(-14.5, 0.84, -0.52)
	room.add_child(backrooms_pickup)
	Backrooms.add_pickup_light(room, backrooms_pickup.position)
	# Retire only the old world, never the live root or any player child.
	# Remove nodes from the tree now so old geometry/lights cannot overlap.
	for child in previous.get_children():
		if child == player or child == self or child == room:
			continue
		previous.remove_child(child)
		child.queue_free()
	player.call("restore_streaming_view")
	transitioning = false
	print("Backrooms reveal: active camera=", get_viewport().get_camera_3d() == player.get_node("Camera3D"), ", host=", previous.name)


func _blend_entry(weight: float, source: Environment, env: WorldEnvironment) -> void:
	if is_instance_valid(env) and source != null and backrooms_entry_blend != null:
		Backrooms.blend_return_environment(source, backrooms_environment, backrooms_entry_blend, weight)
	_set_entry_lights(weight)


func _set_entry_lights(weight: float) -> void:
	for item in _entry_lights:
		var light := item["light"] as OmniLight3D
		if not is_instance_valid(light):
			continue
		var original_color: Color = item["color"]
		light.light_energy = float(item["energy"]) * lerpf(1.0, 0.10, weight)
		light.light_color = original_color.lerp(Color(0.84, 0.81, 0.64), weight)
		light.light_volumetric_fog_energy = float(item["fog"]) * (1.0 - weight)


func _finish_entry_blend(env: WorldEnvironment) -> void:
	_set_entry_lights(1.0)
	_entry_lights.clear()
	if is_instance_valid(env) and backrooms_entry_blend != null and env.environment == backrooms_entry_blend:
		env.environment = backrooms_environment
		env.remove_meta("_return_blend")
	backrooms_entry_blend = null
	backrooms_entry_tween = null


func _physics_process(_delta: float) -> void:
	if backrooms_active and is_instance_valid(backrooms_pickup):
		backrooms_pickup.call("update_prompt", player)


# Diagnostic shortcut uses _input so a GUI control cannot consume it first.
# The ordinary interaction path below remains in _unhandled_input.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or not event.ctrl_pressed:
		return
	if event.keycode != KEY_F9 and event.physical_keycode != KEY_F9:
		return
	_perf_trace = not _perf_trace
	_perf_samples.clear()
	_perf_elapsed = 0.0
	_perf_worst_ms = 0.0
	var german := str(Controls.pref(self, "language", "en")) == "de"
	if _perf_trace:
		_show_trace_status("●  STREAMING-AUFZEICHNUNG AKTIV   |   Strg+F9: speichern" if german else "●  STREAMING RECORDING ACTIVE   |   Ctrl+F9: save", Color("#ff8c82"), false)
		StreamingTrace.start()
	else:
		var saved := StreamingTrace.stop()
		if saved:
			_show_trace_status("✓  Messung gespeichert: streaming_trace.json" if german else "✓  Recording saved: streaming_trace.json", Color("#a4e4b3"), true)
		else:
			_show_trace_status("!  Messdatei konnte nicht gespeichert werden" if german else "!  Could not save recording", Color("#ff8c82"), true)
	print("[StreamingPerf] ", "ON" if _perf_trace else "OFF")
	get_viewport().set_input_as_handled()

func _show_trace_status(message: String, color: Color, temporary: bool) -> void:
	if not is_instance_valid(_trace_badge):
		var layer := CanvasLayer.new()
		layer.name = "StreamingTraceStatus"
		layer.layer = 99
		add_child(layer)
		var anchor := Control.new()
		anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(anchor)
		anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_trace_badge = PanelContainer.new()
		_trace_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_trace_badge.set_meta("_independent_caption", true)
		anchor.add_child(_trace_badge)
		_trace_badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_trace_badge.offset_left = -255
		_trace_badge.offset_right = 255
		_trace_badge.offset_top = 14
		_trace_badge.offset_bottom = 48
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.05, 0.07, 0.94)
		style.set_corner_radius_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		_trace_badge.add_theme_stylebox_override("panel", style)
		_trace_label = Label.new()
		_trace_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_trace_label.set_meta("_independent_caption", true)
		_trace_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_trace_label.add_theme_font_size_override("font_size", 16)
		_trace_badge.add_child(_trace_label)
	_trace_label.text = message
	_trace_label.add_theme_color_override("font_color", color)
	_trace_badge.show()
	_trace_hide_at = Time.get_ticks_msec() + 6000 if temporary else 0

func _unhandled_input(event: InputEvent) -> void:
	if not backrooms_active or not is_instance_valid(backrooms_pickup) or get_tree().paused or bool(player.get("interaction_locked")):
		return
	if Controls.pressed(event, "interact"):
		if bool(backrooms_pickup.call("collect", player)):
			get_viewport().set_input_as_handled()


func _process_backrooms() -> void:
	var local := room.to_local(player.global_position)
	if not is_instance_valid(staged) and (is_instance_valid(_pending_stage) or local.distance_to(Vector3(Backrooms.EXIT_X, local.y, Backrooms.EXIT_Z)) < BACKROOMS_RETURN_PRELOAD_RADIUS):
		_advance_pending_stage("", true)
	# Evaluate the actual staged casino transform on every frame. The
	# return corridor and casino have different local coordinate systems.
	var arrived := is_instance_valid(staged) and Backrooms.crossed_return_entrance(
		staged.to_local(player.global_position), portals.ENTRY_Z)
	if not backrooms_scored:
		var passed_exit := local.x > Backrooms.EXIT_X + 1.3 and absf(local.z - Backrooms.EXIT_Z) < 1.1
		# If a large movement step missed the narrow scoring band, the
		# physical return route is also proof of traversal. Do not score
		# from inside the maze: its X extent ends before the return bend.
		var passed_return := arrived and local.x > Backrooms.RETURN_BEND_X - Backrooms.HALF_WIDTH - 0.35
		if passed_exit or passed_return:
			_finish_backrooms()
	if backrooms_scored:
		_update_backrooms_return_lighting(local.x)
		if arrived:
			_handoff_backrooms_return()


func _stage_backrooms_return() -> void:
	# Only used as a safety fallback if a player reaches the scoring plane
	# before all ordinary preparation steps have completed.
	for phase in range(6):
		if is_instance_valid(staged):
			return
		_advance_pending_stage("", true, true)


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
	if backrooms_entry_tween != null:
		backrooms_entry_tween.kill()
		_finish_entry_blend(room.get_node("Lighting/Environment") as WorldEnvironment)
	backrooms_scored = true
	Backrooms.seal_exit(backrooms_exit_connector)
	# Behind the closed gate the maze can no longer be seen or reached.
	# Keep its WorldEnvironment alive for blending, but hide geometry and
	# local lights now instead of rendering three GI volumes together.
	_retire_backrooms_geometry()
	_prewarm_next_gi()
	finishing = bool(verdict.get("finished", false))
	_update_level_sign(staged, int(verdict["streak"]), finishing)
	if not finishing:
		var candidates: Array[String] = demo.available_ids(staged)
		state.prepare_round(candidates)
		demo.apply(staged, str(state.anomaly_id))
	var soundscape := staged.get_node_or_null("RoomSoundscape")
	if soundscape != null:
		soundscape.call("activate")
	# Reflections are captured only once the final casino environment is
	# active, while the casino is still hidden behind the new return bend.


func _retire_backrooms_geometry() -> void:
	for child in room.get_children():
		if child == backrooms_exit_connector:
			continue
		if child is Node3D:
			(child as Node3D).hide()
			child.process_mode = Node.PROCESS_MODE_DISABLED
	# WorldEnvironment remains in the tree even when its Node3D parent is
	# hidden. Keep the blend resource, but never re-enable the old probe.
	_stop_backrooms_hum(room)


func _update_backrooms_return_lighting(local_x: float) -> void:
	if backrooms_return_lighting_ready or not is_instance_valid(staged) or staged_environment == null:
		return
	# The sealed exit makes this one-way. Keep the furthest blend value
	# if the player looks back or briefly walks backwards in the corridor.
	var weight: float = maxf(backrooms_return_light_weight, Backrooms.return_light_weight(local_x))
	if weight <= 0.0:
		return
	if is_equal_approx(weight, backrooms_return_light_weight) and backrooms_return_environment != null:
		return
	backrooms_return_light_weight = weight
	var old_env := room.get_node("Lighting/Environment") as WorldEnvironment
	var torch := player.get_node_or_null("Camera3D/BackroomsFlashlight") as SpotLight3D
	if torch != null:
		torch.light_energy = float(torch.get_meta("_return_base_energy", 0.95)) * (1.0 - weight)
	if weight >= 1.0:
		# Activate the EXACT destination resource before the blind turn,
		# not when the player has already walked into the visible hall.
		var next_env := staged.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if next_env == null:
			return
		old_env.environment = null
		old_env.remove_meta("_return_blend")
		next_env.environment = staged_environment
		if staged.has_method("apply_image_contrast"):
			staged.call("apply_image_contrast")
		var old_probe := room.get_node_or_null("Lighting/BackroomsVoxelGI") as VoxelGI
		if old_probe != null:
			old_probe.hide()
		backrooms_return_environment = null
		backrooms_return_lighting_ready = true
		_activate_reflections_sequentially(staged)
		return
	if backrooms_return_environment == null:
		backrooms_return_environment = staged_environment.duplicate() as Environment
	Backrooms.blend_return_environment(backrooms_environment, staged_environment, backrooms_return_environment, weight)
	if old_env.environment != backrooms_return_environment:
		old_env.set_meta("_return_blend", true)
		old_env.environment = backrooms_return_environment


func _stop_backrooms_hum(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var hum := target.get_node_or_null("BackroomsHum") as AudioStreamPlayer
	if hum != null:
		hum.stop()
		hum.stream = null


func _handoff_backrooms_return() -> void:
	if not backrooms_active or not backrooms_scored or not is_instance_valid(staged) or not is_instance_valid(backrooms_host):
		return
	# Safety fallback for unusually large frame steps; ordinary walking
	# completes this well before the player sees the casino.
	_update_backrooms_return_lighting(Backrooms.LIGHT_BLEND_END)
	# A visual preparation flag must never strand the gameplay state.
	# If a destination environment was unavailable, preserve the actual
	# staged environment when possible and still complete the valid return.
	if not backrooms_return_lighting_ready:
		var destination := staged.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if destination != null and staged_environment != null:
			destination.environment = staged_environment
		push_warning("Backrooms return lighting was not ready; completing the physical handoff")
	transitioning = true
	var previous := room
	var old_host := backrooms_host
	var upcoming := staged
	backrooms_exit_connector.reparent(upcoming, true)
	backrooms_exit_connector.name = "ArrivalConnector"
	_stop_backrooms_hum(previous)
	var sound := get_node_or_null("/root/AudioDirector")
	if sound != null:
		sound.call("set_backrooms_mode", false)
	var old_env := previous.get_node("Lighting/Environment") as WorldEnvironment
	old_env.environment = null
	var old_probe := previous.get_node_or_null("Lighting/BackroomsVoxelGI") as VoxelGI
	if old_probe != null:
		old_probe.hide()
	player.call("begin_streaming_handoff")
	player.reparent(upcoming, true)
	reparent(upcoming, true)
	player.call("end_streaming_handoff")
	# The live player has arrived in the casino. Reset movement and
	# traversal-only equipment unconditionally after reparenting, once.
	player.call("set_backrooms_mode", false)
	room = upcoming
	# Do not reassign or reconfigure the active environment here. It has
	# been rendering the casino since before the turn in the connector.
	upcoming.remove_meta("_streaming_standby")
	upcoming.remove_meta("_streaming_lighting_prepared")
	get_tree().current_scene = upcoming
	_disposal.enqueue(old_host)
	staged = null
	staged_lane = ""
	staged_gi_warmed = false
	choice_taken = false
	backrooms_active = false
	backrooms_scored = false
	backrooms_maze = null
	backrooms_host = null
	backrooms_lane = ""
	backrooms_environment = null
	backrooms_return_environment = null
	backrooms_return_lighting_ready = false
	backrooms_return_light_weight = 0.0
	backrooms_exit_connector = null
	backrooms_pickup = null
	_place_markers()
	if finishing:
		portals.lock_departure(upcoming, "left")
		won = true
		finishing = false
	player.call("restore_streaming_view")
	transitioning = false
