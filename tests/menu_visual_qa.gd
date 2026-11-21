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
    if menu.has_node("Footnote") or menu.get_script().source_code.contains("$Footnote"):
        _fail("Bottom menu help text was not removed")
        return
    var sound = root.get_node_or_null("UISfx")
    var sound_player := sound.get_node_or_null("Click") as AudioStreamPlayer if sound != null else null
    if sound == null or sound_player == null or not (sound_player.stream is AudioStreamWAV) \
            or sound_player.bus != "UI":
        _fail("Original menu click sound or independent UI bus is missing")
        return
    var play_button := menu_buttons.get_node_or_null("PlayButton") as Button
    var focus_surface := play_button.get_theme_stylebox("focus")
    var normal_surface := play_button.get_theme_stylebox("normal")
    if not (focus_surface is StyleBoxEmpty) or not (normal_surface is StyleBoxTexture) \
            or not play_button.has_meta("_ui_click_attached"):
        _fail("Main menu buttons must use sculpted skins without sticky mouse focus outlines")
        return
    var credits_source := preload("res://ui/credits_panel.gd").new()
    if not str(credits_source.call("_credit_text")).contains("freesound.org/people/leonelmail/sounds/329533/") \
            or not str(credits_source.call("_credit_text")).contains("CC0 1.0"):
        _fail("Room-tone source and CC0 license missing from in-game credits")
        return
    credits_source.free()
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
