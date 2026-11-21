extends RefCounted
## Soft, dimensional glass surfaces used by the main, pause and settings UI.
## Texture generation is deterministic and cached; no decorative glyphs,
## orange hairlines, or third-party visual assets are required.
const GOLD := Color("#e6bb81")
const PALE := Color("#f5e9dc")
const SKIN_WIDTH := 256
const SKIN_HEIGHT := 76
static var _skin_cache: Dictionary = {}


static func button_skin(state: String, featured: bool = false) -> StyleBoxTexture:
    var key := state + ("_primary" if featured else "_secondary")
    if _skin_cache.has(key):
        return _skin_cache[key] as StyleBoxTexture

    var top := Color("#30455b")
    var bottom := Color("#101e30")
    match state:
        "hover":
            top = Color("#526c83")
            bottom = Color("#1c364d")
        "pressed":
            top = Color("#1a283b")
            bottom = Color("#0b1b2d")
        "disabled":
            top = Color("#18232e")
            bottom = Color("#101923")
    if featured and state == "normal":
        top = Color("#415a75")
        bottom = Color("#1b3049")

    var rim := Color("#b1cad8")
    var image := Image.create_empty(SKIN_WIDTH, SKIN_HEIGHT, false, Image.FORMAT_RGBA8)
    for y in range(SKIN_HEIGHT):
        var v := float(y) / float(SKIN_HEIGHT - 1)
        for x in range(SKIN_WIDTH):
            var px := float(x) + 0.5 - float(SKIN_WIDTH) * 0.5
            var py := float(y) + 0.5 - float(SKIN_HEIGHT) * 0.5
            # Organic silhouette: generously curved leading edge, gently
            # rounded trailing edge. This is the button's shape, not a symbol.
            var radius := 26.0 if px < 0.0 else 16.0
            var dx := absf(px) - (float(SKIN_WIDTH) * 0.5 - 6.0 - radius)
            var dy := absf(py) - (float(SKIN_HEIGHT) * 0.5 - 6.0 - radius)
            var distance := Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()
            distance += minf(maxf(dx, dy), 0.0) - radius
            if distance > 6.0:
                continue
            if distance >= 0.5:
                var shadow_alpha := 0.23 * (1.0 - clampf((distance - 0.5) / 5.5, 0.0, 1.0))
                if state == "hover":
                    var aura := (1.0 - clampf((distance - 0.5) / 5.5, 0.0, 1.0)) * 0.12
                    image.set_pixel(x, y, Color(0.30, 0.67, 0.83, maxf(shadow_alpha, aura)))
                else:
                    image.set_pixel(x, y, Color(0.0, 0.0, 0.0, shadow_alpha))
                continue

            var coverage := clampf(0.5 - distance, 0.0, 1.0)
            var surface := top.lerp(bottom, pow(v, 0.82))
            # Layered, soft rectangular reflections rather than decorative
            # bars. A broad ambient highlight runs through the entire skin.
            var nx := float(x) / float(SKIN_WIDTH)
            var reflection := exp(-pow((v - 0.15) / 0.34, 2.0)) * 0.16
            var core := exp(-pow((nx - 0.32) / 0.56, 2.0)) * 0.095
            var shoulder := exp(-pow((nx - 0.78) / 0.40, 2.0)) * 0.055
            surface = surface.lerp(Color("#c1dce7"), reflection + core + shoulder)
            var lower_bounce := exp(-pow((v - 0.92) / 0.23, 2.0)) * 0.065
            surface = surface.lerp(Color("#6699b4"), lower_bounce)
            var edge := clampf(1.0 - (-distance / 2.1), 0.0, 1.0)
            var edge_strength := 0.44 if state == "hover" else 0.25
            if featured and state == "normal":
                edge_strength += 0.07
            surface = surface.lerp(rim, edge * edge_strength)
            if state == "disabled":
                surface = surface.lerp(Color("#121d29"), 0.42)
            image.set_pixel(x, y, Color(surface.r, surface.g, surface.b, coverage * 0.98))

    var style := StyleBoxTexture.new()
    style.texture = ImageTexture.create_from_image(image)
    style.texture_margin_left = 36.0
    style.texture_margin_right = 26.0
    style.texture_margin_top = 20.0
    style.texture_margin_bottom = 20.0
    style.content_margin_left = 20.0
    style.content_margin_right = 20.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    _skin_cache[key] = style
    return style


static func keyboard_focus_skin() -> StyleBoxFlat:
    var focus := StyleBoxFlat.new()
    focus.bg_color = Color.TRANSPARENT
    focus.border_color = Color("#9fc5d5", 0.86)
    focus.set_border_width_all(2)
    focus.corner_radius_top_left = 23
    focus.corner_radius_bottom_left = 23
    focus.corner_radius_top_right = 15
    focus.corner_radius_bottom_right = 15
    return focus


static func surface(active: bool = false, hovered: bool = false) -> StyleBoxTexture:
    return button_skin("hover" if hovered else "normal", active)


static func apply_button(button: Button, active: bool = false) -> void:
    button.focus_mode = Control.FOCUS_ALL
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_stylebox_override("normal", button_skin("normal", active))
    button.add_theme_stylebox_override("hover", button_skin("hover", active))
    button.add_theme_stylebox_override("pressed", button_skin("pressed", active))
    button.add_theme_stylebox_override("disabled", button_skin("disabled", active))
    # A mouse click must not leave Godot's default focus rectangle behind.
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    button.add_theme_color_override("font_color", PALE)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color("#d6edf3"))
    button.add_theme_color_override("font_disabled_color", Color("#74818f"))
    # Bind one consistent UI click to every native Godot Button we style,
    # including settings tabs, confirmation dialogs and dropdowns.
    if not button.has_meta("_ui_click_attached"):
        button.set_meta("_ui_click_attached", true)
        button.pressed.connect(func() -> void:
            var sound = button.get_node_or_null("/root/UISfx")
            if sound != null:
                sound.call("play_click")
        )


static func apply_dropdown(button: OptionButton) -> void:
    apply_button(button)


static func panel() -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = Color("#101c2b")
    box.border_color = Color("#647487")
    box.set_border_width_all(1)
    box.set_corner_radius_all(15)
    box.shadow_color = Color(0, 0, 0, 0.65)
    box.shadow_size = 24
    return box
