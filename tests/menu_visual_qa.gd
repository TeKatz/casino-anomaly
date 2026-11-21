extends SceneTree
## Lightweight menu/credit regression without loading expensive casino meshes.
const MENU = preload("res://menu.tscn")
const PAUSE = preload("res://ui/pause_menu.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    paused = false
    push_error("Casino abstract menu QA: " + message)
    quit(1)


func _run() -> void:
    var menu := MENU.instantiate() as Control
    if menu == null:
        _fail("Menu could not be instantiated")
        return
    root.add_child(menu)
    await process_frame
    var background := menu.get_node_or_null("Background") as ColorRect
    var menu_buttons := menu.get_node_or_null("CenterPanel/Content/Stack")
    if background == null or not (background.material is ShaderMaterial) or menu_buttons == null:
        _fail("Abstract shader or menu stack missing")
        return
    for id in ["PlayButton", "ContinueButton", "SettingsButton", "CreditsButton", "QuitButton"]:
        var button := menu_buttons.get_node_or_null(id) as Button
        if button == null or button.get_script() == null:
            _fail("Custom menu control missing: " + id)
            return
    if menu_buttons.get_node_or_null("Casino2PreviewButton") != null             or ResourceLoader.exists("res://casino2_preview.tscn"):
        _fail("Deprecated standalone casino preview is still accessible")
        return
    menu.call("_open_settings")
    if not (menu.get("settings_overlay") as Control).visible:
        _fail("Settings cannot open")
        return
    menu.call("_open_credits")
    if not (menu.get("credits_overlay") as Control).visible:
        _fail("Main-menu credits cannot open")
        return
    var credits := menu.get("credits_panel") as Control
    if credits == null or not credits.has_method("refresh_language"):
        _fail("Credits panel missing")
        return
    menu.queue_free()
    await process_frame

    var pause_ui := PAUSE.new() as CanvasLayer
    root.add_child(pause_ui)
    await process_frame
    if pause_ui.get("credits_panel") == null:
        _fail("Pause menu has no credits entry")
        return
    pause_ui.call("_open_credits")
    if not (pause_ui.get("credits_panel") as Control).visible:
        _fail("Pause credits cannot open")
        return
    pause_ui.call("_close_credits")
    if (pause_ui.get("credits_panel") as Control).visible:
        _fail("Pause credits cannot close")
        return
    pause_ui.queue_free()
    await process_frame
    print("Casino Anomaly abstract UI and credits QA PASS")
    quit(0)
