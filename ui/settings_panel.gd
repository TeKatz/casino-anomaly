extends PanelContainer
const Loc = preload("res://gameplay/localization.gd")
## Reusable tabbed settings UI. Functions both while SceneTree is paused
## and in the normal main menu; changes apply and persist immediately.
signal back_pressed

const GOLD := Color("#dbad6b")
const PALE := Color("#f5e4ce")
const BACKGROUND := Color("#111924")
const CATEGORIES := ["settings.graphics", "settings.audio", "settings.controls", "settings.gameplay"]

var tab_row: HBoxContainer
var options_box: VBoxContainer
var tabs: Array[Button] = []
var selected_tab := 0
var settings_node: Variant = null
var title_label: Label
var footer_note: Label
var back_button: Button


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    settings_node = get_node_or_null("/root/GameSettings")
    custom_minimum_size = Vector2(720, 580)
    var panel_style := _style(BACKGROUND, GOLD, 1)
    panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
    panel_style.shadow_size = 18
    add_theme_stylebox_override("panel", panel_style)

    var margin := MarginContainer.new()
    for side in ["left", "right"]:
        margin.add_theme_constant_override("margin_" + side, 24)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 18)
    add_child(margin)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 14)
    margin.add_child(layout)

    title_label = Label.new()
    var title := title_label
    title.text = Loc.t("settings.title", self)
    title.add_theme_font_size_override("font_size", 29)
    title.add_theme_color_override("font_color", GOLD)
    layout.add_child(title)

    tab_row = HBoxContainer.new()
    tab_row.add_theme_constant_override("separation", 10)
    layout.add_child(tab_row)
    for i in range(CATEGORIES.size()):
        var tab := Button.new()
        tab.text = Loc.t(CATEGORIES[i], self)
        tab.custom_minimum_size = Vector2(126, 39)
        tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab.focus_mode = Control.FOCUS_NONE
        tab_row.add_child(tab)
        tabs.append(tab)
        tab.pressed.connect(_switch_tab.bind(i))
        tab.mouse_entered.connect(_tab_hover.bind(tab, true))
        tab.mouse_exited.connect(_tab_hover.bind(tab, false))

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    layout.add_child(scroll)
    options_box = VBoxContainer.new()
    options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    options_box.add_theme_constant_override("separation", 18)
    scroll.add_child(options_box)

    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 10)
    layout.add_child(footer)
    footer_note = Label.new()
    var note := footer_note
    note.text = Loc.t("settings.changes_saved", self)
    note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    note.add_theme_color_override("font_color", Color("#96a2ab"))
    footer.add_child(note)
    back_button = Button.new()
    var back := back_button
    back.text = Loc.t("settings.back", self)
    back.custom_minimum_size = Vector2(142, 44)
    back.add_theme_stylebox_override("normal", _style(Color("#483529"), GOLD, 1))
    back.pressed.connect(func() -> void: back_pressed.emit())
    footer.add_child(back)
    _switch_tab(0)
    if settings_node != null:
        settings_node.options_changed.connect(_on_setting_changed)


func _on_setting_changed(key: String) -> void:
    if key == "language":
        call_deferred("_refresh_language")


func _refresh_language() -> void:
    if not is_inside_tree():
        return
    title_label.text = Loc.t("settings.title", self)
    footer_note.text = Loc.t("settings.changes_saved", self)
    back_button.text = Loc.t("settings.back", self)
    for i in range(tabs.size()):
        tabs[i].text = Loc.t(CATEGORIES[i], self)
    _switch_tab(selected_tab)


func _style(bg: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border_color
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(7)
    style.content_margin_left = 9
    style.content_margin_top = 6
    style.content_margin_right = 9
    style.content_margin_bottom = 6
    return style


func _tab_hover(button: Button, entered: bool) -> void:
    if not is_instance_valid(button):
        return
    var chosen: bool = tabs.find(button) == selected_tab
    var glow: Color = Color(1.16, 1.07, 0.9) if entered else Color.WHITE
    if chosen and not entered:
        glow = Color("#ffe3ac")
    var tween := create_tween()
    tween.tween_property(button, "modulate", glow, 0.14)


func _switch_tab(index: int) -> void:
    selected_tab = index
    for i in range(tabs.size()):
        var chosen: bool = i == index
        var button := tabs[i]
        button.add_theme_stylebox_override("normal", _style(
            Color("#665036") if chosen else Color("#232c34"),
            Color("#f5c682") if chosen else Color("#45525c"),
            2 if chosen else 1
        ))
        button.add_theme_stylebox_override("hover", _style(
            Color("#796043") if chosen else Color("#34404a"), GOLD, 2
        ))
        button.add_theme_color_override("font_color", PALE if chosen else Color("#c4c6c6"))
        button.modulate = Color("#ffe3ac") if chosen else Color.WHITE

    for child in options_box.get_children():
        options_box.remove_child(child)
        child.queue_free()
    match index:
        0:
            _section(Loc.t("settings.display", self))
            _select(Loc.t("settings.window_mode", self), "window_mode", [
                [Loc.t("settings.windowed", self), "windowed"], [Loc.t("settings.borderless", self), "borderless"], [Loc.t("settings.fullscreen", self), "fullscreen"]
            ])
            _select(Loc.t("settings.resolution", self), "resolution", [
                ["1280 × 720", "1280x720"], ["1600 × 900", "1600x900"],
                ["1920 × 1080", "1920x1080"], ["2560 × 1440", "2560x1440"]
            ])
            _select(Loc.t("settings.fps_limit", self), "fps_limit", [
                [Loc.t("settings.unlimited", self), 0], ["30 FPS", 30], ["60 FPS", 60],
                ["90 FPS", 90], ["120 FPS", 120], ["144 FPS", 144], ["240 FPS", 240]
            ])
            _toggle("VSync", "vsync")
            _toggle(Loc.t("settings.taa", self), "taa")
            _toggle(Loc.t("settings.voxel_gi", self), "voxel_gi")
            if not ResourceLoader.exists("res://lighting/main_wing.res") \
                    or not ResourceLoader.exists("res://lighting/west_wing.res"):
                _section(Loc.t("settings.voxel_gi_unbaked", self))
            _slider(Loc.t("settings.render_scale", self), "render_scale", 0.5, 1.0, 0.05, "×")
        1:
            _section(Loc.t("settings.volume", self))
            _slider(Loc.t("settings.master", self), "master_volume", 0.0, 1.0, 0.05, "%")
            _slider(Loc.t("settings.music", self), "music_volume", 0.0, 1.0, 0.05, "%")
            _slider(Loc.t("settings.sfx", self), "sfx_volume", 0.0, 1.0, 0.05, "%")
            _slider(Loc.t("settings.ui", self), "ui_volume", 0.0, 1.0, 0.05, "%")
        2:
            _section(Loc.t("settings.mouse_movement", self))
            _slider(Loc.t("settings.mouse_sensitivity", self), "mouse_sensitivity", 0.25, 3.0, 0.05, "×")
            _toggle(Loc.t("settings.invert_y", self), "invert_y")
            _select(Loc.t("settings.sprint", self), "sprint_mode", [
                [Loc.t("settings.hold", self), "hold"], [Loc.t("settings.toggle", self), "toggle"]
            ])
        3:
            _section(Loc.t("settings.game_view", self))
            _slider(Loc.t("settings.fov", self), "fov", 60.0, 105.0, 1.0, "°")
            _toggle(Loc.t("settings.camera_motion", self), "camera_motion")
            _section(Loc.t("settings.language", self))
            _select(Loc.t("settings.language", self), "language", [
                ["English", "en"], ["Deutsch", "de"]
            ])


func _section(text: String) -> void:
    var title := Label.new()
    title.text = text
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", GOLD)
    options_box.add_child(title)


func _line(caption: String) -> HBoxContainer:
    var line := HBoxContainer.new()
    line.custom_minimum_size = Vector2(0, 40)
    line.add_theme_constant_override("separation", 16)
    options_box.add_child(line)
    var label := Label.new()
    label.text = caption
    label.custom_minimum_size = Vector2(300, 0)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_color_override("font_color", PALE)
    line.add_child(label)
    return line


func _select(caption: String, key: String, choices: Array) -> void:
    var line := _line(caption)
    var dropdown := OptionButton.new()
    dropdown.custom_minimum_size = Vector2(230, 36)
    for i in range(choices.size()):
        dropdown.add_item(str(choices[i][0]))
        if choices[i][1] == settings_node.get_option(key):
            dropdown.select(i)
    dropdown.item_selected.connect(func(index: int) -> void:
        settings_node.set_option(key, choices[index][1])
    )
    line.add_child(dropdown)


func _toggle(caption: String, key: String) -> void:
    var line := _line(caption)
    var checkbox := CheckButton.new()
    checkbox.button_pressed = bool(settings_node.get_option(key))
    checkbox.custom_minimum_size = Vector2(100, 36)
    checkbox.toggled.connect(func(enabled: bool) -> void:
        settings_node.set_option(key, enabled)
    )
    line.add_child(checkbox)


func _formatted(value: float, suffix: String) -> String:
    if suffix == "%":
        return "%d %%" % int(roundf(value * 100.0))
    if suffix == "°":
        return "%d°" % int(value)
    return "%.2f×" % value


func _slider(caption: String, key: String, low: float, high: float, step: float, suffix: String) -> void:
    var line := _line(caption)
    var slider := HSlider.new()
    slider.custom_minimum_size = Vector2(158, 32)
    slider.min_value = low
    slider.max_value = high
    slider.step = step
    slider.value = float(settings_node.get_option(key))
    line.add_child(slider)
    var output := Label.new()
    output.custom_minimum_size = Vector2(60, 0)
    output.text = _formatted(slider.value, suffix)
    output.add_theme_color_override("font_color", GOLD)
    line.add_child(output)
    slider.value_changed.connect(func(value: float) -> void:
        settings_node.set_option(key, value)
        output.text = _formatted(value, suffix)
    )
