extends Node3D
## Seamless Exit-8-style spatial streaming.
## At most two authored casino rooms coexist briefly: active + next.
## All edits to walls/doors and all connector meshes are runtime-only.
## The two EXITs turn away from each other behind opaque corners. Once the
## player commits, both exits are sealed behind them, and the selected
## connector stays with the new room after the old hall has been freed.
## No camera teleports, fades or extra button presses.

const DemoAnomalies = preload("res://gameplay/demo_anomalies.gd")
const StreamPortals = preload("res://gameplay/stream_portals.gd")
const ROOM = preload("res://main.tscn")

const PRELOAD_AT_X := -31.0
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
var hud: Label
var prompt: Label
var feedback: Label
var staged: Node3D
var staged_environment: Environment
var staged_lane := ""
var choice_taken := false
var transitioning := false
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

    demo = DemoAnomalies.new()
    doors = Node3D.new()
    doors.name = "DoorChoices"
    add_child(doors)
    if not _place_markers():
        push_error("Casino needs both original EXIT signs as portal markers")
        queue_free()
        return
    _build_hud()

    var state = get_node_or_null("/root/LoopState")
    if state == null:
        queue_free()
        return
    var available: Array[String] = demo.available_ids(room)
    state.prepare_round(available)
    demo.apply(room, str(state.anomaly_id))
    _update_hud()


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
        if part is Label3D and (part as Label3D).text == "EXIT":
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


func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "GameHUD"
    layer.layer = 2
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(23, 20)
    hud.add_theme_font_size_override("font_size", 19)
    hud.add_theme_color_override("font_color", Color("#f4d59e"))
    layer.add_child(hud)

    feedback = Label.new()
    feedback.position = Vector2(23, 58)
    feedback.add_theme_font_size_override("font_size", 18)
    feedback.add_theme_color_override("font_color", Color("#ffe9bd"))
    layer.add_child(feedback)

    prompt = Label.new()
    prompt.anchor_top = 1.0
    prompt.anchor_bottom = 1.0
    prompt.offset_left = 23
    prompt.offset_top = -60
    prompt.offset_right = 900
    prompt.offset_bottom = -25
    prompt.add_theme_font_size_override("font_size", 20)
    prompt.add_theme_color_override("font_color", Color("#f5e5c6"))
    layer.add_child(prompt)


func _update_hud() -> void:
    var state = get_node_or_null("/root/LoopState")
    if state == null:
        return
    hud.text = "DURCHLAUF %02d     |     FORTSCHRITT %d/%d     |     FEHLER %d" % [
        state.visited_loops + 1,
        state.correct_streak,
        state.REQUIRED_CORRECT,
        state.mistakes
    ]


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

    if not choice_taken:
        prompt.text = "LINKS: ANOMALIE   |   RECHTS: NORMAL   –   durch den Ausgang und um die Ecke"
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
    var environment_node := next.get_node_or_null("WorldEnvironment") as WorldEnvironment
    staged_environment = environment_node.environment if environment_node != null else null
    if environment_node != null:
        environment_node.environment = null
    next.transform = _stage_transform(lane)
    get_tree().root.add_child(next)
    staged = next
    staged_lane = lane


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
    choice_taken = true
    demo.clear()
    if bool(verdict.get("finished", false)):
        _show_victory()
        return

    # Populate the NEXT room while the player is still in the connector.
    # The previous room stays visible behind them until the exit handoff.
    var candidates: Array[String] = demo.available_ids(staged)
    state.prepare_round(candidates)
    demo.apply(staged, str(state.anomaly_id))
    _update_hud()
    feedback.text = "RICHTIG." if bool(verdict.get("correct", false)) else "FALSCH – Serie zurückgesetzt."
    prompt.text = "Folge dem Gang um die Ecke. Der nächste Durchlauf ist bereits vorbereitet."


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
    choice_taken = false

    # Preserve the single CharacterBody3D and the live HUD/controller.
    # No camera cut, teleport, or orientation change occurs at handoff.
    player.reparent(upcoming, true)
    reparent(upcoming, true)
    room = upcoming
    var environment_node := upcoming.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if environment_node != null:
        environment_node.environment = staged_environment
    upcoming.remove_meta("_streaming_standby")
    get_tree().current_scene = upcoming
    previous.queue_free()
    _place_markers()
    _update_hud()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    transitioning = false


func _show_victory() -> void:
    won = true
    player.set_physics_process(false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    prompt.text = ""
    if staged != null and is_instance_valid(staged):
        staged.queue_free()
        staged = null
    var panel := Label.new()
    panel.position = Vector2(145, 225)
    panel.add_theme_font_size_override("font_size", 32)
    panel.add_theme_color_override("font_color", Color("#f1d39d"))
    panel.text = "DU HAST DEN AUSGANG GEFUNDEN\n\nAcht richtige Entscheidungen hintereinander.\n\nESC – Zurück zum Hauptmenü"
    get_node("GameHUD").add_child(panel)
