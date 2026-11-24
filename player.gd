extends CharacterBody3D

const WALK_SPEED := 4.0
const SPRINT_SPEED := 6.3
const MOUSE_SENSITIVITY := 0.002
const GRAVITY := 18.0
const WALK_ACCELERATION := 13.0
const WALK_DECELERATION := 19.0
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
var _footstep_distance := 0.80
var interaction_locked := false
var backrooms_mode := false
var backrooms_flashlight: SpotLight3D
var collision_diagnostics := false
var _reported_contacts: Dictionary = {}
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
    # A real first-person player is the beginning of the soundscape.
    # This works in tutorial, casino halls, preview and continued saves;
    # repeated Player instances during room streaming do not restart tone.
    var sound := get_node_or_null("/root/AudioDirector")
    if sound != null:
        sound.set_world_ambience_enabled(true)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_option_changed(_key: String) -> void:
    if _options == null:
        return
    camera_motion_enabled = bool(_options.get_option("camera_motion"))
    camera.fov = float(_options.get_option("fov"))


func _setting(key: String, fallback: Variant) -> Variant:
    return _options.get_option(key) if _options != null else fallback


func set_interaction_locked(locked: bool) -> void:
    interaction_locked = locked
    if locked:
        velocity = Vector3.ZERO
        _footstep_distance = 0.80


func set_backrooms_mode(enabled: bool) -> void:
    backrooms_mode = enabled
    _sprint_toggled = false
    _footstep_distance = 0.0
    if not enabled and is_instance_valid(backrooms_flashlight):
        backrooms_flashlight.free()
        backrooms_flashlight = null


func equip_backrooms_flashlight() -> bool:
    if not backrooms_mode or is_instance_valid(backrooms_flashlight):
        return false
    backrooms_flashlight = SpotLight3D.new()
    backrooms_flashlight.name = "BackroomsFlashlight"
    backrooms_flashlight.position = Vector3(0.18, -0.12, -0.12)
    backrooms_flashlight.light_color = Color(0.94, 0.96, 1.0)
    backrooms_flashlight.light_energy = 2.2
    backrooms_flashlight.spot_range = 15.0
    backrooms_flashlight.spot_angle = 28.0
    backrooms_flashlight.spot_angle_attenuation = 1.5
    backrooms_flashlight.shadow_enabled = true
    backrooms_flashlight.light_bake_mode = Light3D.BAKE_DISABLED
    camera.add_child(backrooms_flashlight)
    return true


func _unhandled_input(event: InputEvent) -> void:
    if interaction_locked:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        var sensitivity := MOUSE_SENSITIVITY * float(_setting("mouse_sensitivity", 1.0))
        rotate_y(-event.relative.x * sensitivity)
        var invert := -1.0 if bool(_setting("invert_y", false)) else 1.0
        camera.rotate_x(-event.relative.y * sensitivity * invert)
        camera.rotation.x = clamp(camera.rotation.x, -1.25, 1.25)
    elif event is InputEventKey and event.pressed and not event.echo \
            and not backrooms_mode and event.keycode == KEY_SHIFT and str(_setting("sprint_mode", "hold")) == "toggle":
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
    var lateral := velocity.dot(camera.global_transform.basis.x) / SPRINT_SPEED
    var roll := _camera_roll_home + 0.003 * sin(_step_clock) * _walk_blend \
            - 0.004 * clampf(lateral, -1.0, 1.0)
    camera.rotation.z = lerpf(camera.rotation.z, roll, smooth)

func _physics_process(delta: float) -> void:
    if interaction_locked:
        velocity = Vector3.ZERO
        return
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
    sprint = sprint and not backrooms_mode
    var speed := SPRINT_SPEED if sprint else (3.1 if backrooms_mode else WALK_SPEED)
    var target := direction * speed
    var acceleration := WALK_ACCELERATION if axis.length_squared() > 0.0 else WALK_DECELERATION
    velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
    velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
    var before := global_position
    move_and_slide()
    if collision_diagnostics:
        _report_collision_contacts()
    _update_footsteps(global_position.distance_to(before), sprint)


func set_collision_diagnostics(enabled: bool) -> void:
    collision_diagnostics = enabled
    _reported_contacts.clear()
    print("[Collision Debug] ", "ON" if enabled else "OFF")


func _report_collision_contacts() -> void:
    var current: Dictionary = {}
    for i in range(get_slide_collision_count()):
        var hit := get_slide_collision(i)
        # Ignore ordinary floor and ceiling contacts.
        if absf(hit.get_normal().y) >= 0.5:
            continue
        var collider := hit.get_collider()
        if not is_instance_valid(collider):
            continue
        var index := hit.get_collider_shape_index()
        var key := "%s:%d" % [str(hit.get_collider_id()), index]
        current[key] = true
        if _reported_contacts.has(key):
            continue
        var path := str(collider.get_path()) if collider is Node else str(collider)
        var shape_description := str(index)
        if collider is CollisionObject3D:
            var owner_id: int = collider.shape_find_owner(index)
            var shape_node := collider.shape_owner_get_owner(owner_id) as CollisionShape3D
            if shape_node != null and shape_node.shape != null:
                shape_description = "%s (%s)" % [str(shape_node.get_path()), shape_node.shape.get_class()]
        print("[Collision Debug] body=", path, " shape=", shape_description,
            " point=", hit.get_position(), " normal=", hit.get_normal())
    _reported_contacts = current


func classify_casino_surface(local: Vector3) -> String:
    # Carpet is a visual quad without a collision layer: match hall.gd.
    if local.x < -46.0 or local.z > 13.90:
        return "corridor"
    var approach := absf(local.x) < 1.49 and local.z >= -6.52 and local.z <= 12.65
    var west := local.x >= -44.8 and local.x <= -1.49 \
            and local.z >= -6.52 and local.z <= -3.55
    return "carpet" if approach or west else "wood"


func _surface_underfoot() -> String:
    if backrooms_mode:
        return "carpet"
    var room := get_parent() as Node3D
    if room == null or not room.has_node("RedCarpet"):
        return "wood" # Tutorial has no carpet.
    return classify_casino_surface(room.to_local(global_position))


func _update_footsteps(traveled: float, sprinting: bool) -> void:
    if not is_on_floor() or traveled < 0.001:
        return
    _footstep_distance += traveled
    var stride := 1.95 if sprinting else 1.50
    if _footstep_distance < stride:
        return
    _footstep_distance = fmod(_footstep_distance, stride)
    var sound := get_node_or_null("/root/AudioDirector")
    if sound != null:
        var surface := _surface_underfoot()
        sound.play_footstep(surface, sprinting)
        sound.set_corridor_acoustics(surface == "corridor")


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
