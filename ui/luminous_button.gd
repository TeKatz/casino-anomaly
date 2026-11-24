extends Button
## Soft sculpted-glass buttons with a unified, cached line-icon system.
## The default mouse-click focus outline is suppressed. Keyboard/gamepad
## navigation gets a quiet *internal* focus edge instead.
@export var featured := false
@export_enum("gold", "green", "red", "amber") var accent := "gold"
@export var symbol := ""
@export var compact_icon := false

const Controls = preload("res://gameplay/input_bindings.gd")
const MenuStyle = preload("res://ui/menu_style.gd")
const MenuIcons = preload("res://ui/menu_icons.gd")
var _motion: Tween
var _keyboard_navigation := false


func _ready() -> void:
    MenuStyle.apply_button(self, featured, accent)
    alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if compact_icon else HORIZONTAL_ALIGNMENT_LEFT
    expand_icon = false
    add_theme_constant_override("h_separation", 12)
    set_symbol(symbol)
    if compact_icon:
        # The shared 23px side padding is correct for wide text buttons,
        # but makes a 46px icon-only delete action overflow. Use private
        # style copies; never mutate the cached nine-slice skins.
        for state in ["normal", "hover", "pressed", "disabled"]:
            var base := get_theme_stylebox(state) as StyleBoxTexture
            if base == null:
                continue
            var compact := base.duplicate() as StyleBoxTexture
            compact.content_margin_left = 7.0
            compact.content_margin_right = 7.0
            compact.content_margin_top = 5.0
            compact.content_margin_bottom = 5.0
            add_theme_stylebox_override(state, compact)
        add_theme_constant_override("h_separation", 0)
    add_theme_font_size_override("font_size", 19 if featured else 16)
    mouse_entered.connect(_hover_changed.bind(true))
    mouse_exited.connect(_hover_changed.bind(false))
    button_down.connect(_press_changed.bind(true))
    button_up.connect(_press_changed.bind(false))
    focus_entered.connect(_refresh_focus)
    focus_exited.connect(_refresh_focus)
    resized.connect(_center_pivot)
    _center_pivot()


func set_symbol(value: String) -> void:
    symbol = value
    icon = MenuIcons.texture(value)


func set_accent(value: String, promoted: bool = false) -> void:
    accent = value
    featured = promoted
    if is_node_ready():
        MenuStyle.apply_button(self, featured, accent)


func _center_pivot() -> void:
    pivot_offset = size * 0.5


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        _keyboard_navigation = false
        if has_focus():
            _refresh_focus()
    elif event is InputEventKey and event.pressed:
        if event.keycode in [KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
            _keyboard_navigation = true
            call_deferred("_refresh_focus")
    elif event is InputEventJoypadButton and event.pressed:
        _keyboard_navigation = true
        call_deferred("_refresh_focus")


func _refresh_focus() -> void:
    if not is_inside_tree():
        return
    if has_focus() and _keyboard_navigation:
        add_theme_stylebox_override("focus", MenuStyle.keyboard_focus_skin())
    else:
        add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _hover_changed(entered: bool) -> void:
    if disabled:
        return
    _animate_size(Vector2(1.017, 1.017) if entered else Vector2.ONE, 0.22)


func _press_changed(pressed: bool) -> void:
    if disabled:
        return
    _animate_size(Vector2(0.985, 0.985) if pressed else Vector2.ONE, 0.12)


func _animate_size(target: Vector2, duration: float) -> void:
    if _motion != null and _motion.is_running():
        _motion.kill()
    if bool(Controls.pref(self, "reduced_menu_motion", false)):
        scale = Vector2.ONE
        self_modulate = Color.WHITE
        return
    _motion = create_tween().set_parallel(true)
    _motion.tween_property(self, "scale", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    var tint := Color(1.06, 1.07, 1.09, 1.0) if target.x > 1.0 else Color.WHITE
    _motion.tween_property(self, "self_modulate", tint, duration).set_trans(Tween.TRANS_CUBIC)
