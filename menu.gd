extends Control

const SettingsPanel = preload("res://ui/settings_panel.gd")
const CreditsPanel = preload("res://ui/credits_panel.gd")
const Loc = preload("res://gameplay/localization.gd")
var settings_overlay: Control
var credits_overlay: Control
var credits_panel: PanelContainer
var overlay_tween: Tween
var changing_scene := false

const UPDATE_MANIFEST_URL := "https://github.com/TeKatz/casino-anomaly/releases/download/development/update-manifest.json"

@onready var status_label: Label = $CenterPanel/Content/Stack/StatusLabel
@onready var version_label: Label = $CenterPanel/Content/Stack/VersionLabel
@onready var update_button: Button = $CenterPanel/Content/Stack/UpdateButton
@onready var install_button: Button = $CenterPanel/Content/Stack/InstallButton
@onready var request: HTTPRequest = $UpdateRequest

var current_version_code: int = 0
var latest_manifest: Dictionary = {}
var status_key := "menu.offline"
var status_value := ""

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var sound := get_node_or_null("/root/AudioDirector")
    if sound != null:
        sound.set_world_ambience_enabled(false)
        sound.set_menu_music_enabled(true)
    var version_text := FileAccess.get_file_as_string("res://version.json")
    var parsed = JSON.parse_string(version_text)
    if parsed is Dictionary:
        current_version_code = int(parsed.get("versionCode", 0))
        version_label.text = "Version " + str(parsed.get("version", "0.1.0-dev.0"))
    var state = get_node_or_null("/root/LoopState")
    $CenterPanel/Content/Stack/ContinueButton.disabled = state == null or not state.has_continue()
    $CenterPanel/Content/Stack/PlayButton.pressed.connect(_on_play)
    $CenterPanel/Content/Stack/ContinueButton.pressed.connect(_on_continue)
    $CenterPanel/Content/Stack/SettingsButton.pressed.connect(_open_settings)
    $CenterPanel/Content/Stack/CreditsButton.pressed.connect(_open_credits)
    $CenterPanel/Content/Stack/QuitButton.pressed.connect(_on_quit)
    _create_settings_overlay()
    _create_credits_overlay()
    update_button.pressed.connect(_check_update)
    install_button.pressed.connect(_install_update)
    request.request_completed.connect(_on_request_completed)
    var game_settings = get_node_or_null("/root/GameSettings")
    if game_settings != null:
        game_settings.options_changed.connect(_on_setting_changed)
    _localize_ui()
    get_viewport().size_changed.connect(_update_layout)
    _update_layout()
    _animate_intro()
    call_deferred("_check_update")

func _exit_tree() -> void:
    var sound := get_node_or_null("/root/AudioDirector")
    if sound != null:
        sound.set_menu_music_enabled(false)


func _on_setting_changed(key: String) -> void:
    if key == "language":
        _localize_ui()
        if credits_panel != null:
            credits_panel.call("refresh_language")

func _set_status(key: String, value: String = "") -> void:
    status_key = key
    status_value = value
    _update_status()


func _update_status() -> void:
    var message := Loc.t(status_key, self)
    status_label.text = message % status_value if status_key == "menu.available" else message


func _localize_ui() -> void:
    var stack := $CenterPanel/Content/Stack
    (stack.get_node("Subtitle") as Label).text = Loc.t("menu.subtitle", self)
    (stack.get_node("Title") as Label).text = Loc.t("menu.choose", self)
    var buttons := {
        "new_game": "PlayButton", "continue": "ContinueButton",
        "settings": "SettingsButton", "credits": "CreditsButton",
        "check_updates": "UpdateButton", "install_update": "InstallButton",
        "quit": "QuitButton"
    }
    for key in buttons:
        var button := stack.get_node(str(buttons[key])) as Button
        button.text = Loc.t("menu." + key, self)
    _update_status()

func _on_play() -> void:
    var state = get_node_or_null("/root/LoopState")
    if state == null:
        _set_status("menu.failed_state")
        return
    state.start_new_run()
    _fade_to_scene("res://gameplay/tutorial.tscn")

func _on_continue() -> void:
    var state = get_node_or_null("/root/LoopState")
    if state == null or not state.has_continue():
        return
    _fade_to_scene("res://main.tscn" if state.tutorial_done else "res://gameplay/tutorial.tscn")

func _create_settings_overlay() -> void:
    var panel := SettingsPanel.new()
    settings_overlay = _build_overlay(panel)
    panel.back_pressed.connect(func() -> void: _hide_overlay(settings_overlay))


func _create_credits_overlay() -> void:
    credits_panel = CreditsPanel.new()
    credits_overlay = _build_overlay(credits_panel)
    credits_panel.back_pressed.connect(func() -> void: _hide_overlay(credits_overlay))


func _build_overlay(content: Control) -> Control:
    var overlay := Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.024, 0.04, 0.94)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(shade)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)
    center.add_child(content)
    overlay.visible = false
    return overlay


func _show_overlay(overlay: Control) -> void:
    if overlay_tween != null and overlay_tween.is_running():
        overlay_tween.kill()
    overlay.visible = true
    overlay.modulate.a = 0.0
    overlay_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    overlay_tween.tween_property(overlay, "modulate:a", 1.0, 0.25)


func _hide_overlay(overlay: Control) -> void:
    if overlay_tween != null and overlay_tween.is_running():
        overlay_tween.kill()
    overlay_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    overlay_tween.tween_property(overlay, "modulate:a", 0.0, 0.18)
    overlay_tween.tween_callback(func() -> void: overlay.visible = false)


func _open_settings() -> void:
    _show_overlay(settings_overlay)


func _open_credits() -> void:
    _show_overlay(credits_overlay)


func _update_layout() -> void:
    var compact := get_viewport_rect().size.x < 980.0
    $Brand.visible = not compact
    if compact:
        $CenterPanel.anchor_left = 0.14
        $CenterPanel.anchor_right = 0.86
    else:
        $CenterPanel.anchor_left = 0.56
        $CenterPanel.anchor_right = 0.95


func _animate_intro() -> void:
    $Brand.modulate.a = 0.0
    $CenterPanel.modulate.a = 0.0
    $CenterPanel.position.y += 12.0
    var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property($Brand, "modulate:a", 1.0, 0.72)
    tween.tween_property($CenterPanel, "modulate:a", 1.0, 0.48)
    tween.tween_property($CenterPanel, "position:y", $CenterPanel.position.y - 12.0, 0.48)


func _fade_to_scene(scene_path: String) -> void:
    if changing_scene:
        return
    changing_scene = true
    var screen := $Transition as ColorRect
    screen.move_to_front()
    screen.visible = true
    screen.modulate.a = 0.0
    var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(screen, "modulate:a", 1.0, 0.38)
    tween.tween_callback(func() -> void: get_tree().change_scene_to_file(scene_path))


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        if credits_overlay != null and credits_overlay.visible:
            _hide_overlay(credits_overlay)
            get_viewport().set_input_as_handled()
        elif settings_overlay != null and settings_overlay.visible:
            _hide_overlay(settings_overlay)
            get_viewport().set_input_as_handled()

func _on_quit() -> void:
    if changing_scene:
        return
    changing_scene = true
    var screen := $Transition as ColorRect
    screen.move_to_front()
    screen.visible = true
    screen.modulate.a = 0.0
    var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(screen, "modulate:a", 1.0, 0.30)
    tween.tween_callback(get_tree().quit)

func _check_update() -> void:
    if request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
        return
    latest_manifest.clear()
    install_button.visible = false
    install_button.disabled = true
    update_button.disabled = true
    _set_status("menu.checking")
    var url := UPDATE_MANIFEST_URL + "?nocache=" + str(int(Time.get_unix_time_from_system()))
    var error := request.request(url, PackedStringArray(["Cache-Control: no-cache"]))
    if error != OK:
        update_button.disabled = false
        _set_status("menu.checking_failed")

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    update_button.disabled = false
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        _set_status("menu.offline_updates")
        return
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if not (parsed is Dictionary):
        _set_status("menu.invalid_manifest")
        return
    if int(parsed.get("schemaVersion", 0)) != 1 or str(parsed.get("channel", "")) != "development":
        _set_status("menu.unknown_channel")
        return
    var package = parsed.get("package", {})
    if not (package is Dictionary):
        _set_status("menu.invalid_package")
        return
    if not str(package.get("url", "")).begins_with("https://github.com/TeKatz/casino-anomaly/releases/download/development/"):
        _set_status("menu.invalid_source")
        return
    var published_code := int(parsed.get("versionCode", -1))
    if published_code <= current_version_code:
        _set_status("menu.latest")
        return
    latest_manifest = parsed
    install_button.visible = true
    install_button.disabled = false
    _set_status("menu.available", str(parsed.get("version", "")))

func _install_update() -> void:
    if latest_manifest.is_empty():
        return
    if OS.get_name() != "Windows" or OS.has_feature("editor"):
        _set_status("menu.not_windows")
        return
    var install_dir := OS.get_executable_path().get_base_dir()
    var updater_source := install_dir.path_join("tools/updater/CasinoAnomaly.Updater.exe")
    if not FileAccess.file_exists(updater_source):
        _set_status("menu.missing_updater")
        return
    var helper_dir := OS.get_user_data_dir().path_join("update-helper")
    var make_result := DirAccess.make_dir_recursive_absolute(helper_dir)
    if make_result != OK:
        _set_status("menu.create_updater_failed")
        return
    var updater_copy := helper_dir.path_join("CasinoAnomaly.Updater.exe")
    if DirAccess.copy_absolute(updater_source, updater_copy) != OK:
        _set_status("menu.copy_updater_failed")
        return
    var arguments := PackedStringArray([
        "--manifest=" + UPDATE_MANIFEST_URL,
        "--install-dir=" + install_dir,
        "--wait-pid=" + str(OS.get_process_id()),
        "--current-version-code=" + str(current_version_code)
    ])
    var child_pid := OS.create_process(updater_copy, arguments, false)
    if child_pid <= 0:
        _set_status("menu.launch_updater_failed")
        return
    get_tree().quit()
