extends CanvasLayer
## Pauses the CURRENT scene rather than replacing it. The UI remains active
## while the SceneTree is paused and follows the same player across handoffs.

const Controls = preload("res://gameplay/input_bindings.gd")
const FitCenter = preload("res://ui/fit_centered_panel.gd")
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
var panel_tween: Tween
var section_labels: Array[Label] = []
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

    var center := FitCenter.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel_root.add_child(center)
    pause_panel = PanelContainer.new()
    pause_panel.custom_minimum_size = Vector2(500, 680)
    pause_panel.add_theme_stylebox_override("panel", MenuStyle.panel())
    center.add_child(pause_panel)

    var margin := MarginContainer.new()
    for side in ["left", "right"]:
        margin.add_theme_constant_override("margin_" + side, 36)
    margin.add_theme_constant_override("margin_top", 27)
    margin.add_theme_constant_override("margin_bottom", 27)
    pause_panel.add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 7)
    margin.add_child(stack)
    var title := Label.new()
    title.text = "CASINO ANOMALY"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", GOLD)
    title.add_theme_font_size_override("font_size", 28)
    stack.add_child(title)
    subtitle_label = Label.new()
    var subtitle := subtitle_label
    subtitle.text = "PAUSE"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color("#a5aeb7"))
    stack.add_child(subtitle)

    _add_section(stack, "pause.group_current")
    _add_button(stack, "pause.resume", _resume)
    _add_button(stack, "pause.settings", _open_settings)
    _add_section(stack, "pause.group_discoveries")
    _add_button(stack, "pause.archive", func() -> void: _open_archive("archive"))
    _add_button(stack, "pause.stats", func() -> void: _open_archive("stats"))
    _add_button(stack, "pause.credits", _open_credits)
    _add_section(stack, "pause.group_session")
    _add_button(stack, "pause.new_game", func() -> void: _confirm_action("new"))
    _add_button(stack, "pause.load", func() -> void: _confirm_action("load"))
    _add_button(stack, "pause.menu", _go_to_main_menu)
    _add_button(stack, "pause.quit", _request_quit)

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


func _add_section(parent: VBoxContainer, key: String) -> void:
    var row := HBoxContainer.new()
    row.custom_minimum_size.y = 21
    row.add_theme_constant_override("separation", 13)
    parent.add_child(row)
    var label := Label.new()
    label.text = Loc.t(key, self)
    label.set_meta("translation_key", key)
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", Color("#bba58a"))
    row.add_child(label)
    section_labels.append(label)
    var rule := HSeparator.new()
    rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(rule)


func _add_button(parent: VBoxContainer, key: String, action: Callable) -> void:
    var button := LuminousButton.new()
    button.text = Loc.t(key, self)
    button.set_meta("translation_key", key)
    button.custom_minimum_size = Vector2(0, 41)
    match key:
        "pause.resume":
            button.symbol = "resume"
            button.accent = "green"
            button.featured = true
        "pause.settings": button.symbol = "settings"
        "pause.archive": button.symbol = "archive"
        "pause.stats": button.symbol = "stats"
        "pause.credits": button.symbol = "credits"
        "pause.new_game":
            button.symbol = "new"
            button.accent = "amber"
            button.featured = true
        "pause.load": button.symbol = "load"
        "pause.menu": button.symbol = "home"
        "pause.quit":
            button.symbol = "quit"
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
    for section in section_labels:
        section.text = Loc.t(str(section.get_meta("translation_key")), self)
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
    var settings := get_node_or_null("/root/GameSettings")
    if settings != null and bool(settings.get_meta("_binding_capture", false)):
        return
    if Controls.pressed(event, "pause") or (open and event.is_action_pressed("ui_cancel")):
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
    panel_root.modulate.a = 0.0 if not bool(Controls.pref(self, "reduced_menu_motion", false)) else 1.0
    if intro_tween != null and intro_tween.is_running():
        intro_tween.kill()
    intro_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    intro_tween.tween_property(panel_root, "modulate:a", 1.0, 0.0 if bool(Controls.pref(self, "reduced_menu_motion", false)) else 0.23).set_trans(Tween.TRANS_CUBIC)
    get_tree().paused = true
    _fade_panel(pause_panel)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume() -> void:
    open = false
    if panel_tween != null and panel_tween.is_running():
        panel_tween.kill()
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
    if panel_tween != null and panel_tween.is_running():
        panel_tween.kill()
    if bool(Controls.pref(self, "reduced_menu_motion", false)):
        panel.modulate.a = 1.0
        return
    panel.modulate.a = 0.0
    panel_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    panel_tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    panel_tween.tween_property(panel, "modulate:a", 1.0, 0.24)


func _confirm_action(action: String) -> void:
    var state := get_node_or_null("/root/LoopState")
    if action == "load" and (state == null or not state.has_continue()):
        return
    if action == "new" and not bool(Controls.pref(self, "confirm_new_run", true)):
        _run_action(action)
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
        if bool(Controls.pref(self, "skip_tutorial", false)):
            state.complete_tutorial()
            get_tree().change_scene_to_file("res://main.tscn")
        else:
            get_tree().change_scene_to_file("res://gameplay/tutorial.tscn")
    else:
        state.load_run()
        get_tree().change_scene_to_file(
            "res://main.tscn" if state.tutorial_done else "res://gameplay/tutorial.tscn"
        )


func _request_quit() -> void:
    if not bool(Controls.pref(self, "confirm_quit", false)):
        get_tree().quit()
        return
    confirmation_action = "quit"
    confirmation.dialog_text = "Spiel beenden?" if Controls.pref(self, "language", "en") == "de" else "Quit the game?"
    for connection in confirmation.confirmed.get_connections():
        confirmation.confirmed.disconnect(connection["callable"])
    confirmation.confirmed.connect(get_tree().quit, CONNECT_ONE_SHOT)
    confirmation.popup_centered()

func _go_to_main_menu() -> void:
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().change_scene_to_file("res://menu.tscn")
