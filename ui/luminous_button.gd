extends Button
## Soft sculpted-glass buttons; no icons, corner strokes or orange trim.
## The default mouse-click focus outline is suppressed. Keyboard/gamepad
## navigation gets a quiet *internal* focus edge instead.
@export var featured := false

const MenuStyle = preload("res://ui/menu_style.gd")
var _motion: Tween
var _keyboard_navigation := false


func _ready() -> void:
    MenuStyle.apply_button(self, featured)
    alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_theme_font_size_override("font_size", 19 if featured else 16)
    mouse_entered.connect(_hover_changed.bind(true))
    mouse_exited.connect(_hover_changed.bind(false))
    button_down.connect(_press_changed.bind(true))
    button_up.connect(_press_changed.bind(false))
    focus_entered.connect(_refresh_focus)
    focus_exited.connect(_refresh_focus)
    resized.connect(_center_pivot)
    _center_pivot()


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
    _animate_size(Vector2(1.013, 1.013) if entered else Vector2.ONE, 0.19)


func _press_changed(pressed: bool) -> void:
    if disabled:
        return
    _animate_size(Vector2(0.985, 0.985) if pressed else Vector2.ONE, 0.12)


func _animate_size(target: Vector2, duration: float) -> void:
    if _motion != null and _motion.is_running():
        _motion.kill()
    _motion = create_tween()
    _motion.tween_property(self, "scale", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
