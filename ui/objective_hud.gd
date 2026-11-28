extends CanvasLayer
## Reusable, passive objective HUD. The owning scene controls the lifetime
## and contextual visibility. Objective IDs and localization keys are data.
const Controls = preload("res://gameplay/input_bindings.gd")
const Loc = preload("res://gameplay/localization.gd")
const MenuStyle = preload("res://ui/menu_style.gd")

var objective_id := ""
var text_key := ""
var root: Control
var card: PanelContainer
var heading: Label
var message: Label
var accent: ColorRect
var context_visible := false
var _motion: Tween
var _shine_motion: Tween
var shine: ColorRect
var _shine_material: ShaderMaterial
var _reveal_offset := 0.0
var _announced_id := ""
var _announced_key := ""

# One restrained, non-looping diagonal reflection. The content-area overlay
# is feathered on all sides and never accepts input or changes layout.
const SHINE_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    float center = mix(-0.4, 1.4, progress);
    float x = UV.x + (UV.y - 0.5) * 0.22;
    float distance_to_band = (x - center) / 0.085;
    float band = exp(-distance_to_band * distance_to_band);
    float edge = smoothstep(0.0, 0.06, UV.x) * (1.0 - smoothstep(0.94, 1.0, UV.x))
        * smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.88, 1.0, UV.y));
    COLOR = vec4(1.0, 0.84, 0.53, band * edge * 0.12 * COLOR.a);
}
"""


func _ready() -> void:
    layer = 46
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_process(false)
    root = Control.new()
    root.name = "Root"
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    card = PanelContainer.new()
    card.name = "ObjectiveCard"
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(card)
    card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    card.offset_left = -376
    card.offset_right = -24
    card.offset_top = 24
    card.offset_bottom = 112
    var frame := MenuStyle.flat_surface(Color("#17181d",0.95),Color("#b79a65",0.85),10)
    frame.content_margin_left = 15
    frame.content_margin_right = 16
    frame.content_margin_top = 12
    frame.content_margin_bottom = 13
    frame.shadow_color = Color(0.0,0.0,0.0,0.48)
    frame.shadow_size = 9
    frame.shadow_offset = Vector2(0,4)
    card.add_theme_stylebox_override("panel",frame)
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation",12)
    card.add_child(row)
    accent = ColorRect.new()
    accent.color = MenuStyle.GOLD
    accent.custom_minimum_size.x = 3
    accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(accent)
    var stack := VBoxContainer.new()
    stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stack.add_theme_constant_override("separation",7)
    row.add_child(stack)
    heading = Label.new()
    heading.name = "ObjectiveHeading"
    heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    heading.add_theme_font_size_override("font_size",12)
    heading.add_theme_color_override("font_color",MenuStyle.GOLD)
    stack.add_child(heading)
    var rule := ColorRect.new()
    rule.name = "ObjectiveRule"
    rule.color = Color("#a88b58",0.50)
    rule.custom_minimum_size.y = 1
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_child(rule)
    message = Label.new()
    message.name = "ObjectiveText"
    message.mouse_filter = Control.MOUSE_FILTER_IGNORE
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message.add_theme_font_size_override("font_size",17)
    message.add_theme_color_override("font_color",MenuStyle.PALE)
    stack.add_child(message)
    shine = ColorRect.new()
    shine.name = "ObjectiveShine"
    shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shine.z_index = 1
    var shader := Shader.new()
    shader.code = SHINE_SHADER
    _shine_material = ShaderMaterial.new()
    _shine_material.shader = shader
    shine.material = _shine_material
    card.add_child(shine)
    shine.hide()
    var settings := get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_setting)
    root.resized.connect(_fit_card)
    card.hide()
    _refresh_text()
    _fit_card()


func set_objective(id: String, localized_key: String) -> void:
    if objective_id==id and text_key==localized_key:
        return
    objective_id = id
    text_key = localized_key
    _refresh_text()
    set_process(not objective_id.is_empty())
    _sync(true)


func clear_objective() -> void:
    objective_id = ""
    text_key = ""
    _announced_id = ""
    _announced_key = ""
    set_process(false)
    _sync()


func set_context_visible(value: bool) -> void:
    if context_visible==value:
        return
    context_visible = value
    _sync()


func _refresh_text() -> void:
    heading.text = Loc.t("objective.heading",self)
    message.text = Loc.t(text_key,self) if not text_key.is_empty() else ""


func _fit_card() -> void:
    var width := minf(352.0,maxf(120.0,root.size.x-48.0))
    card.offset_left = -24.0-width
    card.offset_right = -24.0


func _reduced() -> bool:
    return bool(Controls.pref(self,"reduced_motion",false)) or bool(Controls.pref(self,"reduced_menu_motion",false))


func _process(_delta: float) -> void:
    # Paused world scripts cannot update contextual visibility themselves.
    _sync()


func _sync(force_reveal: bool = false) -> void:
    var loader := get_node_or_null("/root/SceneLoader")
    var loading := loader != null and bool(loader.get("active"))
    var should_show := context_visible and not get_tree().paused and not loading and not objective_id.is_empty() and not text_key.is_empty() and bool(Controls.pref(self,"hud_visible",true)) and bool(Controls.pref(self,"tutorial_hints",true)) and bool(Controls.pref(self,"interaction_hints",true))
    if should_show==card.visible and not (should_show and force_reveal):
        return
    _reset_motion()
    card.visible = should_show
    if not should_show:
        return
    var new_objective := _announced_id != objective_id or _announced_key != text_key
    _announced_id = objective_id
    _announced_key = text_key
    if _reduced():
        return
    card.modulate.a = 0.0
    accent.modulate.a = 0.40
    _set_reveal_offset(-12.0)
    _motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
    _motion.tween_property(card,"modulate:a",1.0,0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _motion.tween_method(_set_reveal_offset,-12.0,0.0,0.56).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _motion.tween_property(accent,"modulate:a",1.0,0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    # Announce once per objective, not on every pause or dialogue return.
    if new_objective:
        shine.show()
        _set_shine_progress(0.0)
        _shine_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _shine_motion.tween_method(_set_shine_progress,0.0,1.0,1.05).set_delay(0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        _shine_motion.tween_callback(shine.hide)


func _set_reveal_offset(value: float) -> void:
    _reveal_offset = value
    card.position.y = 24.0 + _reveal_offset


func _set_shine_progress(value: float) -> void:
    _shine_material.set_shader_parameter("progress",value)


func _reset_motion() -> void:
    if _motion != null:
        _motion.kill()
        _motion = null
    if _shine_motion != null:
        _shine_motion.kill()
        _shine_motion = null
    card.modulate.a = 1.0
    accent.modulate.a = 1.0
    _set_reveal_offset(0.0)
    shine.hide()


func _on_setting(key: String) -> void:
    if key=="language":
        _refresh_text()
    if key in ["hud_visible","interaction_hints","tutorial_hints"]:
        _sync()
    if key in ["reduced_motion","reduced_menu_motion"] and _reduced():
        _reset_motion()
    if key in ["ui_scale","ui_text_size","language"]:
        _fit_card()
