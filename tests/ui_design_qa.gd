extends SceneTree
## Isolated regression checks for the shared UI design system.
const Style = preload("res://ui/menu_style.gd")
const Luminous = preload("res://ui/luminous_button.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("Casino UI design QA: " + message)
    quit(1)


func _run() -> void:
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
        if pixels == null or pixels.get_pixel(96, 3).is_equal_approx(pixels.get_pixel(96, 32)):
            _fail("Vector skin failed to render a distinct rim")
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
    quit(0)
