extends RefCounted
## Premium symmetrical nine-slice skins shared by main, pause, dialogue and
## settings. Every face has the same rounded silhouette: NO left protrusions.
## Gold is the default; new game and quit use dedicated green/red outlines.
const GOLD := Color("#dabd84")
const GREEN := Color("#75c899")
const RED := Color("#df8490")
const AMBER := Color("#f2ae70")
const PALE := Color("#f5e9dc")
const KENNEY_FACE := """<svg xmlns="http://www.w3.org/2000/svg" width="192" height="64" viewBox="0 0 192 64"><defs><linearGradient id="surface" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0" stop-color="#TOP"/><stop offset="1" stop-color="#BOTTOM"/></linearGradient></defs><rect x="0" y="0" width="192" height="64" rx="6" fill="#EDGE"/><rect x="2" y="2" width="188" height="60" rx="4" fill="#RIM"/><rect x="4" y="4" width="184" height="56" rx="2" fill="url(#surface)"/></svg>"""
const KenneyIcons = preload("res://ui/kenney_icons.gd")
static var _skin_cache: Dictionary = {}


static func accent_color(accent: String) -> Color:
    match accent:
        "green":
            return GREEN
        "red":
            return RED
        "amber":
            return AMBER
        _:
            return GOLD


static func button_skin(state: String, featured: bool = false, accent: String = "gold") -> StyleBoxTexture:
    var key := "%s_%s_%s" % [state, accent, "featured" if featured else "standard"]
    if _skin_cache.has(key):
        return _skin_cache[key] as StyleBoxTexture

    var top := Color("#303137")
    var bottom := Color("#1b1c21")
    var rim := accent_color(accent).darkened(0.20)
    match state:
        "hover":
            top = Color("#45413a")
            bottom = Color("#29272a")
            rim = accent_color(accent).lightened(0.22)
        "pressed":
            top = Color("#191a1e")
            bottom = Color("#101115")
        "disabled":
            top = Color("#222328")
            bottom = Color("#18191d")
            rim = Color("#55565d")
    if featured and state == "normal":
        top = Color("#423a2e")
        bottom = Color("#242326")
        rim = accent_color(accent)
    elif featured and state == "hover":
        top = Color("#514738")
        bottom = Color("#302b27")
    # Geometry adapted from Kenney UI Pack 2.0 (CC0). Rasterize each palette
    # variant once; keep the existing symmetric nine-slice and compact sizing.
    var svg := KENNEY_FACE.replace("RIM", rim.to_html(false)).replace("TOP", top.to_html(false)).replace("BOTTOM", bottom.to_html(false)).replace("EDGE", rim.darkened(0.40).to_html(false))
    var image := Image.new()
    var result := image.load_svg_from_buffer(svg.to_utf8_buffer())
    if result != OK:
        image = Image.create_empty(192, 64, false, Image.FORMAT_RGBA8)
        image.fill(top)
    var style := StyleBoxTexture.new()
    style.texture = ImageTexture.create_from_image(image)
    # Both vertical caps must fit inside the smallest 36px settings dropdown.
    # The previous 26+26px caps could not fit in 36–43px controls and
    # Godot visibly sliced off their lower halves. Equal caps also avoid
    # asymmetrical side nubs. See settings_pause_qa and menu_visual_qa.
    style.texture_margin_left = 22.0
    style.texture_margin_right = 22.0
    style.texture_margin_top = 15.0
    style.texture_margin_bottom = 15.0
    style.content_margin_left = 23.0
    style.content_margin_right = 23.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    _skin_cache[key] = style
    return style


static func keyboard_focus_skin() -> StyleBoxFlat:
    var focus := StyleBoxFlat.new()
    focus.bg_color = Color.TRANSPARENT
    focus.border_color = Color("#f0d9a0", 0.96)
    focus.set_border_width_all(2)
    focus.set_corner_radius_all(6)
    return focus


static func surface(active: bool = false, hovered: bool = false) -> StyleBoxTexture:
    return button_skin("hover" if hovered else "normal", active)


static func apply_button(button: Button, active: bool = false, accent: String = "gold") -> void:
    button.focus_mode = Control.FOCUS_ALL
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.set_meta("_premium_accent", accent)
    button.add_theme_stylebox_override("normal", button_skin("normal", active, accent))
    button.add_theme_stylebox_override("hover", button_skin("hover", active, accent))
    button.add_theme_stylebox_override("pressed", button_skin("pressed", active, accent))
    button.add_theme_stylebox_override("disabled", button_skin("disabled", active, accent))
    # LuminousButton distinguishes mouse and navigation focus. Plain controls
    # must still expose a focus ring for keyboard and controller users.
    if button.has_method("_refresh_focus"):
        button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        if button.is_node_ready():
            button.call_deferred("_refresh_focus")
    else:
        button.add_theme_stylebox_override("focus", keyboard_focus_skin())
    button.add_theme_color_override("font_color", PALE)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color("#f0d9a0"))
    button.add_theme_color_override("font_disabled_color", Color("#929198"))
    button.add_theme_color_override("icon_normal_color", accent_color(accent))
    button.add_theme_color_override("icon_hover_color", Color("#f6f6f2"))
    button.add_theme_color_override("icon_pressed_color", accent_color(accent).lightened(0.18))
    button.add_theme_color_override("icon_disabled_color", Color("#79848c"))
    attach_sound(button)


static func play_sound(event: String) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    if tree == null:
        return
    var sound := tree.root.get_node_or_null("UISfx")
    if sound != null:
        sound.call("play_event", event)


static func attach_sound(button: BaseButton, event: String = "") -> void:
    if not event.is_empty():
        button.set_meta("_ui_sound", event)
    if button.has_meta("_ui_click_attached"):
        return
    button.set_meta("_ui_click_attached", true)
    button.pressed.connect(func() -> void:
        var action := str(button.get_meta("_ui_sound", "navigation"))
        if action != "silent":
            play_sound(action)
    )


static func apply_dropdown(button: OptionButton) -> void:
    apply_button(button)
    # Popup opening, not item selection or programmatic setup.
    attach_sound(button, "silent")
    # Godot defaults to only 4px, putting the icon against the border.
    button.add_theme_constant_override("arrow_margin", 23)
    button.add_theme_icon_override("arrow", KenneyIcons.texture("arrow"))
    button.add_theme_stylebox_override("focus", keyboard_focus_skin())
    button.add_theme_constant_override("h_separation", 12)
    button.add_theme_color_override("font_color", PALE)
    var popup := button.get_popup()
    if popup != null:
        if not popup.has_meta("_ui_dropdown_sound"):
            popup.set_meta("_ui_dropdown_sound", true)
            popup.about_to_popup.connect(func() -> void: play_sound("dropdown"))
        popup.add_theme_stylebox_override("panel", panel())
        var selected := StyleBoxFlat.new()
        selected.bg_color = Color("#40372b")
        selected.border_color = GOLD
        selected.set_border_width_all(1)
        selected.set_corner_radius_all(7)
        popup.add_theme_stylebox_override("hover", selected)
        popup.add_theme_color_override("font_color", PALE)
        popup.add_theme_color_override("font_hover_color", Color.WHITE)


static func panel() -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = Color("#17181d")
    box.border_color = Color("#9d8050", 0.92)
    box.set_border_width_all(2)
    box.set_corner_radius_all(12)
    box.corner_detail = 12
    box.shadow_color = Color(0, 0, 0, 0.78)
    box.shadow_size = 32
    box.shadow_offset = Vector2(0, 9)
    return box


static func flat_surface(bg: Color, edge: Color, radius: int = 5, border: int = 1) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = edge
    style.set_border_width_all(border)
    style.set_corner_radius_all(radius)
    return style


static func apply_toggle(toggle: CheckButton) -> void:
    toggle.add_theme_icon_override("checked", KenneyIcons.texture("check_on"))
    toggle.add_theme_icon_override("unchecked", KenneyIcons.texture("check_off"))
    toggle.add_theme_icon_override("checked_disabled", KenneyIcons.texture("check_on_disabled"))
    toggle.add_theme_icon_override("unchecked_disabled", KenneyIcons.texture("check_off_disabled"))
    toggle.add_theme_stylebox_override("focus", keyboard_focus_skin())
    toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    attach_sound(toggle)


static func apply_slider(slider: HSlider) -> void:
    var track := flat_surface(Color("#111216"), Color("#6e604c"))
    track.content_margin_top = 3
    track.content_margin_bottom = 3
    slider.add_theme_stylebox_override("slider", track)
    slider.add_theme_stylebox_override("grabber_area", flat_surface(Color("#a38149"), Color("#a38149"), 5, 0))
    slider.add_theme_stylebox_override("grabber_area_highlight", flat_surface(Color("#c9a45c"), Color("#c9a45c"), 5, 0))
    slider.add_theme_icon_override("grabber", KenneyIcons.texture("slider"))
    slider.add_theme_icon_override("grabber_highlight", KenneyIcons.texture("slider_hover"))
    slider.add_theme_icon_override("grabber_disabled", KenneyIcons.texture("slider_disabled"))
    slider.add_theme_stylebox_override("focus", keyboard_focus_skin())
    slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func apply_progress(bar: ProgressBar, target: float) -> void:
    bar.add_theme_stylebox_override("background", flat_surface(Color("#111216"), Color("#514633"), 4))
    bar.add_theme_stylebox_override("fill", flat_surface(Color("#c9a45c"), Color("#e0c38a"), 4, 0))
    bar.value = target
    # Presentation only. The profile continues to be the source of truth.
    if not bar.is_inside_tree() or not bar.is_visible_in_tree():
        return
    var settings := bar.get_node_or_null("/root/GameSettings")
    if settings != null and bool(settings.call("get_option", "reduced_menu_motion")):
        return
    bar.value = bar.min_value
    var motion := bar.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    motion.tween_method(func(value: float) -> void:
        if is_instance_valid(settings) and bool(settings.call("get_option", "reduced_menu_motion")):
            bar.value = target
            motion.kill()
        else:
            bar.value = value
    , bar.min_value, target, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
