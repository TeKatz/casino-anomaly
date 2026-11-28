extends Control
const MenuStyle = preload("res://ui/menu_style.gd")

const RuntimeCache = preload("res://gameplay/runtime_asset_cache.gd")
const Controls = preload("res://gameplay/input_bindings.gd")
const FitCenter = preload("res://ui/fit_centered_panel.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const CreditsPanel = preload("res://ui/credits_panel.gd")
const ProfilePanel = preload("res://ui/profile_panel.gd")
const ProfileSideCards = preload("res://ui/profile_side_cards.gd")
const ArchivePanel = preload("res://ui/anomaly_archive_panel.gd")
const RunResults = preload("res://ui/run_results_panel.gd")
var results_overlay: Control
const Loc = preload("res://gameplay/localization.gd")
var settings_overlay: Control
var credits_overlay: Control
var credits_panel: PanelContainer
var profile_panel: PanelContainer
var profile_overlay: Control
var profile_side_cards: Control
var archive_panel: PanelContainer
var archive_overlay: Control
var overlay_tween: Tween
var active_overlay: Control
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
    # Release cache-only references from the previous run. Live scene nodes
    # retain their resources until Godot finishes the normal scene handoff.
    RuntimeCache.clear()
    var preferences := get_node_or_null("/root/GameSettings")
    if preferences != null:
        preferences.call("set_menu_context", true)
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
    # Loading a run is a contextual action inside the selected profile.
    $CenterPanel/Content/Stack/ContinueButton.visible = false
    $CenterPanel/Content/Stack/PlayButton.pressed.connect(_on_play)
    MenuStyle.attach_sound($CenterPanel/Content/Stack/ContinueButton, "confirmation")
    $CenterPanel/Content/Stack/ContinueButton.pressed.connect(_on_continue)
    $CenterPanel/Content/Stack/SettingsButton.pressed.connect(_open_settings)
    $CenterPanel/Content/Stack/CreditsButton.pressed.connect(_open_credits)
    $CenterPanel/Content/Stack/QuitButton.pressed.connect(_on_quit)
    _create_settings_overlay()
    _create_credits_overlay()
    _create_profile_overlay()
    _create_archive_overlay()
    update_button.pressed.connect(_check_update)
    install_button.pressed.connect(_install_update)
    request.request_completed.connect(_on_request_completed)
    var game_settings = get_node_or_null("/root/GameSettings")
    if game_settings != null:
        game_settings.options_changed.connect(_on_setting_changed)
    _localize_ui()
    get_viewport().size_changed.connect(_update_layout)
    ($CenterPanel as Control).minimum_size_changed.connect(_queue_menu_layout)
    _update_layout()
    _animate_intro()
    $CasinoPanorama.panorama_ready.connect(_on_panorama_ready)
    $CasinoPanorama.panorama_failed.connect(_on_panorama_failed)
    if DisplayServer.get_name() != "headless":
        var first_launch := not get_tree().root.has_meta("_casino_intro_seen")
        $StartupIntro.begin(first_launch and not bool(Controls.pref(self, "skip_creator_intro", false)))
        $StartupIntro.finished.connect(_on_startup_finished)
    if state != null and bool(state.get("report_pending")):
        _show_run_results(state.call("get_run_report"))
    if bool(Controls.pref(self, "auto_updates", true)):
        call_deferred("_check_update")

func _exit_tree() -> void:
    var preferences := get_node_or_null("/root/GameSettings")
    if preferences != null:
        preferences.call("set_menu_context", false)
    var sound := get_node_or_null("/root/AudioDirector")
    if sound != null:
        sound.set_menu_music_enabled(false)


func _on_setting_changed(key: String) -> void:
    if key == "language":
        _localize_ui()
        if credits_panel != null:
            credits_panel.call("refresh_language")
        if profile_panel != null:
            profile_panel.call("refresh")
        if archive_panel != null:
            archive_panel.call("refresh_language")

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
    profile_panel.call("refresh")
    _show_overlay(profile_overlay)
    var slot := int(profile_panel.get("selected_slot"))
    var occupied := bool(profile_panel.call("is_selected_occupied"))
    profile_side_cards.call("sync_selection", slot, occupied, true)


func _on_continue() -> void:
    _on_play()


func _create_profile_overlay() -> void:
    profile_panel = ProfilePanel.new()
    profile_overlay = _build_overlay(profile_panel)
    profile_side_cards = ProfileSideCards.new()
    profile_side_cards.name = "ProfileSideCards"
    profile_overlay.add_child(profile_side_cards)
    profile_side_cards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    profile_side_cards.call("bind_panel", profile_panel)
    profile_side_cards.connect("open_requested", Callable(self, "_open_profile_archive"))
    profile_panel.connect("selection_changed", Callable(profile_side_cards, "sync_selection"))
    profile_panel.back_pressed.connect(func() -> void: _hide_overlay(profile_overlay))
    profile_panel.launch_requested.connect(_fade_to_scene)


func _create_archive_overlay() -> void:
    archive_panel = ArchivePanel.new()
    archive_overlay = _build_overlay(archive_panel)
    archive_panel.back_pressed.connect(_back_from_profile_archive)


func _open_profile_archive(next_mode: String) -> void:
    archive_panel.call("show_mode", next_mode)
    _show_overlay(archive_overlay)


func _back_from_profile_archive() -> void:
    profile_panel.call("refresh")
    _show_overlay(profile_overlay)
    # Coming back from the archive must restore the preview cards' exact
    # geometry and current data, rather than keeping an old slide state.
    profile_side_cards.call("sync_selection",
        int(profile_panel.get("selected_slot")),
        bool(profile_panel.call("is_selected_occupied")), false)


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
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.024, 0.04, 0.94)
    overlay.add_child(shade)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := FitCenter.new()
    overlay.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.add_child(content)
    overlay.visible = false
    return overlay


func _show_overlay(overlay: Control) -> void:
    if overlay_tween != null and overlay_tween.is_running():
        overlay_tween.kill()
    var previous := active_overlay
    for candidate in [profile_overlay, archive_overlay, credits_overlay, settings_overlay, results_overlay]:
        if candidate != null and candidate != overlay and candidate != previous:
            candidate.visible = false
    active_overlay = overlay
    overlay.visible = true
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.move_to_front()
    if bool(Controls.pref(self, "reduced_menu_motion", false)):
        overlay.modulate.a = 1.0
        overlay.position.x = 0.0
        if previous != null and previous != overlay:
            previous.hide()
        return
    overlay.modulate.a = 0.0
    overlay.position.x = 18.0
    overlay_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    overlay_tween.tween_property(overlay, "modulate:a", 1.0, 0.25)
    overlay_tween.tween_property(overlay, "position:x", 0.0, 0.25)
    if previous != null and previous != overlay and is_instance_valid(previous):
        previous.visible = true
        previous.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay_tween.tween_property(previous, "modulate:a", 0.0, 0.15)
        overlay_tween.chain().tween_callback(func() -> void:
            if is_instance_valid(previous) and previous != active_overlay:
                previous.visible = false
        )


func _hide_overlay(overlay: Control) -> void:
    if overlay_tween != null and overlay_tween.is_running():
        overlay_tween.kill()
    if active_overlay == overlay:
        active_overlay = null
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if bool(Controls.pref(self, "reduced_menu_motion", false)):
        overlay.hide()
        overlay.position.x = 0.0
        return
    overlay_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    overlay_tween.tween_property(overlay, "modulate:a", 0.0, 0.18)
    overlay_tween.tween_property(overlay, "position:x", 12.0, 0.18)
    overlay_tween.chain().tween_callback(func() -> void:
        if is_instance_valid(overlay) and overlay != active_overlay:
            overlay.visible = false
            overlay.position.x = 0.0
    )


func _open_settings() -> void:
    _show_overlay(settings_overlay)


func _open_credits() -> void:
    _show_overlay(credits_overlay)


func _update_layout() -> void:
    var view_size := get_viewport_rect().size
    var compact := view_size.x < 980.0
    $Brand.visible = not compact
    var panel := $CenterPanel as PanelContainer
    # Size to the real visible controls, not a fixed full-height glass slab.
    # Keep the right edge fixed even when translations or the update button
    # change the natural minimum size.
    var minimum := panel.get_combined_minimum_size()
    var natural_width := maxf(360.0, minimum.x)
    var natural_height := maxf(300.0, minimum.y)
    var available_width := view_size.x * (0.76 if compact else 0.38)
    var available_height := maxf(120.0, view_size.y - 56.0)
    var fit_scale := minf(1.0, minf(available_width / natural_width, available_height / natural_height))
    panel.pivot_offset = Vector2.ZERO
    panel.scale = Vector2.ONE * fit_scale
    panel.anchor_left = 0.0
    panel.anchor_right = 0.0
    panel.anchor_top = 0.0
    panel.anchor_bottom = 0.0
    var left := (view_size.x - natural_width * fit_scale) * 0.5 if compact else view_size.x * 0.96 - natural_width * fit_scale
    var top := (view_size.y - natural_height * fit_scale) * 0.5
    panel.offset_left = left
    panel.offset_right = left + natural_width
    panel.offset_top = top
    panel.offset_bottom = top + natural_height
    if profile_side_cards != null:
        profile_side_cards.call_deferred("_layout_cards")


func _queue_menu_layout() -> void:
    call_deferred("_update_layout")


func _on_panorama_ready() -> void:
    $Background.hide()
    $StartupIntro.complete()


func _on_panorama_failed() -> void:
    $Background.show()
    # A broken/missing asset must not strand the user at startup.
    $StartupIntro.complete()


func _on_startup_finished() -> void:
    get_tree().root.set_meta("_casino_intro_seen", true)


func _animate_intro() -> void:
    if bool(Controls.pref(self, "reduced_menu_motion", false)):
        return
    $Brand.modulate.a = 0.0
    $CenterPanel.modulate.a = 0.0
    var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property($Brand, "modulate:a", 1.0, 0.72)
    tween.tween_property($CenterPanel, "modulate:a", 1.0, 0.48)


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
    tween.tween_callback(func() -> void:
        var loader = get_node_or_null("/root/SceneLoader")
        $CasinoPanorama.set_suspended(true)
        screen.visible = false
        if loader == null or not loader.travel_to(scene_path):
            changing_scene = false
            $CasinoPanorama.set_suspended(false)
            _set_status("menu.failed_state")
            return
        loader.transition_failed.connect(_on_scene_load_failed, CONNECT_ONE_SHOT)
    )


func _on_scene_load_failed(_path: String) -> void:
    changing_scene = false
    $CasinoPanorama.set_suspended(false)


func _unhandled_input(event: InputEvent) -> void:
    if active_overlay != null and (Controls.pressed(event, "pause") or event.is_action_pressed("ui_cancel")):
        # During cross-fades the outgoing screen may still be visible;
        # Escape always belongs to the CURRENT menu, never the outgoing one.
        MenuStyle.play_sound("back")
        if active_overlay == archive_overlay:
            _back_from_profile_archive()
        elif active_overlay == results_overlay:
            _close_run_results()
        else:
            _hide_overlay(active_overlay)
        get_viewport().set_input_as_handled()


func _on_quit() -> void:
    if changing_scene:
        return
    if bool(Controls.pref(self, "confirm_quit", false)):
        var dialog := ConfirmationDialog.new()
        dialog.title = "Casino Anomaly"
        dialog.dialog_text = "Spiel beenden?" if Controls.pref(self, "language", "en") == "de" else "Quit the game?"
        add_child(dialog)
        MenuStyle.apply_confirmation(dialog,true)
        dialog.ok_button_text = "Beenden" if Controls.pref(self,"language","en") == "de" else "Quit"
        dialog.cancel_button_text = "Abbrechen" if Controls.pref(self,"language","en") == "de" else "Cancel"
        MenuStyle.attach_sound(dialog.get_ok_button(), "navigation")
        MenuStyle.attach_sound(dialog.get_cancel_button(), "back")
        dialog.confirmed.connect(_quit_confirmed)
        dialog.canceled.connect(dialog.queue_free)
        dialog.popup_centered()
        return
    _quit_confirmed()

func _quit_confirmed() -> void:
    if changing_scene:
        return
    changing_scene = true
    var screen := $Transition as ColorRect
    screen.move_to_front()
    screen.visible = true
    screen.modulate.a = 0.0
    var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(screen, "modulate:a", 1.0, 0.30)
    tween.tween_callback(Callable(get_node("/root/AudioDirector"), "request_quit"))

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
    get_node("/root/AudioDirector").call("request_quit")


func _show_run_results(report: Dictionary) -> void:
    if report.is_empty():
        return
    var results: PanelContainer = RunResults.new()
    results.call("set_report",report)
    results_overlay = _build_overlay(results)
    results.connect("back_pressed",_close_run_results)
    _show_overlay(results_overlay)
    var screen: ColorRect = $Transition as ColorRect
    screen.move_to_front()
    screen.show()
    screen.modulate.a = 1.0
    var fade: Tween = create_tween()
    fade.tween_property(screen,"modulate:a",0.0,0.55)
    fade.tween_callback(screen.hide)


func _close_run_results() -> void:
    var state: Node = get_node_or_null("/root/LoopState")
    if state != null:
        state.call("acknowledge_run_report")
    if is_instance_valid(results_overlay):
        _hide_overlay(results_overlay)
