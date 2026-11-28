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
var previous_response: Label
var topic_label: Label
var topic_markers: Dictionary = {}
var page_label: Label
var choices_stack: VBoxContainer
var choices_scroll: ScrollContainer
var buttons: Dictionary = {}
var next_button: Button
var back_button: Button
var _conversation: Dictionary = Catalog.entrance()
var _discovered: Dictionary = {}
var _fade: Tween
var _page_motion: Tween
var _entrance_offset := 0.0


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

    # Center the dialogue in the lower third; keep the NPC visible above it.
    # Fit the authored panel to the logical viewport at any UI scale.
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

    topic_label = _label("ActiveTopic", 13, MenuStyle.GOLD)
    topic_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    speech.add_child(topic_label)
    response_label = _label("Response", 20, MenuStyle.PALE)
    response_label.custom_minimum_size = Vector2(400, 120)
    response_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    response_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    response_label.set_meta("_independent_caption", true)
    speech.add_child(response_label)
    # A passive outgoing text layer lets the new page update immediately
    # without flashing the window, changing hit targets or delaying input.
    previous_response = _label("OutgoingResponse", 20, MenuStyle.PALE)
    previous_response.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    previous_response.set_meta("_independent_caption", true)
    response_label.add_child(previous_response)
    previous_response.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    previous_response.hide()
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
    leave.set("symbol", "quit")
    leave.set_meta("_ui_sound", "back")
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
    topic_markers.clear()
    for topic in _conversation.get("topics", []):
        var id := str(topic["id"])
        var button := _button(id.capitalize()+"Button", false)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_on_choice.bind(id))
        choices_stack.add_child(button)
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        buttons[id] = button
        # Permanent selection rail, independent of hover and keyboard focus.
        var marker := ColorRect.new()
        marker.name = "SelectedTopic"
        marker.color = MenuStyle.GOLD
        marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
        button.add_child(marker)
        marker.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
        marker.offset_left = 8.0
        marker.offset_right = 11.0
        marker.offset_top = 10.0
        marker.offset_bottom = -10.0
        marker.hide()
        topic_markers[id] = marker


func _fit_panel() -> void:
    if not is_instance_valid(panel) or overlay.size.x <= 0.0 or overlay.size.y <= 0.0:
        return
    var natural := panel.get_combined_minimum_size()
    var margin := 24.0
    var factor := minf(1.0, minf(maxf(1.0,overlay.size.x-2.0*margin)/maxf(1.0,natural.x), maxf(1.0,overlay.size.y-2.0*margin)/maxf(1.0,natural.y)))
    panel.size = natural
    panel.pivot_offset = Vector2.ZERO
    panel.scale = Vector2.ONE*factor
    panel.position = Vector2((overlay.size.x-natural.x*factor)*0.5, maxf(margin, overlay.size.y-natural.y*factor-margin)).round() + Vector2(0.0, _entrance_offset)


func show_conversation() -> void:
    if active:
        return
    current_topic = str(_conversation.get("entry", "welcome"))
    page_index = 0
    active = true
    visible = true
    _show_page(false)
    _animate_open()
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
    _reset_entrance()
    _reset_page_motion()
    visible = false
    closed.emit()


func _on_choice(topic: String) -> void:
    if not active:
        return
    if topic == "leave":
        close_conversation()
        return
    if Catalog.pages(_conversation,topic).is_empty() or (current_topic == topic and page_index == 0):
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


func _show_page(animate: bool = true) -> void:
    var outgoing := response_label.text
    var outgoing_alpha := response_label.self_modulate.a
    # Rapid navigation continues from whichever text is actually visible.
    if previous_response.visible and previous_response.self_modulate.a > outgoing_alpha:
        outgoing = previous_response.text
        outgoing_alpha = previous_response.self_modulate.a
    _reset_page_motion()
    _refresh_language()
    var pages := Catalog.pages(_conversation,current_topic)
    var id := str(pages[page_index].get("objective",""))
    if not id.is_empty() and not _discovered.has(id):
        var key := Catalog.objective_key(_conversation,id)
        if not key.is_empty():
            _discovered[id] = true
            objective_discovered.emit(id,key)
    if animate and outgoing != response_label.text and not _reduced():
        _animate_response(outgoing,outgoing_alpha)


func _reduced() -> bool:
    return bool(Controls.pref(self,"reduced_motion",false)) or bool(Controls.pref(self,"reduced_menu_motion",false))


func _set_entrance_offset(value: float) -> void:
    panel.position.y += value - _entrance_offset
    _entrance_offset = value


func _reset_entrance() -> void:
    if _fade != null:
        _fade.kill()
        _fade = null
    overlay.modulate.a = 1.0
    panel.modulate.a = 1.0
    _set_entrance_offset(0.0)


func _animate_open() -> void:
    _reset_entrance()
    if _reduced():
        return
    overlay.modulate.a = 0.0
    _set_entrance_offset(14.0)
    _fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
    _fade.tween_property(overlay,"modulate:a",1.0,0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _fade.tween_method(_set_entrance_offset,14.0,0.0,0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _reset_page_motion() -> void:
    if _page_motion != null:
        _page_motion.kill()
        _page_motion = null
    response_label.self_modulate.a = 1.0
    previous_response.self_modulate.a = 0.0
    previous_response.hide()


func _animate_response(outgoing: String, outgoing_alpha: float) -> void:
    previous_response.text = outgoing
    previous_response.self_modulate.a = outgoing_alpha
    previous_response.show()
    response_label.self_modulate.a = 0.0
    _page_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _page_motion.tween_property(previous_response,"self_modulate:a",0.0,0.10).set_trans(Tween.TRANS_SINE)
    _page_motion.parallel().tween_property(response_label,"self_modulate:a",1.0,0.26).set_delay(0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _page_motion.tween_callback(previous_response.hide)


func _on_settings_changed(key: String) -> void:
    if key == "language":
        _reset_page_motion()
        _refresh_language()
    if key in ["caption_size","caption_background"]:
        _apply_readability()
    if key in ["reduced_motion","reduced_menu_motion"] and active and _reduced():
        _reset_entrance()
        _reset_page_motion()
    if key in ["ui_text_size","ui_scale","caption_size","language"]:
        _fit_panel.call_deferred()


func _apply_readability() -> void:
    var scale: float = {"small": 0.85, "normal": 1.0, "large": 1.15, "very_large": 1.30}[Controls.pref(self, "caption_size", "normal")]
    for label in [response_label, previous_response]:
        label.add_theme_font_size_override("font_size", roundi(20 * scale))
        label.add_theme_constant_override("outline_size", 2 if float(Controls.pref(self,"caption_background",0.7))>0.5 else 0)
        label.add_theme_color_override("font_outline_color", Color("#111216"))


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
    topic_label.text = Loc.t("dialogue.greeting",self)
    for topic in _conversation.get("topics",[]):
        var id := str(topic["id"])
        var button := buttons.get(id) as Button
        if button != null:
            button.text = Loc.t(str(topic["label"]),self)
            button.tooltip_text = button.text
            var selected := id == current_topic
            # Reapply cached skins only when the actual selection changes.
            if bool(button.get("featured")) != selected:
                button.set("featured",selected)
                # Change the skin only; do not reset accessibility colors,
                # focus, icon tint or click behavior on every page.
                for state in ["normal","hover","pressed","disabled"]:
                    button.add_theme_stylebox_override(state,MenuStyle.button_skin(state,selected,"gold"))
            var marker := topic_markers.get(id) as ColorRect
            if marker != null:
                marker.visible = selected
            if selected:
                topic_label.text = button.text
    (buttons["leave"] as Button).text = Loc.t(str(_conversation.get("leave_label","croupier.option.leave")),self)
    _fit_panel.call_deferred()


func _input(event: InputEvent) -> void:
    if active and (Controls.pressed(event,"pause") or event.is_action_pressed("ui_cancel")):
        close_conversation()
        get_viewport().set_input_as_handled()
