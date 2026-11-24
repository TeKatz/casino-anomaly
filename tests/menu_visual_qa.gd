extends SceneTree
## Menu/credit regression including the isolated casino panorama.
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
    var main_panel := menu.get_node_or_null("CenterPanel") as Control
    var screen := menu.get_viewport_rect().size
    var bounds := main_panel.get_global_rect() if main_panel != null else Rect2()
    if main_panel == null or bounds.position.y < 10.0 \
            or bounds.end.y > screen.y - 10.0:
        _fail("Main menu glass panel is clipped by the top/bottom viewport edge")
        return
    if background == null or not (background.material is ShaderMaterial) or menu_buttons == null:
        _fail("Abstract shader or menu stack missing")
        return
    var panorama := menu.get_node_or_null("CasinoPanorama") as Control
    var view := panorama.get_node_or_null("RenderSurface/World") as SubViewport if panorama != null else null
    if view == null or not view.own_world_3d or not view.gui_disable_input or not (panorama.get_node("RenderSurface") is TextureRect) or view.size != root.size:
        _fail("Panorama viewport is not isolated or native resolution")
        return
    if screen.x >= 980.0 and (bounds.position.x < screen.x * 0.57 or bounds.end.x > screen.x * 0.98 or bounds.size.y > screen.y * 0.85 or (menu.get_node("Brand") as Control).anchor_top > 0.161):
        _fail("Panorama menu positioning regressed")
        return
    var intro := menu.get_node("StartupIntro") as ColorRect
    intro.call("begin", true)
    if not intro.visible or intro.modulate.a != 1.0 or not bool(intro.get("active")) or intro.get_node("Center/Content/Logo").texture == null or not str(intro.get_node("Center/Content/Creator").text).contains("TeKatz"):
        _fail("Opaque branded startup cover missing")
        return
    await process_frame
    if not intro.visible or bool(intro.get("closing")):
        _fail("Startup cover disappeared before panorama readiness")
        return
    var run_state := root.get_node_or_null("LoopState")
    var previous_active = run_state.active
    var previous_tutorial = run_state.tutorial_done
    run_state.active = true
    run_state.tutorial_done = true
    var packed := load("res://main.tscn") as PackedScene
    var installed := bool(panorama.call("install_room", packed))
    run_state.active = previous_active
    run_state.tutorial_done = previous_tutorial
    if not installed:
        _fail("Real casino panorama cannot be instantiated")
        return
    for frame in range(5):
        await process_frame
    if not bool(panorama.get("first_frame_ready")) or not bool(intro.get("closing")) or background.visible:
        _fail("Startup cover did not wait for the panorama-ready signal")
        return
    await create_timer(2.4).timeout
    if intro.visible or bool(intro.get("active")):
        _fail("Startup cover failed to release input after fade")
        return
    intro.call("begin", false)
    if not intro.visible or intro.get_node("Center/Content").visible:
        _fail("Menu return repeated the branded first-launch intro")
        return
    intro.call("complete")
    await create_timer(0.95).timeout
    if intro.visible:
        _fail("Return cover failed to clear")
        return
    var visual := panorama.get("room") as Node3D
    if visual == null or not bool(panorama.get("ready_for_display")) or not visual.has_node("Architecture") or not visual.has_node("SlotMachines"):
        _fail("Casino visual geometry missing")
        return
    for node_name in ["Player", "LoopController", "StreamingPortals", "RoomSoundscape", "VoxelGIRig"]:
        if visual.has_node(node_name):
            _fail("Gameplay node leaked into menu: " + node_name)
            return
    if not visual.find_children("*", "ReflectionProbe", true, false).is_empty() or visual.process_mode != Node.PROCESS_MODE_DISABLED:
        _fail("Menu scene has live reflection capture or gameplay processing")
        return
    for body in visual.find_children("*", "CollisionObject3D", true, false):
        if body.collision_layer != 0 or body.collision_mask != 0:
            _fail("Physics layers remain active in the visual-only menu")
            return
    var rig := panorama.get_node("RenderSurface/World/Showcase/CameraRig") as Node3D
    var camera := rig.get_node("PanoramaCamera") as Camera3D
    if view.get_camera_3d() != camera or root.get_camera_3d() == camera:
        _fail("Panorama camera leaked into the gameplay viewport")
        return
    panorama.call("update_pose", 0.0)
    var start := rig.transform
    panorama.call("update_pose", 10.5)
    if rig.transform.is_equal_approx(start) or absf(rig.position.x) > 0.7:
        _fail("Panorama is static or outside its safe camera path")
        return
    panorama.call("update_pose", 42.0)
    if not rig.transform.is_equal_approx(start):
        _fail("Panorama loop is not seamless")
        return
    var preferences = root.get_node("GameSettings")
    var saved_menu_scale = preferences.get_option("menu_render_scale")
    var saved_menu_mode = preferences.get_option("menu_background")
    preferences.set_option("menu_render_scale", 0.75)
    if view.size != root.size or not is_equal_approx(view.scaling_3d_scale, 0.75):
        _fail("Menu render scale does not use native output with scaled 3D")
        return
    preferences.set_option("menu_background", "abstract")
    if panorama.visible or not background.visible or view.render_target_update_mode != SubViewport.UPDATE_DISABLED:
        _fail("Abstract menu does not suspend panorama")
        return
    preferences.set_option("menu_background", "still")
    if not panorama.visible or background.visible or view.render_target_update_mode != SubViewport.UPDATE_ONCE:
        _fail("Still menu does not request a single render")
        return
    preferences.set_option("menu_background", saved_menu_mode)
    preferences.set_option("menu_render_scale", saved_menu_scale)
    preferences.save_options()
    panorama.call("set_suspended", true)
    if view.render_target_update_mode != SubViewport.UPDATE_DISABLED:
        _fail("Menu panorama still renders while loading a game")
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
    for event in ["Navigation", "Confirmation", "Dropdown"]:
        var voice := sound.get_node_or_null(event) as AudioStreamPlayer
        if voice == null or not (voice.stream is AudioStreamOggVorbis) or voice.bus != "UI":
            _fail("Missing Kenney menu voice: " + event)
            return
    var style_api = preload("res://ui/menu_style.gd")
    var probe := Button.new()
    menu.add_child(probe)
    style_api.attach_sound(probe, "navigation")
    var before := int(sound.get("play_count"))
    probe.pressed.emit()
    if str(sound.get("last_event")) != "navigation" or int(sound.get("play_count")) != before + 1:
        _fail("Navigation sound missing or duplicated")
        return
    style_api.attach_sound(probe, "back")
    probe.pressed.emit()
    if str(sound.get("last_event")) != "back" or int(sound.get("play_count")) != before + 2:
        _fail("Back sound missing or duplicated")
        return
    style_api.attach_sound(probe, "confirmation")
    probe.pressed.emit()
    if str(sound.get("last_event")) != "confirmation" or int(sound.get("play_count")) != before + 3:
        _fail("Confirmation sound missing or duplicated")
        return
    var sound_dropdown := OptionButton.new()
    menu.add_child(sound_dropdown)
    style_api.apply_dropdown(sound_dropdown)
    sound_dropdown.pressed.emit()
    sound_dropdown.get_popup().about_to_popup.emit()
    if str(sound.get("last_event")) != "dropdown" or int(sound.get("play_count")) != before + 4:
        _fail("Dropdown opening sound missing or duplicated")
        return
    probe.queue_free()
    sound_dropdown.queue_free()
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
            "profile", "add_profile", "edit", "delete", "back", "history",
            "graphics", "audio", "controls", "gameplay", "general", "accessibility", "achievements", "modes"]:
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
    var kenney = preload("res://ui/kenney_icons.gd")
    for name in kenney.DRAWINGS:
        var icon: Texture2D = kenney.texture(name)
        if icon == null or icon.get_width() <= 0 or icon != kenney.texture(name):
            _fail("Embedded Kenney icon missing or uncached: " + str(name))
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
    var side_cards := menu.get("profile_side_cards") as Control
    if side_cards == null or side_cards.get_node_or_null("StatisticsCard") == null \
            or side_cards.get_node_or_null("ArchiveCard") == null:
        _fail("Flanking statistics and anomaly archive panels are missing")
        return
    var buttons: Array = profile_picker.get("slot_delete_buttons")
    if buttons.size() != 5:
        _fail("Every profile row needs an independent delete icon")
        return
    for delete_icon in buttons:
        if not (delete_icon as Button).get("compact_icon") \
                or (delete_icon as Button).icon == null:
            _fail("Small per-slot delete button has no compact icon skin")
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
