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


func _ready() -> void:
    layer = 46
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
    card.offset_left = -344
    card.offset_right = -24
    card.offset_top = 24
    card.offset_bottom = 104
    var frame := MenuStyle.flat_surface(Color("#17181d",0.90),Color("#9d8050",0.75),8)
    frame.content_margin_left = 12
    frame.content_margin_right = 14
    frame.content_margin_top = 9
    frame.content_margin_bottom = 10
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
    stack.add_theme_constant_override("separation",4)
    row.add_child(stack)
    heading = Label.new()
    heading.name = "ObjectiveHeading"
    heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    heading.add_theme_font_size_override("font_size",12)
    heading.add_theme_color_override("font_color",MenuStyle.GOLD)
    stack.add_child(heading)
    message = Label.new()
    message.name = "ObjectiveText"
    message.mouse_filter = Control.MOUSE_FILTER_IGNORE
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message.add_theme_font_size_override("font_size",17)
    message.add_theme_color_override("font_color",MenuStyle.PALE)
    stack.add_child(message)
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
    _sync(true)


func clear_objective() -> void:
    objective_id = ""
    text_key = ""
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
    var width := minf(320.0,maxf(120.0,root.size.x-48.0))
    card.offset_left = -24.0-width
    card.offset_right = -24.0


func _reduced() -> bool:
    return bool(Controls.pref(self,"reduced_motion",false)) or bool(Controls.pref(self,"reduced_menu_motion",false))


func _sync(force_reveal: bool = false) -> void:
    var should_show := context_visible and not objective_id.is_empty() and not text_key.is_empty() and bool(Controls.pref(self,"hud_visible",true)) and bool(Controls.pref(self,"tutorial_hints",true)) and bool(Controls.pref(self,"interaction_hints",true))
    if should_show==card.visible and not (should_show and force_reveal):
        return
    if _motion != null:
        _motion.kill()
    card.visible = should_show
    card.modulate.a = 1.0
    accent.modulate.a = 1.0
    if not should_show or _reduced():
        return
    card.modulate.a = 0.0
    accent.modulate.a = 0.45
    _motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
    _motion.tween_property(card,"modulate:a",1.0,0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _motion.tween_property(accent,"modulate:a",1.0,0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_setting(key: String) -> void:
    if key=="language":
        _refresh_text()
    if key in ["hud_visible","interaction_hints","tutorial_hints"]:
        _sync()
    if key in ["reduced_motion","reduced_menu_motion"] and _reduced():
        if _motion != null:
            _motion.kill()
        card.modulate.a = 1.0
        accent.modulate.a = 1.0
    if key in ["ui_scale","ui_text_size","language"]:
        _fit_card()
