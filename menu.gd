extends Control

const SettingsPanel = preload("res://ui/settings_panel.gd")
const Loc = preload("res://gameplay/localization.gd")
var settings_overlay: Control

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
    # The persistent audio director plays music only while the menu scene
    # exists; its low-level room ambience continues across scene changes.
    var sound := get_node_or_null("/root/AudioDirector")
    if sound != null:
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
    $CenterPanel/Content/Stack/Casino2PreviewButton.pressed.connect(_on_preview)
    $CenterPanel/Content/Stack/SettingsButton.pressed.connect(_open_settings)
    _create_settings_overlay()
    $CenterPanel/Content/Stack/QuitButton.pressed.connect(_on_quit)
    update_button.pressed.connect(_check_update)
    install_button.pressed.connect(_install_update)
    request.request_completed.connect(_on_request_completed)
    var game_settings = get_node_or_null("/root/GameSettings")
    if game_settings != null:
        game_settings.options_changed.connect(_on_setting_changed)
    _localize_ui()
    call_deferred("_check_update")


func _exit_tree() -> void:
    var sound := get_node_or_null("/root/AudioDirector")
    if sound != null:
        sound.set_menu_music_enabled(false)


func _on_setting_changed(key: String) -> void:
    if key == "language":
        _localize_ui()


func _set_status(key: String, value: String = "") -> void:
    status_key = key
    status_value = value
    _update_status()


func _update_status() -> void:
    var message := Loc.t(status_key, self)
    status_label.text = message % status_value if status_key == "menu.available" else message


func _localize_ui() -> void:
    var stack := $CenterPanel/Content/Stack
    var subtitle := stack.get_node("Subtitle") as Label
    subtitle.text = Loc.t("menu.subtitle", self)
    var buttons := {
        "new_game": "PlayButton", "continue": "ContinueButton",
        "settings": "SettingsButton", "preview": "Casino2PreviewButton",
        "check_updates": "UpdateButton", "install_update": "InstallButton",
        "quit": "QuitButton"
    }
    for key in buttons:
        var button := stack.get_node(str(buttons[key])) as Button
        button.text = Loc.t("menu." + key, self)
    $Footnote.text = Loc.t("menu.footnote", self)
    _update_status()

func _on_play() -> void:
    var state = get_node_or_null("/root/LoopState")
    if state == null:
        _set_status("menu.failed_state")
        return
    state.start_new_run()
    get_tree().change_scene_to_file("res://gameplay/tutorial.tscn")


func _on_continue() -> void:
    var state = get_node_or_null("/root/LoopState")
    if state == null or not state.has_continue():
        return
    get_tree().change_scene_to_file(
        "res://main.tscn" if state.tutorial_done else "res://gameplay/tutorial.tscn"
    )


func _create_settings_overlay() -> void:
    settings_overlay = Control.new()
    settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(settings_overlay)
    var shade := ColorRect.new()
    shade.color = Color(0.01, 0.014, 0.019, 0.88)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    settings_overlay.add_child(shade)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    settings_overlay.add_child(center)
    var panel := SettingsPanel.new()
    panel.back_pressed.connect(func() -> void: settings_overlay.visible = false)
    center.add_child(panel)
    settings_overlay.visible = false


func _open_settings() -> void:
    settings_overlay.visible = true


func _unhandled_input(event: InputEvent) -> void:
    if settings_overlay != null and settings_overlay.visible and event is InputEventKey \
            and event.pressed and event.keycode == KEY_ESCAPE:
        settings_overlay.visible = false
        get_viewport().set_input_as_handled()


func _on_preview() -> void:
    get_tree().change_scene_to_file("res://casino2_preview.tscn")

func _on_quit() -> void:
    get_tree().quit()

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
