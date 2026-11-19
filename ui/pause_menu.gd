extends CanvasLayer
## Pauses the CURRENT scene rather than replacing it. The UI remains active
## while the SceneTree is paused and follows the same player across handoffs.

const SettingsPanel = preload("res://ui/settings_panel.gd")
const GOLD := Color("#dcb477")

var panel_root: Control
var pause_panel: PanelContainer
var settings_panel: PanelContainer
var confirmation: ConfirmationDialog
var open := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 90
    panel_root = Control.new()
    panel_root.name = "PauseOverlay"
    panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(panel_root)

    var dim := ColorRect.new()
    dim.color = Color(0.012, 0.016, 0.022, 0.78)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel_root.add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel_root.add_child(center)
    pause_panel = PanelContainer.new()
    pause_panel.custom_minimum_size = Vector2(475, 510)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#151c26")
    style.border_color = GOLD
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.shadow_size = 24
    style.shadow_color = Color(0, 0, 0, 0.75)
    pause_panel.add_theme_stylebox_override("panel", style)
    center.add_child(pause_panel)

    var margin := MarginContainer.new()
    for side in ["left", "right"]:
        margin.add_theme_constant_override("margin_" + side, 36)
    margin.add_theme_constant_override("margin_top", 27)
    margin.add_theme_constant_override("margin_bottom", 27)
    pause_panel.add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 12)
    margin.add_child(stack)
    var title := Label.new()
    title.text = "CASINO ANOMALY"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", GOLD)
    title.add_theme_font_size_override("font_size", 29)
    stack.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "PAUSE"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color("#a5aeb7"))
    stack.add_child(subtitle)

    _add_button(stack, "SPIEL FORTSETZEN", _resume)
    _add_button(stack, "EINSTELLUNGEN", _open_settings)
    _add_button(stack, "NEUES SPIEL", func() -> void: _confirm_action("new"))
    _add_button(stack, "SPIELSTAND LADEN", func() -> void: _confirm_action("load"))
    _add_button(stack, "HAUPTMENÜ", _go_to_main_menu)
    _add_button(stack, "SPIEL BEENDEN", get_tree().quit)

    settings_panel = SettingsPanel.new()
    settings_panel.visible = false
    settings_panel.back_pressed.connect(_close_settings)
    center.add_child(settings_panel)

    confirmation = ConfirmationDialog.new()
    confirmation.title = "Spielstand"
    confirmation.dialog_text = "Das aktuelle Spiel verlassen?"
    confirmation.ok_button_text = "Bestätigen"
    confirmation.cancel_button_text = "Abbrechen"
    confirmation.process_mode = Node.PROCESS_MODE_ALWAYS
    panel_root.add_child(confirmation)
    visible = false


func _add_button(parent: VBoxContainer, title: String, action: Callable) -> void:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size = Vector2(0, 43)
    button.pressed.connect(action)
    parent.add_child(button)


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo             and event.keycode == KEY_ESCAPE:
        if confirmation.visible:
            confirmation.hide()
        elif open and settings_panel.visible:
            _close_settings()
        elif open:
            _resume()
        else:
            _pause()
        get_viewport().set_input_as_handled()


func _pause() -> void:
    if open:
        return
    open = true
    visible = true
    pause_panel.visible = true
    settings_panel.visible = false
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume() -> void:
    open = false
    visible = false
    settings_panel.visible = false
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_settings() -> void:
    settings_panel.visible = true
    pause_panel.visible = false


func _close_settings() -> void:
    settings_panel.visible = false
    pause_panel.visible = true


func _confirm_action(action: String) -> void:
    var state := get_node_or_null("/root/LoopState")
    if action == "load" and (state == null or not state.has_continue()):
        return
    confirmation.dialog_text = (
        "Neues Spiel beginnen? Der aktuelle Spielstand wird überschrieben."
        if action == "new" else "Spielstand neu laden? Nicht gespeicherter Fortschritt geht verloren."
    )
    for connection in confirmation.confirmed.get_connections():
        confirmation.confirmed.disconnect(connection["callable"])
    confirmation.confirmed.connect(_run_action.bind(action), CONNECT_ONE_SHOT)
    confirmation.popup_centered()


func _run_action(action: String) -> void:
    var state := get_node_or_null("/root/LoopState")
    if state == null:
        return
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if action == "new":
        state.start_new_run()
        get_tree().change_scene_to_file("res://gameplay/tutorial.tscn")
    else:
        state.load_run()
        get_tree().change_scene_to_file(
            "res://main.tscn" if state.tutorial_done else "res://gameplay/tutorial.tscn"
        )


func _go_to_main_menu() -> void:
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().change_scene_to_file("res://menu.tscn")
