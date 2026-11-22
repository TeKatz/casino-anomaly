extends CanvasLayer
## Pauses the CURRENT scene rather than replacing it. The UI remains active
## while the SceneTree is paused and follows the same player across handoffs.

const SettingsPanel = preload("res://ui/settings_panel.gd")
const CreditsPanel = preload("res://ui/credits_panel.gd")
const ArchivePanel = preload("res://ui/anomaly_archive_panel.gd")
const LuminousButton = preload("res://ui/luminous_button.gd")
const MenuStyle = preload("res://ui/menu_style.gd")
const Loc = preload("res://gameplay/localization.gd")
const GOLD := Color("#dcb477")

var panel_root: Control
var pause_panel: PanelContainer
var settings_panel: PanelContainer
var credits_panel: PanelContainer
var archive_panel: PanelContainer
var intro_tween: Tween
var confirmation: ConfirmationDialog
var open := false
var subtitle_label: Label
var localized_buttons: Array[Button] = []
var confirmation_action := ""


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 90
    panel_root = Control.new()
    panel_root.name = "PauseOverlay"
    panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(panel_root)

    var dim := ColorRect.new()
    dim.color = Color(0.015, 0.023, 0.038, 0.87)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel_root.add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel_root.add_child(center)
    pause_panel = PanelContainer.new()
    pause_panel.custom_minimum_size = Vector2(475, 625)
    pause_panel.add_theme_stylebox_override("panel", MenuStyle.panel())
    center.add_child(pause_panel)

    var margin := MarginContainer.new()
    for side in ["left", "right"]:
        margin.add_theme_constant_override("margin_" + side, 36)
    margin.add_theme_constant_override("margin_top", 27)
    margin.add_theme_constant_override("margin_bottom", 27)
    pause_panel.add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 9)
    margin.add_child(stack)
    var title := Label.new()
    title.text = "CASINO ANOMALY"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", GOLD)
    title.add_theme_font_size_override("font_size", 29)
    stack.add_child(title)
    subtitle_label = Label.new()
    var subtitle := subtitle_label
    subtitle.text = "PAUSE"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color("#a5aeb7"))
    stack.add_child(subtitle)

    _add_button(stack, "pause.resume", _resume)
    _add_button(stack, "pause.settings", _open_settings)
    _add_button(stack, "pause.archive", func() -> void: _open_archive("archive"))
    _add_button(stack, "pause.stats", func() -> void: _open_archive("stats"))
    _add_button(stack, "pause.credits", _open_credits)
    _add_button(stack, "pause.new_game", func() -> void: _confirm_action("new"))
    _add_button(stack, "pause.load", func() -> void: _confirm_action("load"))
    _add_button(stack, "pause.menu", _go_to_main_menu)
    _add_button(stack, "pause.quit", get_tree().quit)

    settings_panel = SettingsPanel.new()
    settings_panel.visible = false
    settings_panel.back_pressed.connect(_close_settings)
    center.add_child(settings_panel)

    credits_panel = CreditsPanel.new()
    credits_panel.visible = false
    credits_panel.back_pressed.connect(_close_credits)
    center.add_child(credits_panel)

    archive_panel = ArchivePanel.new()
    archive_panel.visible = false
    archive_panel.back_pressed.connect(_close_archive)
    center.add_child(archive_panel)

    confirmation = ConfirmationDialog.new()
    confirmation.title = Loc.t("pause.save_title", self)
    confirmation.dialog_text = Loc.t("pause.leave", self)
    confirmation.ok_button_text = Loc.t("pause.confirm", self)
    confirmation.cancel_button_text = Loc.t("pause.cancel", self)
    confirmation.process_mode = Node.PROCESS_MODE_ALWAYS
    panel_root.add_child(confirmation)
    MenuStyle.apply_button(confirmation.get_ok_button(), true)
    MenuStyle.apply_button(confirmation.get_cancel_button())
    visible = false
    var game_settings = get_node_or_null("/root/GameSettings")
    if game_settings != null:
        game_settings.options_changed.connect(_on_setting_changed)
    _refresh_localization()


func _add_button(parent: VBoxContainer, key: String, action: Callable) -> void:
    var button := LuminousButton.new()
    button.text = Loc.t(key, self)
    button.set_meta("translation_key", key)
    button.custom_minimum_size = Vector2(0, 43)
    if key == "pause.new_game":
        button.accent = "green"
    elif key == "pause.quit":
        button.accent = "red"
    button.pressed.connect(action)
    parent.add_child(button)
    localized_buttons.append(button)


func _on_setting_changed(key: String) -> void:
    if key == "language":
        _refresh_localization()


func _refresh_localization() -> void:
    for button in localized_buttons:
        button.text = Loc.t(str(button.get_meta("translation_key")), self)
    confirmation.title = Loc.t("pause.save_title", self)
    credits_panel.call("refresh_language")
    archive_panel.call("refresh_language")
    confirmation.ok_button_text = Loc.t("pause.confirm", self)
    confirmation.cancel_button_text = Loc.t("pause.cancel", self)
    var key := "pause.leave"
    if confirmation_action == "new":
        key = "pause.confirm_new"
    elif confirmation_action == "load":
        key = "pause.confirm_load"
    confirmation.dialog_text = Loc.t(key, self)


func _input(event: InputEvent) -> void:
    # The introduction owns Escape while a dialogue is open.
    var owning_scene := get_parent().get_parent()
    if owning_scene != null and owning_scene.has_method("is_dialogue_open") \
            and owning_scene.is_dialogue_open():
        return
    # Do not open the normal pause overlay on top of the private G menu.
    var dev_menu := get_parent().get_node_or_null("AnomalyDevMenu")
    if dev_menu != null and dev_menu.visible:
        return
    if event is InputEventKey and event.pressed and not event.echo             and event.keycode == KEY_ESCAPE:
        if confirmation.visible:
            confirmation.hide()
        elif open and archive_panel.visible:
            _close_archive()
        elif open and credits_panel.visible:
            _close_credits()
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
    credits_panel.visible = false
    archive_panel.visible = false
    panel_root.modulate.a = 0.0
    if intro_tween != null and intro_tween.is_running():
        intro_tween.kill()
    intro_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    intro_tween.tween_property(panel_root, "modulate:a", 1.0, 0.23).set_trans(Tween.TRANS_CUBIC)
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume() -> void:
    open = false
    visible = false
    settings_panel.visible = false
    credits_panel.visible = false
    archive_panel.visible = false
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_settings() -> void:
    settings_panel.visible = true
    credits_panel.visible = false
    pause_panel.visible = false
    _fade_panel(settings_panel)


func _close_settings() -> void:
    settings_panel.visible = false
    pause_panel.visible = true
    _fade_panel(pause_panel)


func _open_credits() -> void:
    credits_panel.visible = true
    settings_panel.visible = false
    pause_panel.visible = false
    _fade_panel(credits_panel)


func _close_credits() -> void:
    credits_panel.visible = false
    pause_panel.visible = true
    _fade_panel(pause_panel)


func _open_archive(next_mode: String) -> void:
    archive_panel.call("show_mode", next_mode)
    archive_panel.visible = true
    credits_panel.visible = false
    settings_panel.visible = false
    pause_panel.visible = false
    _fade_panel(archive_panel)


func _close_archive() -> void:
    archive_panel.visible = false
    pause_panel.visible = true
    _fade_panel(pause_panel)


func _fade_panel(panel: Control) -> void:
    panel.modulate.a = 0.0
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC)


func _confirm_action(action: String) -> void:
    var state := get_node_or_null("/root/LoopState")
    if action == "load" and (state == null or not state.has_continue()):
        return
    confirmation_action = action
    _refresh_localization()
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
