extends CharacterBody3D

const WALK_SPEED := 4.0
const SPRINT_SPEED := 6.3
const MOUSE_SENSITIVITY := 0.002
const GRAVITY := 18.0
const PauseMenu = preload("res://ui/pause_menu.gd")

# Camera motion is cosmetic and can be disabled for motion-sensitive players.
# Mouse look keeps full control of pitch; no step-induced camera pitching.
@export var camera_motion_enabled: bool = true
@export_range(0.0, 0.06, 0.001) var walk_bob_strength: float = 0.020
@export_range(0.0, 0.04, 0.001) var breathing_strength: float = 0.011

@onready var camera: Camera3D = $Camera3D

var _camera_home: Vector3
var _camera_roll_home: float
var _step_clock: float = 0.0
var _breath_clock: float = 0.0
var _walk_blend: float = 0.0
var _sprint_toggled := false
var _options: Variant = null

func _ready() -> void:
    _camera_home = camera.position
    _camera_roll_home = camera.rotation.z
    _options = get_node_or_null("/root/GameSettings")
    if _options != null:
        _options.options_changed.connect(_on_option_changed)
        _on_option_changed("")
    var pause_menu := PauseMenu.new()
    pause_menu.name = "InGameMenu"
    add_child(pause_menu)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_option_changed(_key: String) -> void:
    if _options == null:
        return
    camera_motion_enabled = bool(_options.get_option("camera_motion"))
    camera.fov = float(_options.get_option("fov"))


func _setting(key: String, fallback: Variant) -> Variant:
    return _options.get_option(key) if _options != null else fallback


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        var sensitivity := MOUSE_SENSITIVITY * float(_setting("mouse_sensitivity", 1.0))
        rotate_y(-event.relative.x * sensitivity)
        var invert := -1.0 if bool(_setting("invert_y", false)) else 1.0
        camera.rotate_x(-event.relative.y * sensitivity * invert)
        camera.rotation.x = clamp(camera.rotation.x, -1.25, 1.25)
    elif event is InputEventKey and event.pressed and not event.echo \
            and event.keycode == KEY_SHIFT and str(_setting("sprint_mode", "hold")) == "toggle":
        _sprint_toggled = not _sprint_toggled
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
    if not camera_motion_enabled:
        camera.position = _camera_home
        camera.rotation.z = _camera_roll_home
        return

    # A complete inhale/exhale cycle takes roughly five seconds.
    _breath_clock += delta * 1.22
    var horizontal_speed := Vector2(velocity.x, velocity.z).length()
    var target_weight := 0.0
    if is_on_floor():
        target_weight = clampf(horizontal_speed / WALK_SPEED, 0.0, 1.0)
    _walk_blend = lerpf(_walk_blend, target_weight, 1.0 - exp(-7.0 * delta))
    _step_clock += delta * 8.8 * target_weight

    var breath_y := sin(_breath_clock) * breathing_strength
    var step_y := sin(_step_clock * 2.0) * walk_bob_strength * _walk_blend
    var step_x := cos(_step_clock) * walk_bob_strength * 0.38 * _walk_blend
    var target := _camera_home + Vector3(step_x, breath_y + step_y, 0.0)
    var smooth := 1.0 - exp(-10.0 * delta)
    camera.position = camera.position.lerp(target, smooth)

    # Extremely slight side-to-side sway while walking; no camera pitch.
    var roll := _camera_roll_home + 0.003 * sin(_step_clock) * _walk_blend
    camera.rotation.z = lerpf(camera.rotation.z, roll, smooth)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0

    var axis := Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_W):
        axis.y -= 1.0
    if Input.is_physical_key_pressed(KEY_S):
        axis.y += 1.0
    if Input.is_physical_key_pressed(KEY_A):
        axis.x -= 1.0
    if Input.is_physical_key_pressed(KEY_D):
        axis.x += 1.0
    # Movement MUST be world-space relative to the live view.
    # Reparenting to a hall rotated by 180 degrees must not reverse WASD.
    var direction := _movement_direction(axis)
    var sprint := _sprint_toggled if str(_setting("sprint_mode", "hold")) == "toggle" \
        else Input.is_physical_key_pressed(KEY_SHIFT)
    var speed := SPRINT_SPEED if sprint else WALK_SPEED
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    move_and_slide()

func _movement_direction(axis: Vector2) -> Vector3:
    var camera_basis := camera.global_transform.basis
    var right := camera_basis.x
    right.y = 0.0
    right = right.normalized()
    var forward := -camera_basis.z
    forward.y = 0.0
    forward = forward.normalized()
    return (right * axis.x - forward * axis.y).normalized()


func _exit_tree() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
