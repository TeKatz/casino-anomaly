extends Button
## Dimensional beveled controls with their own animated etched corners.
## Uses native Button input/focus handling, so mouse, keyboard and gamepad work.
@export var featured := false

const INK := Color("#111c2d")
const GOLD := Color("#edc991")
const TEXT := Color("#f4e9dc")
var highlight := 0.0
var _highlight_tween: Tween


func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_theme_font_size_override("font_size", 19 if featured else 16)
    add_theme_color_override("font_color", TEXT)
    add_theme_color_override("font_hover_color", Color("#ffffff"))
    add_theme_color_override("font_pressed_color", GOLD)
    add_theme_color_override("font_focus_color", TEXT)
    add_theme_color_override("font_disabled_color", Color("#697483"))
    add_theme_stylebox_override("normal", _surface(false, false))
    add_theme_stylebox_override("hover", _surface(true, false))
    add_theme_stylebox_override("pressed", _surface(true, true))
    add_theme_stylebox_override("focus", _focus_style())
    add_theme_stylebox_override("disabled", _disabled_style())
    mouse_entered.connect(_hover_changed.bind(true))
    mouse_exited.connect(_hover_changed.bind(false))
    focus_entered.connect(_hover_changed.bind(true))
    focus_exited.connect(_hover_changed.bind(false))
    pivot_offset = size * 0.5
    resized.connect(func() -> void: pivot_offset = size * 0.5)


func _surface(hovered: bool, pressed: bool) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = Color("#26344b") if hovered else (Color("#202a3c") if featured else INK)
    if pressed:
        s.bg_color = Color("#34445b")
    s.border_color = Color("#efcb98") if hovered else Color("#687081") if featured else Color("#37475b")
    s.border_width_top = 1
    s.border_width_left = 3 if featured else 2
    s.border_width_bottom = 2
    s.border_width_right = 1
    s.corner_radius_top_left = 3
    s.corner_radius_top_right = 13
    s.corner_radius_bottom_left = 13
    s.corner_radius_bottom_right = 3
    s.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
    s.shadow_size = 9 if hovered else 5
    s.content_margin_left = 18
    s.content_margin_right = 18
    return s


func _disabled_style() -> StyleBoxFlat:
    var s := _surface(false, false)
    s.bg_color = Color("#111923")
    s.border_color = Color("#26313d")
    s.shadow_size = 0
    return s


func _focus_style() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = Color.TRANSPARENT
    s.border_color = Color("#ecd4ac")
    s.set_border_width_all(1)
    s.set_corner_radius_all(6)
    s.expand_margin_left = 3
    s.expand_margin_right = 3
    s.expand_margin_top = 3
    s.expand_margin_bottom = 3
    return s


func _hover_changed(active: bool) -> void:
    if disabled:
        return
    if _highlight_tween != null and _highlight_tween.is_running():
        _highlight_tween.kill()
    _highlight_tween = create_tween().set_parallel(true)
    _highlight_tween.tween_method(_set_highlight, highlight, 1.0 if active else 0.0, 0.22).set_trans(Tween.TRANS_CUBIC)
    _highlight_tween.tween_property(self, "scale", Vector2(1.016, 1.016) if active else Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC)


func _set_highlight(value: float) -> void:
    highlight = value
    queue_redraw()


func _draw() -> void:
    var alpha := 0.30 + 0.60 * highlight
    if disabled:
        alpha = 0.08
    var color := Color(0.98, 0.76, 0.52, alpha)
    # Fine engraved corners sit outside the caption, not over it.
    draw_line(Vector2(13, 6), Vector2(35 + highlight * 17, 6), color, 1.5, true)
    draw_line(Vector2(size.x - 34 - highlight * 16, size.y - 6), Vector2(size.x - 12, size.y - 6), color, 1.5, true)
    var jewel := PackedVector2Array([
        Vector2(9, size.y * 0.5), Vector2(14, size.y * 0.5 - 5),
        Vector2(19, size.y * 0.5), Vector2(14, size.y * 0.5 + 5)
    ])
    draw_colored_polygon(jewel, Color(0.96, 0.65, 0.43, alpha))
