extends CanvasLayer
## Compact, optional bilingual conversation. No save schema or game rules.
signal closed

const Controls = preload("res://gameplay/input_bindings.gd")
const Loc = preload("res://gameplay/localization.gd")
const MenuStyle = preload("res://ui/menu_style.gd")
const LuminousButton = preload("res://ui/luminous_button.gd")
const GOLD := Color("#d6b176")

var active := false
var current_topic := "welcome"
var overlay: Control
var title_label: Label
var response_label: Label
var buttons: Dictionary = {}


func _ready() -> void:
    layer = 70
    overlay = Control.new()
    overlay.name = "CroupierOverlay"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.012, 0.014, 0.017, 0.40)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(shade)

    var panel := PanelContainer.new()
    panel.name = "DialoguePanel"
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 1.0
    panel.anchor_bottom = 1.0
    panel.offset_left = -380.0
    panel.offset_right = 380.0
    panel.offset_top = -283.0
    panel.offset_bottom = -24.0
    panel.add_theme_stylebox_override("panel", MenuStyle.panel())
    overlay.add_child(panel)

    var padding := MarginContainer.new()
    padding.add_theme_constant_override("margin_left", 22)
    padding.add_theme_constant_override("margin_right", 22)
    padding.add_theme_constant_override("margin_top", 16)
    padding.add_theme_constant_override("margin_bottom", 16)
    panel.add_child(padding)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 9)
    padding.add_child(stack)

    title_label = Label.new()
    title_label.add_theme_color_override("font_color", GOLD)
    title_label.add_theme_font_size_override("font_size", 23)
    stack.add_child(title_label)

    response_label = Label.new()
    response_label.name = "Response"
    response_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    response_label.custom_minimum_size = Vector2(0, 65)
    response_label.add_theme_font_size_override("font_size", 18)
    response_label.add_theme_color_override("font_color", Color("#f1e9da"))
    stack.add_child(response_label)

    var choices := GridContainer.new()
    choices.columns = 2
    choices.add_theme_constant_override("h_separation", 10)
    choices.add_theme_constant_override("v_separation", 8)
    stack.add_child(choices)
    for topic in ["rules", "anomalies", "casino", "leave"]:
        var button := LuminousButton.new()
        button.name = topic.capitalize() + "Button"
        button.custom_minimum_size = Vector2(338, 48)
        button.pressed.connect(_on_choice.bind(topic))
        choices.add_child(button)
        buttons[topic] = button

    var settings = get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_settings_changed)
    _refresh_language()
    visible = false


func show_conversation() -> void:
    if active:
        return
    current_topic = "welcome"
    active = true
    _refresh_language()
    visible = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    (buttons["rules"] as Button).grab_focus()


func close_conversation() -> void:
    if not active:
        return
    active = false
    visible = false
    closed.emit()


func _on_choice(topic: String) -> void:
    if topic == "leave":
        close_conversation()
        return
    current_topic = topic
    _refresh_language()


func _on_settings_changed(key: String) -> void:
    if key == "language":
        _refresh_language()


func _refresh_language() -> void:
    title_label.text = Loc.t("croupier.name", self)
    response_label.text = Loc.t("croupier." + current_topic, self)
    for topic in buttons:
        (buttons[topic] as Button).text = Loc.t("croupier.option." + str(topic), self)


func _input(event: InputEvent) -> void:
    if active and (Controls.pressed(event, "pause") or event.is_action_pressed("ui_cancel")):
        close_conversation()
        get_viewport().set_input_as_handled()
