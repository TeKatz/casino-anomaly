extends PanelContainer
const Loc = preload("res://gameplay/localization.gd")
const MenuStyle = preload("res://ui/menu_style.gd")
const LuminousButton = preload("res://ui/luminous_button.gd")
## Reusable tabbed settings UI. Functions both while SceneTree is paused
## and in the normal main menu; changes apply and persist immediately.
signal back_pressed

const GOLD := Color("#dbad6b")
const PALE := Color("#f5e4ce")
const BACKGROUND := Color("#111924")
const CATEGORIES := ["settings.graphics", "settings.audio", "settings.controls", "settings.gameplay", "settings.general"]

var tab_row: VBoxContainer
var scroll: ScrollContainer
var preview_dialog: ConfirmationDialog
var reset_dialog: ConfirmationDialog
var preset_select: OptionButton
var reset_button: Button
var reset_all_button: Button
var options_box: VBoxContainer
var tabs: Array[Button] = []
var selected_tab := 0
var options_tween: Tween
var settings_node: Variant = null
var title_label: Label
var footer_note: Label
var back_button: Button


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    settings_node = get_node_or_null("/root/GameSettings")
    custom_minimum_size = Vector2(850, 580)
    var panel_style := MenuStyle.panel()
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

    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 20)
    layout.add_child(body)
    tab_row = VBoxContainer.new()
    tab_row.add_theme_constant_override("separation", 9)
    tab_row.custom_minimum_size.x = 160
    body.add_child(tab_row)
    for i in range(CATEGORIES.size()):
        var tab := LuminousButton.new()
        tab.symbol = ["settings", "info", "profile", "stats", "settings"][i]
        MenuStyle.apply_button(tab)
        tab.text = _category(i)
        tab.custom_minimum_size = Vector2(126, 39)
        tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab.focus_mode = Control.FOCUS_ALL
        tab_row.add_child(tab)
        tabs.append(tab)
        tab.pressed.connect(_switch_tab.bind(i))
        tab.mouse_entered.connect(_tab_hover.bind(tab, true))
        tab.mouse_exited.connect(_tab_hover.bind(tab, false))

    scroll = ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(scroll)
    options_box = VBoxContainer.new()
    options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    options_box.add_theme_constant_override("separation", 18)
    scroll.add_child(options_box)

    reset_button = LuminousButton.new()
    MenuStyle.apply_button(reset_button)
    reset_button.text = _tr("Reset category", "Kategorie zurücksetzen")
    reset_button.custom_minimum_size.y = 42
    reset_button.pressed.connect(func() -> void: _request_reset(false))
    tab_row.add_child(reset_button)
    reset_all_button = LuminousButton.new()
    MenuStyle.apply_button(reset_all_button)
    reset_all_button.text = _tr("Reset all", "Alles zurücksetzen")
    reset_all_button.custom_minimum_size.y = 42
    reset_all_button.pressed.connect(func() -> void: _request_reset(true))
    tab_row.add_child(reset_all_button)
    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 10)
    layout.add_child(footer)
    footer_note = Label.new()
    var note := footer_note
    note.text = Loc.t("settings.changes_saved", self)
    note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    note.add_theme_color_override("font_color", Color("#96a2ab"))
    footer.add_child(note)
    back_button = LuminousButton.new()
    (back_button as LuminousButton).symbol = "back"
    var back := back_button
    back.text = Loc.t("settings.back", self)
    back.custom_minimum_size = Vector2(142, 44)
    back.add_theme_font_size_override("font_size", 16)
    back.pressed.connect(func() -> void:
        settings_node.cancel_display_preview()
        settings_node.save_options()
        back_pressed.emit()
    )
    footer.add_child(back)
    _switch_tab(0)
    if settings_node != null:
        settings_node.options_changed.connect(_on_setting_changed)
        settings_node.display_preview_changed.connect(_preview_changed)
    preview_dialog = ConfirmationDialog.new()
    preview_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(preview_dialog)
    preview_dialog.confirmed.connect(func() -> void: settings_node.confirm_display_preview())
    preview_dialog.canceled.connect(func() -> void: settings_node.cancel_display_preview())
    reset_dialog = ConfirmationDialog.new()
    reset_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(reset_dialog)
    reset_dialog.confirmed.connect(_confirm_reset)
    visibility_changed.connect(_on_visibility)
    set_process(false)


func _on_setting_changed(key: String) -> void:
    if key == "language":
        call_deferred("_refresh_language")
    elif key == "graphics_preset" and is_instance_valid(preset_select):
        for index in range(preset_select.item_count):
            if preset_select.get_item_metadata(index) == settings_node.get_option(key):
                preset_select.select(index)
                break


func _refresh_language() -> void:
    if not is_inside_tree():
        return
    title_label.text = Loc.t("settings.title", self)
    footer_note.text = Loc.t("settings.changes_saved", self)
    back_button.text = Loc.t("settings.back", self)
    for i in range(tabs.size()):
        tabs[i].text = _category(i)
    reset_button.text = _tr("Reset category", "Kategorie zurücksetzen")
    reset_all_button.text = _tr("Reset all", "Alles zurücksetzen")
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
    preset_select = null
    if scroll != null:
        scroll.scroll_vertical = 0
    for i in range(tabs.size()):
        var chosen: bool = i == index
        var button := tabs[i]
        MenuStyle.apply_button(button, chosen)
        button.add_theme_color_override("font_color", PALE if chosen else Color("#c4c6c6"))
        button.modulate = Color("#ffe3ac") if chosen else Color.WHITE

    for child in options_box.get_children():
        options_box.remove_child(child)
        child.queue_free()
    match index:
        0:
            _graphics()
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
        4:
            _section(Loc.t("settings.language", self))
            _select(Loc.t("settings.language", self), "language", [
                ["English", "en"], ["Deutsch", "de"]
            ])

    if options_tween != null and options_tween.is_running():
        options_tween.kill()
    options_box.modulate.a = 0.0
    options_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    options_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    options_tween.tween_property(options_box, "modulate:a", 1.0, 0.19)


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
    label.custom_minimum_size = Vector2(210, 0)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_color_override("font_color", PALE)
    line.add_child(label)
    return line


func _select(caption: String, key: String, choices: Array, description: String = "") -> void:
    var line := _line(caption)
    var dropdown := OptionButton.new()
    dropdown.custom_minimum_size = Vector2(215, 36)
    dropdown.tooltip_text = description
    line.get_child(0).tooltip_text = description
    if key == "graphics_preset":
        preset_select = dropdown
    MenuStyle.apply_dropdown(dropdown)
    for i in range(choices.size()):
        dropdown.add_item(str(choices[i][0]))
        dropdown.set_item_metadata(i, choices[i][1])
        if choices[i][1] == settings_node.get_option(key):
            dropdown.select(i)
    dropdown.item_selected.connect(func(index: int) -> void:
        if key in ["window_mode", "resolution", "monitor"]:
            settings_node.preview_display(key, choices[index][1])
        else:
            settings_node.set_option(key, choices[index][1])
        if key == "graphics_preset":
            call_deferred("_switch_tab", selected_tab)
    )
    line.add_child(dropdown)


func _toggle(caption: String, key: String, description: String = "") -> void:
    var line := _line(caption)
    var checkbox := CheckButton.new()
    checkbox.button_pressed = bool(settings_node.get_option(key))
    checkbox.custom_minimum_size = Vector2(100, 36)
    checkbox.tooltip_text = description
    line.get_child(0).tooltip_text = description
    checkbox.add_theme_color_override("font_color", PALE)
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


func _slider(caption: String, key: String, low: float, high: float, step: float, suffix: String, description: String = "") -> void:
    var line := _line(caption)
    var slider := HSlider.new()
    slider.custom_minimum_size = Vector2(146, 32)
    slider.tooltip_text = description
    line.get_child(0).tooltip_text = description
    var track := StyleBoxFlat.new()
    track.bg_color = Color("#0c1623")
    track.border_color = Color("#607688")
    track.set_border_width_all(1)
    track.set_corner_radius_all(5)
    slider.add_theme_stylebox_override("slider", track)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color("#96775f")
    fill.set_corner_radius_all(5)
    slider.add_theme_stylebox_override("grabber_area", fill)
    slider.add_theme_stylebox_override("grabber_area_highlight", fill)
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


var reset_everything := false

func _tr(en: String, de: String) -> String:
    return de if settings_node != null and str(settings_node.get_option("language")) == "de" else en

func _category(index: int) -> String:
    return _tr("General", "Allgemein") if index == 4 else Loc.t(CATEGORIES[index], self)

func _request_reset(all_settings: bool) -> void:
    reset_everything = all_settings
    reset_dialog.title = _tr("Restore defaults", "Standardwerte")
    reset_dialog.dialog_text = _tr("Restore the selected settings to their defaults? Save games are unaffected.", "Ausgewählte Einstellungen zurücksetzen? Spielstände bleiben erhalten.")
    reset_dialog.popup_centered()

func _confirm_reset() -> void:
    if reset_everything:
        settings_node.reset_all()
    else:
        settings_node.reset_category(selected_tab)
    _refresh_language()

func _on_visibility() -> void:
    if not is_visible_in_tree() and settings_node != null:
        settings_node.cancel_display_preview()
        settings_node.save_options()

func _preview_changed(active: bool) -> void:
    if preview_dialog == null or not is_visible_in_tree():
        return
    if active:
        preview_dialog.title = _tr("Keep display settings?", "Anzeigeeinstellungen behalten?")
        preview_dialog.get_ok_button().text = _tr("Keep", "Behalten")
        preview_dialog.get_cancel_button().text = _tr("Revert", "Zurücksetzen")
        set_process(true)
        _process(0.0)
        preview_dialog.popup_centered()
    else:
        preview_dialog.hide()
        set_process(false)
        call_deferred("_switch_tab", selected_tab)

func _process(_delta: float) -> void:
    if preview_dialog != null:
        preview_dialog.dialog_text = _tr("Reverting in %d seconds.", "Zurücksetzen in %d Sekunden.") % settings_node.display_preview_seconds()

func _quality_choices(allow_off: bool = true, ultra: bool = false) -> Array:
    var choices := [[_tr("Original", "Original"), "original"]]
    if allow_off:
        choices.append([_tr("Off", "Aus"), "off"])
    choices.append_array([[_tr("Low", "Niedrig"), "low"], [_tr("Medium", "Mittel"), "medium"], [_tr("High", "Hoch"), "high"]])
    if ultra:
        choices.append(["Ultra", "ultra"])
    return choices

func _fps_choices(menu_only: bool = false) -> Array:
    var choices := []
    if menu_only:
        choices.append([_tr("Same as game", "Wie im Spiel"), -1])
    choices.append([Loc.t("settings.unlimited", self), 0])
    for fps in ([30, 60, 120, 144] if menu_only else [30, 60, 75, 90, 120, 144, 165, 180, 240, 360]):
        choices.append(["%d FPS" % fps, fps])
    return choices

func _graphics() -> void:
    _section(Loc.t("settings.display", self))
    _select(Loc.t("settings.window_mode", self), "window_mode", [
        [Loc.t("settings.windowed", self), "windowed"], [Loc.t("settings.borderless", self), "borderless"], [Loc.t("settings.fullscreen", self), "fullscreen"]])
    var monitors := [[_tr("Current monitor", "Aktueller Monitor"), -1]]
    if DisplayServer.get_name() != "headless":
        for index in range(DisplayServer.get_screen_count()):
            var dim := DisplayServer.screen_get_size(index)
            monitors.append(["%d · %d × %d" % [index + 1, dim.x, dim.y], index])
    _select(_tr("Monitor", "Monitor"), "monitor", monitors)
    var resolutions := []
    for value in settings_node.available_resolutions():
        resolutions.append([str(value).replace("x", " × "), value])
    _select(Loc.t("settings.resolution", self), "resolution", resolutions)
    _select(Loc.t("settings.fps_limit", self), "fps_limit", _fps_choices())
    _select("VSync", "vsync_mode", [[_tr("Off", "Aus"), "off"], [_tr("On", "Ein"), "on"], ["Adaptive", "adaptive"], ["Mailbox", "mailbox"]], _tr("Adaptive and Mailbox depend on display/driver support.", "Adaptiv und Mailbox hängen von Anzeige und Treiber ab."))
    _section(_tr("Graphics quality", "Grafikqualität"))
    _select(_tr("Preset", "Voreinstellung"), "graphics_preset", [[_tr("Custom", "Benutzerdefiniert"), "custom"], [_tr("Low", "Niedrig"), "low"], [_tr("Medium", "Mittel"), "medium"], [_tr("High", "Hoch"), "high"], ["Ultra", "ultra"]])
    _select(_tr("Anti-aliasing", "Kantenglättung"), "aa_mode", [[_tr("Off", "Aus"), "off"], ["FXAA", "fxaa"], ["TAA", "taa"], ["MSAA 2×", "msaa2"], ["MSAA 4×", "msaa4"], ["MSAA 8×", "msaa8"]], _tr("FSR 2 uses its own temporal AA instead.", "FSR 2 verwendet seine eigene zeitliche Kantenglättung."))
    _select("Upscaling", "upscaling", [["Bilinear", "bilinear"], ["FSR 1.0", "fsr1"], ["FSR 2.2", "fsr2"]], _tr("FSR improves scaled images; 100% is native resolution.", "FSR verbessert skalierte Bilder; 100 % entspricht nativer Auflösung."))
    _slider(Loc.t("settings.render_scale", self), "render_scale", 0.5, 1.0, 0.05, "%", _tr("Lower internal resolution improves GPU performance.", "Niedrigere interne Auflösung entlastet die GPU."))
    _select(_tr("Anisotropic filtering", "Anisotrope Filterung"), "anisotropy", [[_tr("Off", "Aus"), 0], ["2×", 2], ["4×", 4], ["8×", 8], ["16×", 16]], _tr("Sharpness of surfaces at oblique angles.", "Schärfe von Oberflächen in flachen Blickwinkeln."))
    _select(_tr("Shadow quality", "Schattenqualität"), "shadow_quality", _quality_choices(true, true), _tr("Changes the shadow atlas resolution; high settings cost GPU memory.", "Ändert die Schattenatlas-Auflösung; hohe Werte benötigen mehr GPU-Speicher."))
    _select(_tr("Shadow distance", "Schattenreichweite"), "shadow_distance", _quality_choices(false), _tr("Distant lights stop casting shadows sooner at low settings.", "Bei niedrigen Werten enden entfernte Schatten früher."))
    _section(_tr("Lighting and effects", "Beleuchtung und Effekte"))
    _toggle(Loc.t("settings.voxel_gi", self), "voxel_gi")
    if not ResourceLoader.exists("res://lighting/main_wing.res") or not ResourceLoader.exists("res://lighting/west_wing.res"):
        _section(Loc.t("settings.voxel_gi_unbaked", self))
    _select(_tr("Volumetric fog", "Volumetrischer Nebel"), "fog_quality", _quality_choices(), _tr("Controls fog buffer resolution in scenes that use volumetric fog.", "Steuert die Nebelauflösung in Szenen mit volumetrischem Nebel."))
    _select(_tr("Reflections", "Reflexionen"), "reflection_quality", [[_tr("Original", "Original"), "original"], [_tr("Off", "Aus"), "off"], [_tr("Low", "Niedrig"), "low"], [_tr("High", "Hoch"), "high"]], _tr("Low skips the west-wing probe; Off disables captures.", "Niedrig überspringt die Westflügel-Probe; Aus deaktiviert Aufnahmen."))
    _select("SSAO", "ssao_quality", _quality_choices(), _tr("Ambient occlusion adds contact shading where authored.", "Umgebungsverdeckung ergänzt Kontaktschatten, wo vorgesehen."))
    _toggle("SSIL", "ssil", _tr("Screen-space indirect lighting where authored.", "Indirekte Bildschirmbeleuchtung, wo vorgesehen."))
    _toggle("Bloom / Glow", "bloom")
    _slider(_tr("Bloom strength", "Bloom-Stärke"), "bloom_strength", 0.0, 1.5, 0.05, "%")
    _slider(_tr("Brightness", "Helligkeit"), "brightness", 0.7, 1.3, 0.05, "%")
    _slider(Loc.t("settings.image_contrast", self), "image_contrast", 0.70, 1.05, 0.05, "×")
    _slider(_tr("Saturation", "Farbsättigung"), "saturation", 0.0, 1.5, 0.05, "%")
    _select(_tr("Ambient particles", "Umgebungspartikel"), "particle_quality", _quality_choices())
    _section(_tr("Performance", "Performance"))
    _toggle(_tr("FPS counter", "FPS-Anzeige"), "fps_display")
    _toggle(_tr("Performance overlay", "Performance-Overlay"), "performance_overlay", _tr("Shows worst frame interval, draw calls and rendered objects (not GPU time).", "Zeigt größtes Frame-Intervall, Draw Calls und gerenderte Objekte (keine GPU-Zeit)."))
    _section(_tr("Main menu", "Hauptmenü"))
    _select(_tr("Background", "Hintergrund"), "menu_background", [[_tr("Live 3D", "Live-3D"), "live"], [_tr("Still frame", "Standbild"), "still"], [_tr("Abstract", "Abstrakt"), "abstract"]])
    _slider(_tr("Menu resolution", "Menü-Renderauflösung"), "menu_render_scale", 0.5, 1.0, 0.05, "%")
    _select(_tr("Menu FPS limit", "Menü-FPS-Limit"), "menu_fps_limit", _fps_choices(true))
    _toggle(_tr("Panorama motion", "Panoramabewegung"), "menu_camera_motion")
    _slider(_tr("Panorama speed", "Panoramageschwindigkeit"), "menu_camera_speed", 0.25, 1.5, 0.05, "%")
    _slider(_tr("Background dimming", "Hintergrundabdunklung"), "menu_darkness", 0.0, 1.5, 0.05, "%")
