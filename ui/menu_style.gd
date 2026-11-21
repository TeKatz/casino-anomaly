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

    var top := Color("#293d51")
    var bottom := Color("#142235")
    match state:
        "hover":
            top = Color("#41586b")
            bottom = Color("#203649")
        "pressed":
            top = Color("#1a2939")
            bottom = Color("#101d2a")
        "disabled":
            top = Color("#18232e")
            bottom = Color("#101923")
    if featured and state == "normal":
        top = Color("#3a4d66")
        bottom = Color("#202e45")

    var rim := Color("#8faabd")
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
                image.set_pixel(x, y, Color(0.0, 0.0, 0.0, shadow_alpha))
                continue

            var coverage := clampf(0.5 - distance, 0.0, 1.0)
            var surface := top.lerp(bottom, pow(v, 0.78))
            # Broad reflected light and an inset luminous core add depth
            # without little lines, diamonds, or other decorative ornaments.
            var reflection := exp(-pow((v - 0.20) / 0.28, 2.0)) * 0.14
            var core := exp(-pow((float(x) / float(SKIN_WIDTH) - 0.37) / 0.43, 2.0)) * 0.07
            surface = surface.lerp(Color("#a7c6d6"), reflection + core)
            var edge := clampf(1.0 - (-distance / 2.1), 0.0, 1.0)
            var edge_strength := 0.34 if state == "hover" else 0.18
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
