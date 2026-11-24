extends CanvasLayer
## Gaze- and distance-sensitive prompt for the tutorial's starting door.
## Nothing is attached above the 3D door; the cue belongs to the HUD.
const Controls = preload("res://gameplay/input_bindings.gd")
var key_label: Label
var root_control: Control
var panel: PanelContainer
var caption: Label
var _shown := false
var _fade: Tween


func _ready() -> void:
    layer = 45
    root_control = Control.new()
    root_control.name = "Root"
    root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root_control)

    panel = PanelContainer.new()
    panel.name = "Prompt"
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 1.0
    panel.anchor_bottom = 1.0
    panel.offset_left = -205.0
    panel.offset_right = 205.0
    panel.offset_top = -132.0
    panel.offset_bottom = -66.0
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var glass := StyleBoxFlat.new()
    glass.bg_color = Color("#101a2a", 0.94)
    glass.border_color = Color("#728da2", 0.66)
    glass.set_border_width_all(1)
    glass.set_corner_radius_all(15)
    glass.shadow_color = Color(0, 0, 0, 0.50)
    glass.shadow_size = 15
    panel.add_theme_stylebox_override("panel", glass)
    root_control.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 15)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 9)
    margin.add_theme_constant_override("margin_bottom", 9)
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(margin)

    var line := HBoxContainer.new()
    line.add_theme_constant_override("separation", 15)
    line.alignment = BoxContainer.ALIGNMENT_CENTER
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_child(line)

    var key := PanelContainer.new()
    key.name = "Key"
    key.custom_minimum_size = Vector2(42, 42)
    key.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var key_style := StyleBoxFlat.new()
    key_style.bg_color = Color("#344a60")
    key_style.border_color = Color("#a2bdce")
    key_style.set_border_width_all(1)
    key_style.set_corner_radius_all(9)
    key_style.shadow_color = Color("#07111d", 0.66)
    key_style.shadow_size = 4
    key.add_theme_stylebox_override("panel", key_style)
    line.add_child(key)

    key_label = Label.new()
    key_label.name = "KeyLabel"
    key_label.text = "E"
    key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    key_label.add_theme_font_size_override("font_size", 22)
    key_label.add_theme_color_override("font_color", Color("#f0f6f8"))
    key.mouse_filter = Control.MOUSE_FILTER_IGNORE
    key.add_child(key_label)

    caption = Label.new()
    caption.name = "Caption"
    caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    caption.add_theme_color_override("font_color", Color("#e9f0f4"))
    caption.add_theme_font_size_override("font_size", 18)
    caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    line.add_child(caption)

    panel.modulate.a = 0.0
    panel.visible = false
    var settings := get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.connect("options_changed", _binding_changed)
    _binding_changed("key_bindings")

func _binding_changed(key: String) -> void:
    if key in ["key_bindings", "input_device", "controller_enabled"]:
        key_label.text = Controls.hint(self)


func set_prompt_text(value: String) -> void:
    caption.text = value


func set_prompt_visible(show_prompt: bool) -> void:
    if show_prompt == _shown:
        return
    _shown = show_prompt
    if _fade != null and _fade.is_running():
        _fade.kill()
    if show_prompt:
        panel.visible = true
    _fade = create_tween()
    _fade.tween_property(panel, "modulate:a", 1.0 if show_prompt else 0.0, 0.19) \
            .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    if not show_prompt:
        _fade.tween_callback(func() -> void:
            if not _shown:
                panel.visible = false
        )
