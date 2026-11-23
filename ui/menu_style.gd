extends RefCounted
## Premium symmetrical nine-slice skins shared by main, pause, dialogue and
## settings. Every face has the same rounded silhouette: NO left protrusions.
## Gold is the default; new game and quit use dedicated green/red outlines.
const GOLD := Color("#dabd84")
const GREEN := Color("#75c899")
const RED := Color("#df8490")
const AMBER := Color("#f2ae70")
const PALE := Color("#f5e9dc")
const SKIN_WIDTH := 256
const SKIN_HEIGHT := 48
const INSET := 5.0
const RADIUS := 10.0
static var _skin_cache: Dictionary = {}


static func accent_color(accent: String) -> Color:
    match accent:
        "green":
            return GREEN
        "red":
            return RED
        "amber":
            return AMBER
        _:
            return GOLD


static func button_skin(state: String, featured: bool = false, accent: String = "gold") -> StyleBoxTexture:
    var key := "%s_%s_%s" % [state, accent, "featured" if featured else "standard"]
    if _skin_cache.has(key):
        return _skin_cache[key] as StyleBoxTexture

    var top := Color("#334b62")
    var bottom := Color("#142438")
    match state:
        "hover":
            top = Color("#4d657c")
            bottom = Color("#1c354a")
        "pressed":
            top = Color("#1e2e43")
            bottom = Color("#101e30")
        "disabled":
            top = Color("#1b2938")
            bottom = Color("#101b2a")
    if featured and state == "normal":
        top = Color("#465e72")
        bottom = Color("#21374b")
    if featured and state == "hover":
        top = Color("#5a7085")
        bottom = Color("#294256")
    var rim := accent_color(accent)
    if state == "disabled":
        rim = Color("#62717b")

    var image := Image.create_empty(SKIN_WIDTH, SKIN_HEIGHT, false, Image.FORMAT_RGBA8)
    var half_x := float(SKIN_WIDTH) * 0.5
    var half_y := float(SKIN_HEIGHT) * 0.5
    for y in range(SKIN_HEIGHT):
        var v := float(y) / float(SKIN_HEIGHT - 1)
        for x in range(SKIN_WIDTH):
            var px := float(x) + 0.5 - half_x
            var py := float(y) + 0.5 - half_y
            # Signed distance to a perfectly symmetrical rounded rectangle.
            var dx := absf(px) - (half_x - INSET - RADIUS)
            var dy := absf(py) - (half_y - INSET - RADIUS)
            var outside := Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()
            var distance := outside + minf(maxf(dx, dy), 0.0) - RADIUS
            if distance > 6.0:
                continue
            if distance > 0.5:
                var shadow := (1.0 - clampf((distance - 0.5) / 5.5, 0.0, 1.0)) * 0.29
                image.set_pixel(x, y, Color(0.0, 0.0, 0.0, shadow))
                continue

            var coverage := clampf(0.5 - distance, 0.0, 1.0)
            var nx := float(x) / float(SKIN_WIDTH)
            var surface := top.lerp(bottom, pow(v, 0.82))
            # A wide satin reflection, not a line or decorative ornament.
            var reflection := exp(-pow((v - 0.14) / 0.37, 2.0)) * 0.145
            var center_light := exp(-pow((nx - 0.31) / 0.58, 2.0)) * 0.08
            surface = surface.lerp(Color("#c1d8e4"), reflection + center_light)
            var bounce := exp(-pow((v - 0.87) / 0.19, 2.0)) * 0.043
            surface = surface.lerp(Color("#678fa7"), bounce)

            # Clearly visible colored metal rim, 2-3 source pixels thick.
            # Nine-slice preserves the exact same rim on both ends.
            var rim_width := 3.0 if state == "hover" else 2.4
            var edge := clampf((distance + rim_width) / rim_width, 0.0, 1.0)
            var strength := 0.98 if state == "hover" else 0.91
            var polished := rim.lerp(Color.WHITE, 0.18 * (1.0 - v))
            surface = surface.lerp(polished, edge * strength)
            # A very faint colored reflection inside the face ties it together.
            surface = surface.lerp(rim, (1.0 - edge) * 0.025)
            if state == "disabled":
                surface = surface.lerp(Color("#142230"), 0.45)
            image.set_pixel(x, y, Color(surface.r, surface.g, surface.b, coverage))

    var style := StyleBoxTexture.new()
    style.texture = ImageTexture.create_from_image(image)
    # Both vertical caps must fit inside the smallest 36px settings dropdown.
    # The previous 26+26px caps could not fit in 36–43px controls and
    # Godot visibly sliced off their lower halves. Equal caps also avoid
    # asymmetrical side nubs. See settings_pause_qa and menu_visual_qa.
    style.texture_margin_left = 22.0
    style.texture_margin_right = 22.0
    style.texture_margin_top = 15.0
    style.texture_margin_bottom = 15.0
    style.content_margin_left = 23.0
    style.content_margin_right = 23.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    _skin_cache[key] = style
    return style


static func keyboard_focus_skin() -> StyleBoxFlat:
    var focus := StyleBoxFlat.new()
    focus.bg_color = Color.TRANSPARENT
    focus.border_color = Color("#d4e5ed", 0.90)
    focus.set_border_width_all(2)
    focus.set_corner_radius_all(17)
    return focus


static func surface(active: bool = false, hovered: bool = false) -> StyleBoxTexture:
    return button_skin("hover" if hovered else "normal", active)


static func apply_button(button: Button, active: bool = false, accent: String = "gold") -> void:
    button.focus_mode = Control.FOCUS_ALL
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.set_meta("_premium_accent", accent)
    button.add_theme_stylebox_override("normal", button_skin("normal", active, accent))
    button.add_theme_stylebox_override("hover", button_skin("hover", active, accent))
    button.add_theme_stylebox_override("pressed", button_skin("pressed", active, accent))
    button.add_theme_stylebox_override("disabled", button_skin("disabled", active, accent))
    # Mouse focus is empty; keyboard/gamepad focus is set by LuminousButton.
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    button.add_theme_color_override("font_color", PALE)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color("#e4f3f6"))
    button.add_theme_color_override("font_disabled_color", Color("#74818f"))
    button.add_theme_color_override("icon_normal_color", accent_color(accent))
    button.add_theme_color_override("icon_hover_color", Color("#f6f6f2"))
    button.add_theme_color_override("icon_pressed_color", accent_color(accent).lightened(0.18))
    button.add_theme_color_override("icon_disabled_color", Color("#79848c"))
    if not button.has_meta("_ui_click_attached"):
        button.set_meta("_ui_click_attached", true)
        button.pressed.connect(func() -> void:
            var sound = button.get_node_or_null("/root/UISfx")
            if sound != null:
                sound.call("play_click")
        )


static func apply_dropdown(button: OptionButton) -> void:
    apply_button(button)
    # Godot defaults to only 4px, putting the icon against the border.
    button.add_theme_constant_override("arrow_margin", 23)
    button.add_theme_constant_override("h_separation", 12)
    button.add_theme_color_override("font_color", PALE)
    var popup := button.get_popup()
    if popup != null:
        popup.add_theme_stylebox_override("panel", panel())
        var selected := StyleBoxFlat.new()
        selected.bg_color = Color("#35495b")
        selected.border_color = GOLD
        selected.set_border_width_all(1)
        selected.set_corner_radius_all(7)
        popup.add_theme_stylebox_override("hover", selected)
        popup.add_theme_color_override("font_color", PALE)
        popup.add_theme_color_override("font_hover_color", Color.WHITE)


static func panel() -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = Color("#0d1928")
    box.border_color = Color("#9d886d", 0.92)
    box.set_border_width_all(2)
    box.set_corner_radius_all(18)
    box.corner_detail = 12
    box.shadow_color = Color(0, 0, 0, 0.78)
    box.shadow_size = 32
    box.shadow_offset = Vector2(0, 9)
    return box
