extends CanvasLayer
## Reusable, data-driven conversation view. Topics and pages carry only
## localization keys and optional objective IDs; no progression or door logic.
signal closed
signal objective_discovered(id: String, text_key: String)

const Controls = preload("res://gameplay/input_bindings.gd")
const Loc = preload("res://gameplay/localization.gd")
const MenuStyle = preload("res://ui/menu_style.gd")
const LuminousButton = preload("res://ui/luminous_button.gd")
const Catalog = preload("res://gameplay/dialogue_catalog.gd")

var active := false
var current_topic := "welcome"
var page_index := 0
var overlay: Control
var panel: PanelContainer
var title_label: Label
var context_label: Label
var response_label: Label
var page_label: Label
var choices_stack: VBoxContainer
var choices_scroll: ScrollContainer
var buttons: Dictionary = {}
var next_button: Button
var back_button: Button
var _conversation: Dictionary = Catalog.entrance()
var _discovered: Dictionary = {}
var _fade: Tween


func _ready() -> void:
    layer = 70
    overlay = Control.new()
    overlay.name = "CroupierOverlay"
    add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.012, 0.014, 0.017, 0.20)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(shade)

    # Left-aligned lower composition, leaving the NPC and most of the world
    # visible. Actual panel size is fitted to the logical viewport below.
    panel = PanelContainer.new()
    panel.name = "DialoguePanel"
    panel.add_theme_stylebox_override("panel", MenuStyle.panel())
    overlay.add_child(panel)
    var padding := MarginContainer.new()
    for edge in ["left","right","top","bottom"]:
        padding.add_theme_constant_override("margin_"+edge, 22)
    panel.add_child(padding)
    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 20)
    padding.add_child(columns)

    var speech := VBoxContainer.new()
    speech.name = "SpeechColumn"
    speech.custom_minimum_size = Vector2(400, 0)
    speech.add_theme_constant_override("separation", 10)
    columns.add_child(speech)
    context_label = _label("ConversationContext", 12, Color("#b3a797"))
    speech.add_child(context_label)
    title_label = _label("Speaker", 25, MenuStyle.GOLD)
    speech.add_child(title_label)
    var rule := ColorRect.new()
    rule.color = Color("#a78a55")
    rule.custom_minimum_size.y = 1
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    speech.add_child(rule)

    response_label = _label("Response", 20, MenuStyle.PALE)
    response_label.custom_minimum_size = Vector2(400, 120)
    response_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    response_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    response_label.set_meta("_independent_caption", true)
    speech.add_child(response_label)
    var navigation := HBoxContainer.new()
    navigation.add_theme_constant_override("separation", 8)
    speech.add_child(navigation)
    back_button = _button("PreviousPage", false)
    back_button.custom_minimum_size = Vector2(108, 42)
    back_button.pressed.connect(_previous_page)
    navigation.add_child(back_button)
    page_label = _label("PageIndicator", 12, Color("#b3a797"))
    page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    navigation.add_child(page_label)
    next_button = _button("NextPage", true)
    next_button.custom_minimum_size = Vector2(138, 42)
    next_button.pressed.connect(_next_page)
    navigation.add_child(next_button)

    var divider := VSeparator.new()
    columns.add_child(divider)
    var choices := VBoxContainer.new()
    choices.name = "ChoiceColumn"
    choices.custom_minimum_size.x = 280
    choices.add_theme_constant_override("separation", 8)
    columns.add_child(choices)
    var heading := _label("ChoiceHeading", 12, MenuStyle.GOLD)
    heading.text = Loc.t("dialogue.topics", self)
    choices.add_child(heading)
    choices_scroll = ScrollContainer.new()
    choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    choices_scroll.custom_minimum_size.y = 156
    choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    choices_scroll.follow_focus = true
    choices.add_child(choices_scroll)
    choices_stack = VBoxContainer.new()
    choices_stack.name = "TopicChoices"
    choices_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choices_stack.add_theme_constant_override("separation", 7)
    choices_scroll.add_child(choices_stack)
    var leave := _button("LeaveButton", false)
    leave.custom_minimum_size.y = 44
    leave.pressed.connect(close_conversation)
    choices.add_child(leave)
    buttons["leave"] = leave
    _build_topics()

    var settings := get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_settings_changed)
    overlay.resized.connect(_fit_panel)
    panel.minimum_size_changed.connect(func() -> void: _fit_panel.call_deferred())
    _refresh_language()
    _apply_readability()
    visible = false


func _label(node_name: String, font_size: int, color: Color) -> Label:
    var result := Label.new()
    result.name = node_name
    result.add_theme_font_size_override("font_size", font_size)
    result.add_theme_color_override("font_color", color)
    result.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return result


func _button(node_name: String, featured: bool) -> Button:
    var button := LuminousButton.new()
    button.name = node_name
    button.featured = featured
    button.custom_minimum_size.y = 46
    return button


func configure(conversation: Dictionary) -> bool:
    if active or not Catalog.valid(conversation):
        return false
    _conversation = conversation.duplicate(true)
    _discovered.clear()
    current_topic = str(_conversation.get("entry", "welcome"))
    page_index = 0
    if is_node_ready():
        _build_topics()
        _refresh_language()
    return true


func _build_topics() -> void:
    for child in choices_stack.get_children():
        choices_stack.remove_child(child)
        child.queue_free()
    var leave: Button = buttons.get("leave")
    buttons = {"leave": leave}
    for topic in _conversation.get("topics", []):
        var id := str(topic["id"])
        var button := _button(id.capitalize()+"Button", false)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_on_choice.bind(id))
        choices_stack.add_child(button)
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        buttons[id] = button


func _fit_panel() -> void:
    if not is_instance_valid(panel) or overlay.size.x <= 0.0 or overlay.size.y <= 0.0:
        return
    var natural := panel.get_combined_minimum_size()
    var margin := 24.0
    var factor := minf(1.0, minf(maxf(1.0,overlay.size.x-2.0*margin)/maxf(1.0,natural.x), maxf(1.0,overlay.size.y-2.0*margin)/maxf(1.0,natural.y)))
    panel.size = natural
    panel.pivot_offset = Vector2.ZERO
    panel.scale = Vector2.ONE*factor
    panel.position = Vector2(margin, maxf(margin, overlay.size.y-natural.y*factor-margin)).round()


func show_conversation() -> void:
    if active:
        return
    current_topic = str(_conversation.get("entry", "welcome"))
    page_index = 0
    active = true
    visible = true
    _show_page()
    _fit_panel()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if not next_button.disabled:
        next_button.grab_focus()
    else:
        _focus_topic()


func _focus_topic() -> void:
    for topic in _conversation.get("topics", []):
        var button := buttons.get(str(topic["id"])) as Button
        if button != null:
            button.grab_focus()
            return
    (buttons["leave"] as Button).grab_focus()


func close_conversation() -> void:
    if not active:
        return
    active = false
    if _fade != null:
        _fade.kill()
    panel.modulate.a = 1.0
    visible = false
    closed.emit()


func _on_choice(topic: String) -> void:
    if not active:
        return
    if topic == "leave":
        close_conversation()
        return
    if Catalog.pages(_conversation,topic).is_empty():
        return
    current_topic = topic
    page_index = 0
    _show_page()


func _next_page() -> void:
    if not active or page_index+1 >= Catalog.pages(_conversation,current_topic).size():
        return
    page_index += 1
    _show_page()
    if next_button.disabled:
        _focus_topic()


func _previous_page() -> void:
    if not active or page_index <= 0:
        return
    page_index -= 1
    _show_page()
    if back_button.disabled:
        next_button.grab_focus()


func _show_page() -> void:
    _refresh_language()
    var pages := Catalog.pages(_conversation,current_topic)
    var id := str(pages[page_index].get("objective",""))
    if not id.is_empty() and not _discovered.has(id):
        var key := Catalog.objective_key(_conversation,id)
        if not key.is_empty():
            _discovered[id] = true
            objective_discovered.emit(id,key)
    _animate_panel()


func _animate_panel() -> void:
    if _fade != null:
        _fade.kill()
    if bool(Controls.pref(self,"reduced_motion",false)) or bool(Controls.pref(self,"reduced_menu_motion",false)):
        panel.modulate.a = 1.0
        return
    panel.modulate.a = 0.78
    _fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _fade.tween_property(panel,"modulate:a",1.0,0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_settings_changed(key: String) -> void:
    if key == "language":
        _refresh_language()
    if key in ["caption_size","caption_background"]:
        _apply_readability()
    if key in ["reduced_motion","reduced_menu_motion"] and active:
        _animate_panel()
    if key in ["ui_text_size","ui_scale","caption_size","language"]:
        _fit_panel.call_deferred()


func _apply_readability() -> void:
    var scale: float = {"small": 0.85, "normal": 1.0, "large": 1.15, "very_large": 1.30}[Controls.pref(self, "caption_size", "normal")]
    response_label.add_theme_font_size_override("font_size", roundi(20 * scale))
    response_label.add_theme_constant_override("outline_size", 2 if float(Controls.pref(self,"caption_background",0.7))>0.5 else 0)
    response_label.add_theme_color_override("font_outline_color", Color("#111216"))


func _refresh_language() -> void:
    title_label.text = Loc.t(str(_conversation["speaker"]),self)
    context_label.text = Loc.t(str(_conversation["context"]),self)
    var heading := panel.find_child("ChoiceHeading",true,false) as Label
    if heading != null:
        heading.text = Loc.t("dialogue.topics",self)
    var pages := Catalog.pages(_conversation,current_topic)
    if pages.is_empty():
        return
    page_index = clampi(page_index,0,pages.size()-1)
    response_label.text = Loc.t(str(pages[page_index]["text"]),self)
    page_label.text = "%02d / %02d" % [page_index+1,pages.size()]
    next_button.text = Loc.t("dialogue.next",self)
    back_button.text = Loc.t("dialogue.back",self)
    next_button.disabled = page_index+1>=pages.size()
    back_button.disabled = page_index==0
    for topic in _conversation.get("topics",[]):
        var button := buttons.get(str(topic["id"])) as Button
        if button != null:
            button.text = Loc.t(str(topic["label"]),self)
            button.tooltip_text = button.text
            button.call("set_accent","gold",str(topic["id"])==current_topic)
    (buttons["leave"] as Button).text = Loc.t(str(_conversation.get("leave_label","croupier.option.leave")),self)
    _fit_panel.call_deferred()


func _input(event: InputEvent) -> void:
    if active and (Controls.pressed(event,"pause") or event.is_action_pressed("ui_cancel")):
        close_conversation()
        get_viewport().set_input_as_handled()
