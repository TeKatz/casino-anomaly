extends Node3D
## Runtime-only corridor controller. Never modifies main.tscn on disk.
## One authored hall is reused; the next round begins while the doorway
## occludes the player with a brief dark transition.

const DemoAnomalies = preload("res://gameplay/demo_anomalies.gd")
const RESET_POINT := Vector3(0, 1.02, 11.1)
const INTERACT_DISTANCE := 2.7

var room: Node3D
var player: CharacterBody3D
var doors: Node3D
var demo: RefCounted
var hud: Label
var prompt: Label
var feedback: Label
var veil: ColorRect
var transitioning := false


func _ready() -> void:
    room = get_parent() as Node3D
    player = room.get_node_or_null("Player") as CharacterBody3D
    if player == null:
        push_error("Casino loop needs the existing first-person Player")
        queue_free()
        return
    # The artist's main.tscn already contains two complete EXIT doors.
    # Create invisible position markers only; NEVER overlay more door meshes.
    doors = Node3D.new()
    doors.name = "DoorChoices"
    room.add_child(doors)
    var existing_signs: Array[Label3D] = []
    var architecture := room.get_node_or_null("Architecture") as Node3D
    if architecture != null:
        for child in architecture.get_children():
            if child is Label3D and (child as Label3D).text == "EXIT":
                existing_signs.append(child as Label3D)
    if existing_signs.size() != 2:
        push_error("Casino gameplay expects the two original EXIT doors")
        queue_free()
        return
    var left_label := existing_signs[0]
    var right_label := existing_signs[1]
    if left_label.global_position.z < right_label.global_position.z:
        left_label = existing_signs[1]
        right_label = existing_signs[0]
    _door_marker("LeftDoor", left_label)
    _door_marker("RightDoor", right_label)
    demo = DemoAnomalies.new()
    _build_hud()
    var state = get_node_or_null("/root/LoopState")
    if state == null:
        queue_free()
        return
    var available: Array[String] = demo.available_ids(room)
    state.prepare_round(available)
    demo.apply(room, str(state.anomaly_id))
    _update_hud()


func _door_marker(label: String, exit_sign: Label3D) -> void:
    var marker := Marker3D.new()
    marker.name = label
    doors.add_child(marker)
    marker.global_position = Vector3(
        exit_sign.global_position.x,
        1.6,
        exit_sign.global_position.z
    )


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
    prompt.offset_right = 820
    prompt.offset_bottom = -25
    prompt.add_theme_font_size_override("font_size", 20)
    prompt.add_theme_color_override("font_color", Color("#f5e5c6"))
    layer.add_child(prompt)

    veil = ColorRect.new()
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.color = Color(0, 0, 0, 0)
    veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(veil)


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


func _nearest_door() -> String:
    if player == null or doors == null:
        return ""
    var left := doors.get_node("LeftDoor") as Node3D
    var right := doors.get_node("RightDoor") as Node3D
    var a := player.global_position.distance_to(left.global_position)
    var b := player.global_position.distance_to(right.global_position)
    if minf(a, b) > INTERACT_DISTANCE:
        return ""
    return "left" if a <= b else "right"


func _process(_delta: float) -> void:
    if transitioning or player == null:
        return
    match _nearest_door():
        "left":
            prompt.text = "[E] LINKE TÜR – ANOMALIE"
        "right":
            prompt.text = "[E] RECHTE TÜR – KEINE ANOMALIE"
        _:
            prompt.text = "Suche nach Veränderungen. Am Ende entscheidest du links oder rechts."


func _unhandled_input(event: InputEvent) -> void:
    if transitioning or not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if event.keycode != KEY_E:
        return
    var choice := _nearest_door()
    if choice.is_empty():
        return
    get_viewport().set_input_as_handled()
    _enter_door(choice == "left")


func _enter_door(guess_anomaly: bool) -> void:
    if transitioning:
        return
    var state = get_node_or_null("/root/LoopState")
    if state == null:
        return
    transitioning = true
    prompt.text = ""
    # A brief occlusion masks the spatial seam. A walkable connector and
    # opening animations can replace this transition without changing rules.
    var darken := create_tween()
    darken.tween_property(veil, "color", Color.BLACK, 0.43)
    await darken.finished

    var result: Dictionary = state.decide(guess_anomaly)
    if not bool(result.get("valid", false)):
        transitioning = false
        return
    demo.clear()
    if bool(result.get("finished", false)):
        _show_victory()
        return

    # Reuse the original level, not a second expensive scene copy.
    # While the player sees black, select and apply the next round.
    var available: Array[String] = demo.available_ids(room)
    state.prepare_round(available)
    demo.apply(room, str(state.anomaly_id))
    player.global_position = RESET_POINT
    player.rotation = Vector3.ZERO
    player.velocity = Vector3.ZERO
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    if camera != null:
        camera.rotation = Vector3.ZERO
    _update_hud()
    feedback.text = "RICHTIG – weiter." if bool(result.get("correct", false)) else "FALSCH – Fortschritt zurückgesetzt."
    var lighten := create_tween()
    lighten.tween_property(veil, "color", Color(0, 0, 0, 0), 0.50)
    await lighten.finished
    transitioning = false


func _show_victory() -> void:
    player.set_physics_process(false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var panel := Label.new()
    panel.position = Vector2(145, 225)
    panel.add_theme_font_size_override("font_size", 32)
    panel.add_theme_color_override("font_color", Color("#f1d39d"))
    panel.text = "DU HAST DEN AUSGANG GEFUNDEN\n\nAcht richtige Entscheidungen hintereinander.\n\nESC – Zurück zum Hauptmenü"
    veil.get_parent().add_child(panel)
    panel.move_to_front()
