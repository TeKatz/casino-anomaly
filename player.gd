extends CharacterBody3D

const WALK_SPEED := 4.0
const MOUSE_SENSITIVITY := 0.002
const GRAVITY := 18.0

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

func _ready() -> void:
    _camera_home = camera.position
    _camera_roll_home = camera.rotation.z
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
        camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
        camera.rotation.x = clamp(camera.rotation.x, -1.25, 1.25)
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        get_tree().change_scene_to_file("res://menu.tscn")
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
    var direction := (basis * Vector3(axis.x, 0.0, axis.y)).normalized()
    velocity.x = direction.x * WALK_SPEED
    velocity.z = direction.z * WALK_SPEED
    move_and_slide()

func _exit_tree() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
