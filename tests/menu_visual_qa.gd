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
    var quit_button := menu_buttons.get_node_or_null("QuitButton") as Button
    var settings_button := menu_buttons.get_node_or_null("SettingsButton") as Button
    var menu_icons = preload("res://ui/menu_icons.gd")
    for name in ["play", "resume", "settings", "archive", "stats", "credits",
            "new", "load", "home", "quit", "update", "install",
            "profile", "add_profile", "edit", "delete", "back", "history"]:
        var texture: Texture2D = menu_icons.texture(name)
        if texture == null or texture.get_size().x < 18.0:
            _fail("Shared vector menu icon missing: " + name)
            return
    for id in ["PlayButton", "SettingsButton", "CreditsButton", "QuitButton", "UpdateButton"]:
        var icon_button := menu_buttons.get_node(id) as Button
        if icon_button.icon == null or str(icon_button.get("symbol")).is_empty():
            _fail("Main menu button has no icon: " + id)
            return
    if str(play_button.get("accent")) != "green" or str(quit_button.get("accent")) != "red" \
            or str(settings_button.get("accent")) != "gold":
        _fail("Main-menu semantic green, red and gold borders were not applied")
        return
    var skin := normal_surface as StyleBoxTexture
    if absf(skin.texture_margin_left - skin.texture_margin_right) > 0.001:
        _fail("Button nine-slice margins are asymmetric")
        return
    # The smallest live OptionButton is 36px high. The previous 52px
    # vertical caps caused the clipped upper/lower halves in Settings.
    var palette = preload("res://ui/menu_style.gd")
    for type in ["gold", "green", "red"]:
        for state in ["normal", "hover", "pressed", "disabled"]:
            var shared_skin := palette.button_skin(state, false, type) as StyleBoxTexture
            var caps := shared_skin.texture_margin_top + shared_skin.texture_margin_bottom
            var source_height := shared_skin.texture.get_height()
            if caps > 36.0 or caps > float(source_height):
                _fail("Nine-slice caps clip 36px dropdowns: %s/%s: %.0fpx" % [type, state, caps])
                return
            if absf(shared_skin.texture_margin_top - shared_skin.texture_margin_bottom) > 0.001:
                _fail("Nine-slice vertical caps must stay balanced")
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
    menu.call("_on_play")
    var profile_overlay := menu.get("profile_overlay") as Control
    var profile_picker := menu.get("profile_panel") as Control
    if profile_overlay == null or not profile_overlay.visible \
            or profile_picker == null or (profile_picker.get("slot_buttons") as Array).size() != 5:
        _fail("Profile selection lost its five-slot menu transition")
        return
    for slot_button in profile_picker.get("slot_buttons"):
        if not (slot_button is Button) or (slot_button as Button).icon == null:
            _fail("Profile slots must have a themed icon and custom button skin")
            return
    menu.queue_free()
    await process_frame

    var pause_ui := PAUSE.new() as CanvasLayer
    root.add_child(pause_ui)
    await process_frame
    if pause_ui.get("credits_panel") == null:
        _fail("Pause menu has no credits entry")
        return
    var pause_buttons: Array = pause_ui.get("localized_buttons")
    var section_labels: Array = pause_ui.get("section_labels")
    if pause_buttons.size() != 9 or section_labels.size() != 3:
        _fail("Pause menu action groups lost their hierarchy")
        return
    for button in pause_buttons:
        var control := button as Button
        if control == null or control.icon == null or not control.has_meta("translation_key"):
            _fail("Every pause action must have an icon and localization key")
            return
        match str(control.get_meta("translation_key")):
            "pause.resume":
                if str(control.get("accent")) != "green":
                    _fail("Resume action must be primary")
                    return
            "pause.new_game":
                if str(control.get("accent")) != "amber":
                    _fail("New game needs its distinct warm accent")
                    return
            "pause.quit":
                if str(control.get("accent")) != "red":
                    _fail("Quit must remain visually destructive")
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
