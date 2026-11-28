extends SceneTree
## Isolated regression checks for the shared UI design system.
const Style = preload("res://ui/menu_style.gd")
const Luminous = preload("res://ui/luminous_button.gd")
const Kenney = preload("res://ui/kenney_icons.gd")
const MenuIcons = preload("res://ui/menu_icons.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("Casino UI design QA: " + message)
    quit(1)


func _run() -> void:
    if not bool(ProjectSettings.get_setting("gui/theme/default_font_multichannel_signed_distance_field")):
        _fail("Default UI font is not using MSDF")
        return
    for accent in ["gold", "green", "red", "amber"]:
        var normal := Style.button_skin("normal", false, accent)
        var hover := Style.button_skin("hover", false, accent)
        if normal == hover or normal != Style.button_skin("normal", false, accent):
            _fail("Button state or cache regressed")
            return
        if normal.texture == null or normal.texture_margin_top + normal.texture_margin_bottom > 36.0:
            _fail("Missing texture or oversized vertical caps")
            return
        var pixels := normal.texture.get_image()
        if pixels == null or pixels.get_size() != Vector2i(768, 256) or normal.texture.get_size() != Vector2(192, 64):
            _fail("Nine-slice raster density or logical size regressed")
            return
        if pixels.get_pixel(384, 12).is_equal_approx(pixels.get_pixel(384, 128)):
            _fail("Vector skin failed to render a distinct rim")
            return
    for name in Kenney.DRAWINGS:
        var icon := Kenney.texture(name)
        if icon == null or icon.get_width() <= 0 or icon != Kenney.texture(name):
            _fail("Embedded icon failed or was not cached: " + str(name))
            return
        var expected := Vector2i(26, 26)
        if name == "arrow":
            expected = Vector2i(16, 16)
        elif str(name).begins_with("slider"):
            expected = Vector2i(18, 24)
        if icon.get_size() != Vector2(expected) or icon.get_image().get_size() != expected * 4:
            _fail("Kenney icon density or logical size regressed: " + str(name))
            return
    var menu_icon := MenuIcons.texture("settings")
    if menu_icon == null or menu_icon.get_size() != Vector2(30, 30) or menu_icon.get_image().get_size() != Vector2i(120, 120):
        _fail("Menu icon density or logical size regressed")
        return
    var sounds := root.get_node_or_null("UISfx")
    if sounds == null:
        _fail("Missing UI sound singleton")
        return
    for event in ["Navigation", "Confirmation", "Dropdown"]:
        var voice := sounds.get_node_or_null(event) as AudioStreamPlayer
        if voice == null or not (voice.stream is AudioStreamOggVorbis) or voice.bus != "UI":
            _fail("Missing menu sound " + event)
            return
    var panel := Control.new()
    root.add_child(panel)
    var slider := HSlider.new()
    panel.add_child(slider)
    Style.apply_slider(slider)
    if not slider.has_theme_icon_override("grabber") or not slider.has_theme_icon_override("grabber_highlight"):
        _fail("Kenney slider icons missing")
        return
    var toggle := CheckButton.new()
    panel.add_child(toggle)
    Style.apply_toggle(toggle)
    if toggle.get_theme_icon("checked") == toggle.get_theme_icon("unchecked"):
        _fail("Toggle states indistinguishable")
        return
    var dropdown := OptionButton.new()
    panel.add_child(dropdown)
    Style.apply_dropdown(dropdown)
    if not dropdown.has_theme_icon_override("arrow") or not (dropdown.get_theme_stylebox("focus") is StyleBoxFlat):
        _fail("Dropdown arrow or keyboard focus missing")
        return
    var button := Luminous.new()
    panel.add_child(button)
    button.pressed.emit()
    if str(sounds.get("last_event")) != "navigation":
        _fail("Navigation sound routing incorrect")
        return
    button.set_symbol("back")
    button.pressed.emit()
    if str(sounds.get("last_event")) != "back":
        _fail("Back sound routing incorrect")
        return
    Style.attach_sound(button, "confirmation")
    button.pressed.emit()
    if str(sounds.get("last_event")) != "confirmation":
        _fail("Continue sound routing incorrect")
        return
    dropdown.get_popup().about_to_popup.emit()
    if str(sounds.get("last_event")) != "dropdown":
        _fail("Dropdown sound routing incorrect")
        return
    var settings := root.get_node_or_null("GameSettings")
    if settings == null:
        _fail("Missing settings singleton")
        return
    var old = settings.call("get_option", "reduced_menu_motion")
    settings.call("set_option", "reduced_menu_motion", true)
    button.call("_hover_changed", true)
    var bar := ProgressBar.new()
    panel.add_child(bar)
    Style.apply_progress(bar, 65.0)
    var passed := button.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(bar.value, 65.0)
    settings.call("set_option", "reduced_menu_motion", old)
    if not passed:
        _fail("Reduced motion does not bypass visual animation")
        return
    panel.queue_free()
    await process_frame
    print("Casino Anomaly shared UI design QA PASS")
    root.get_node("AudioDirector").call("request_quit")
