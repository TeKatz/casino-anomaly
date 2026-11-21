extends RefCounted
## Shared secondary interface vocabulary: dimensional borders, recessed
## surfaces, differentiated hover and focus states. No external image assets.
const GOLD := Color("#e6bb81")
const PALE := Color("#f5e9dc")


static func surface(active: bool = false, hovered: bool = false) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = Color("#354457") if hovered else Color("#29384c") if active else Color("#182637")
    box.border_color = Color("#f0d2a1") if hovered else GOLD if active else Color("#566b7b")
    box.border_width_left = 3 if active else 2
    box.border_width_right = 1
    box.border_width_top = 1
    box.border_width_bottom = 2
    box.corner_radius_top_left = 3
    box.corner_radius_top_right = 12
    box.corner_radius_bottom_right = 3
    box.corner_radius_bottom_left = 12
    box.shadow_color = Color(0, 0, 0, 0.42)
    box.shadow_size = 6 if hovered else 3
    box.content_margin_left = 12
    box.content_margin_right = 12
    box.content_margin_top = 7
    box.content_margin_bottom = 7
    return box


static func apply_button(button: Button, active: bool = false) -> void:
    button.focus_mode = Control.FOCUS_ALL
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_stylebox_override("normal", surface(active))
    button.add_theme_stylebox_override("hover", surface(active, true))
    button.add_theme_stylebox_override("pressed", surface(true, true))
    var focus := StyleBoxFlat.new()
    focus.bg_color = Color.TRANSPARENT
    focus.border_color = GOLD
    focus.set_border_width_all(1)
    focus.set_corner_radius_all(8)
    focus.set_expand_margin_all(2)
    button.add_theme_stylebox_override("focus", focus)
    button.add_theme_color_override("font_color", PALE)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", GOLD)
    button.add_theme_color_override("font_disabled_color", Color("#72808b"))


static func apply_dropdown(button: OptionButton) -> void:
    apply_button(button)


static func panel() -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = Color("#101c2b")
    box.border_color = Color("#927a70")
    box.set_border_width_all(1)
    box.border_width_left = 3
    box.corner_radius_top_left = 4
    box.corner_radius_top_right = 18
    box.corner_radius_bottom_left = 18
    box.corner_radius_bottom_right = 4
    box.shadow_color = Color(0, 0, 0, 0.65)
    box.shadow_size = 24
    return box
