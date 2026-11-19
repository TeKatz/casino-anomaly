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
    var saved_hud = settings.get_option("hud_visible")
    var saved_fps = settings.get_option("fps_limit")

    settings.set_option("mouse_sensitivity", 1.35)
    settings.set_option("fov", 86.0)
    settings.set_option("fps_limit", 60)
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
    if tabs.size() != 4:
        _fail("Expected four tab BUTTONS: graphics, audio, controls, gameplay")
        return
    subpanel.call("_switch_tab", 2)
    if int(subpanel.get("selected_tab")) != 2:
        _fail("Tabbed settings cannot switch sections")
        return
    var selected: Button = tabs[2]
    var inactive: Button = tabs[0]
    if (selected.get_theme_stylebox("normal") as StyleBoxFlat).border_width_left <=             (inactive.get_theme_stylebox("normal") as StyleBoxFlat).border_width_left:
        _fail("Selected settings tab is not highlighted")
        return

    settings.set_option("hud_visible", false)
    var loop := room.get_node_or_null("LoopController")
    if loop == null or (loop.get_node("GameHUD") as CanvasLayer).visible:
        _fail("HUD visibility preference is not applied to current run")
        return
    settings.set_option("hud_visible", true)
    pause_menu.call("_close_settings")
    pause_menu.call("_resume")
    if paused or bool(pause_menu.get("open")) or pause_menu.visible or current_scene != room:
        _fail("Resume must return to the same active room without reloading")
        return

    settings.set_option("mouse_sensitivity", saved_sensitivity)
    settings.set_option("fov", saved_fov)
    settings.set_option("hud_visible", saved_hud)
    settings.set_option("fps_limit", saved_fps)
    room.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
    print("Casino Anomaly pause, persistent settings and world-camera input QA PASS")
    quit(0)
