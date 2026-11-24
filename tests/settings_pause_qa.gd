extends SceneTree
## Verify tab UI, actual pause/resume, saved options and movement invariance
## across rotated room parents, without mutating the authored casino scene.

const ROOM = preload("res://main.tscn")
const MENU = preload("res://menu.tscn")


func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    paused = false
    push_error("Casino settings/pause QA: " + reason)
    quit(1)


func _run() -> void:
    var settings = root.get_node_or_null("GameSettings")
    var state = root.get_node_or_null("LoopState")
    if settings == null or state == null:
        _fail("Settings and game-state autoloads must exist")
        return

    var saved_sensitivity = settings.get_option("mouse_sensitivity")
    var saved_fov = settings.get_option("fov")
    var saved_language = settings.get_option("language")
    var saved_fps = settings.get_option("fps_limit")
    var saved_gi = settings.get_option("voxel_gi")
    var saved_contrast = settings.get_option("image_contrast")

    settings.set_option("mouse_sensitivity", 1.35)
    settings.set_option("fov", 86.0)
    settings.set_option("fps_limit", 60)
    await create_timer(0.5).timeout
    if absf(float(settings.get_option("mouse_sensitivity")) - 1.35) > 0.001             or absf(float(settings.get_option("fov")) - 86.0) > 0.01             or Engine.max_fps != 60 or not FileAccess.file_exists("user://casino_settings.cfg"):
        _fail("Changing settings failed to apply and persist")
        return

    var menu := MENU.instantiate() as Control
    if menu == null or menu.get_node_or_null("CenterPanel/Content/Stack/SettingsButton") == null:
        _fail("Settings are missing from the main menu")
        return
    root.add_child(menu)
    await process_frame
    if menu.get_node_or_null("SettingsButton") != null:
        _fail("Settings button should belong to the menu panel")
        return
    menu.call("_open_settings")
    var overlay := menu.get("settings_overlay") as Control
    if overlay == null or not overlay.visible:
        _fail("Main-menu settings panel did not open")
        return
    menu.queue_free()
    await process_frame

    state.save_path = "user://casino_settings_pause_qa_run.cfg"
    state.start_new_run()
    state.complete_tutorial()
    var room := ROOM.instantiate() as Node3D
    root.add_child(room)
    current_scene = room
    await process_frame
    await process_frame
    var player := room.get_node_or_null("Player") as CharacterBody3D
    var pause_menu = player.get_node_or_null("InGameMenu") if player != null else null
    if player == null or pause_menu == null:
        _fail("The active player has no in-place pause menu")
        return
    if absf((player.get_node("Camera3D") as Camera3D).fov - 86.0) > 0.1:
        _fail("Gameplay FOV did not follow saved settings")
        return

    # The movement vector must not flip after a 180-degree room-parent change.
    var movement_before: Vector3 = player.call("_movement_direction", Vector2(0, -1))
    var rotated := Node3D.new()
    rotated.name = "RotatedParentQA"
    rotated.rotation.y = PI
    room.add_child(rotated)
    player.reparent(rotated, true)
    var movement_after: Vector3 = player.call("_movement_direction", Vector2(0, -1))
    if movement_before.distance_to(movement_after) > 0.0001:
        _fail("WASD movement reversed after rotated room handoff")
        return

    pause_menu.call("_pause")
    if not paused or not bool(pause_menu.get("open")) or not pause_menu.visible:
        _fail("ESC pause should suspend, not leave, the current scene")
        return
    pause_menu.call("_open_settings")
    var subpanel := pause_menu.get("settings_panel") as Control
    if subpanel == null or not subpanel.visible:
        _fail("Pause settings submenu not available")
        return
    var tabs: Array = subpanel.get("tabs")
    if tabs.size() != 6:
        _fail("Expected six category buttons including Accessibility")
        return
    subpanel.call("_switch_tab", 2)
    if int(subpanel.get("selected_tab")) != 2:
        _fail("Tabbed settings cannot switch sections")
        return
    var selected: Button = tabs[2]
    var inactive: Button = tabs[0]
    var chosen_style := selected.get_theme_stylebox("normal")
    var inactive_style := inactive.get_theme_stylebox("normal")
    if not (chosen_style is StyleBoxTexture) or not (inactive_style is StyleBoxTexture) \
            or chosen_style == inactive_style:
        _fail("Selected settings tab does not have its own active surface")
        return
    subpanel.call("_switch_tab", 0)
    var options_box := subpanel.get("options_box") as VBoxContainer
    var dropdown: OptionButton
    for line in options_box.get_children():
        for item in line.get_children():
            if item is OptionButton:
                dropdown = item as OptionButton
                break
        if dropdown != null:
            break
    if dropdown == null or dropdown.get_theme_constant("arrow_margin") < 18:
        _fail("Dropdown arrow must sit well inside the right border")
        return
    # Ensure every themed surface can fit vertically in real controls.
    for control in [selected, inactive, dropdown, subpanel.get("back_button") as Button]:
        for button_state in ["normal", "hover", "pressed"]:
            var box := (control as Button).get_theme_stylebox(button_state) as StyleBoxTexture
            if box == null:
                _fail("Settings control lost its premium button skin")
                return
            var source_caps := box.texture_margin_top + box.texture_margin_bottom
            if source_caps > (control as Control).custom_minimum_size.y:
                _fail("Settings skin overflows %s (%s): caps %.0fpx > height %.0fpx" % [
                    (control as Node).name, button_state, source_caps, (control as Control).custom_minimum_size.y])
                return

    var loop := room.get_node_or_null("LoopController")
    if loop == null or loop.get_node_or_null("GameHUD") != null:
        _fail("Gameplay must not expose progress, mistakes, or helper HUD text")
        return
    subpanel.call("_switch_tab", 3)
    settings.set_option("language", "de")
    await process_frame
    if settings.get_option("language") != "de" or tabs[0].text != "Grafik":
        _fail("German language choice was not applied to the settings UI")
        return
    settings.set_option("language", "en")
    await process_frame
    if settings.get_option("language") != "en" or tabs[0].text != "Graphics":
        _fail("English language choice was not applied without restarting")
        return
    subpanel.call("_switch_tab", 0)
    settings.set_option("image_contrast", 0.75)
    await process_frame
    var current_environment := room.get_node("WorldEnvironment") as WorldEnvironment
    if absf(float(settings.get_option("image_contrast")) - 0.75) > 0.001 \
            or current_environment.environment == null \
            or absf(current_environment.environment.adjustment_contrast - 0.75) > 0.001:
        _fail("Image contrast must apply immediately in the active casino")
        return
    settings.set_option("voxel_gi", false)
    await process_frame
    var gi_rig := room.get_node_or_null("VoxelGIRig")
    if settings.get_option("voxel_gi") != false or gi_rig == null:
        _fail("VoxelGI toggle is missing from persistent graphics options")
        return
    for probe in gi_rig.get_children():
        if probe is VoxelGI and probe.visible:
            _fail("VoxelGI is still rendering after switching it off")
            return
    pause_menu.call("_close_settings")
    pause_menu.call("_resume")
    if paused or bool(pause_menu.get("open")) or pause_menu.visible or current_scene != room:
        _fail("Resume must return to the same active room without reloading")
        return

    settings.set_option("mouse_sensitivity", saved_sensitivity)
    settings.set_option("fov", saved_fov)
    settings.set_option("language", saved_language)
    settings.set_option("fps_limit", saved_fps)
    settings.set_option("voxel_gi", saved_gi)
    settings.set_option("image_contrast", saved_contrast)
    settings.save_options()
    room.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
    print("Casino Anomaly pause, persistent settings and world-camera input QA PASS")
    quit(0)
