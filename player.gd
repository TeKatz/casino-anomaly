extends CharacterBody3D

const WALK_SPEED := 4.0
const SPRINT_SPEED := 6.3
const BACKROOMS_WALK_SPEED := 2.1
const BACKROOMS_FLASHLIGHT_ENERGY := 0.95
const BACKROOMS_FLASHLIGHT_RANGE := 11.0
const BACKROOMS_FLASHLIGHT_PROJECTOR = preload("res://backrooms/materials/flashlight_beam.svg")
const MOUSE_SENSITIVITY := 0.002
const GRAVITY := 18.0
const WALK_ACCELERATION := 13.0
const WALK_DECELERATION := 19.0
const Controls = preload("res://gameplay/input_bindings.gd")
const ComfortHUD = preload("res://ui/comfort_hud.gd")
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
var _streaming_handoff := false
var backrooms_flashlight: SpotLight3D
var collision_diagnostics := false
var _reported_contacts: Dictionary = {}
var _options: Variant = null
var _mouse_pending := Vector2.ZERO

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
    var comfort := ComfortHUD.new()
    comfort.name = "ComfortHUD"
    add_child(comfort)
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
    if _key in ["", "camera_motion"]:
        camera_motion_enabled = bool(_options.get_option("camera_motion"))
    if _key in ["", "fov"]:
        camera.fov = float(_options.get_option("fov"))
    if _key in ["key_bindings", "sprint_mode", "controller_enabled"]:
        _sprint_toggled = false
        _mouse_pending = Vector2.ZERO


func _setting(key: String, fallback: Variant) -> Variant:
    return _options.get_option(key) if _options != null else fallback


func set_interaction_locked(locked: bool) -> void:
    interaction_locked = locked
    if locked:
        _mouse_pending = Vector2.ZERO
        _sprint_toggled = false
        velocity = Vector3.ZERO
        _footstep_distance = 0.80


func begin_streaming_handoff() -> void:
    _streaming_handoff = true


func end_streaming_handoff() -> void:
    _streaming_handoff = false
    restore_streaming_view()


func restore_streaming_view() -> void:
    if not is_inside_tree() or not is_instance_valid(camera):
        return
    # Reparenting can change the viewport camera registration. Never rely
    # on the implicit camera choice after a scene handoff.
    camera.make_current()
    if not get_tree().paused and not interaction_locked:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_backrooms_mode(enabled: bool) -> void:
    backrooms_mode = enabled
    _sprint_toggled = false
    _footstep_distance = 0.0
    if enabled:
        # Clamp residual sprint velocity at the reveal, not several steps later.
        var horizontal := Vector2(velocity.x, velocity.z).limit_length(BACKROOMS_WALK_SPEED)
        velocity.x = horizontal.x
        velocity.z = horizontal.y
    if not enabled and is_instance_valid(backrooms_flashlight):
        backrooms_flashlight.free()
        backrooms_flashlight = null


func equip_backrooms_flashlight() -> bool:
    if not backrooms_mode or is_instance_valid(backrooms_flashlight):
        return false
    backrooms_flashlight = SpotLight3D.new()
    backrooms_flashlight.name = "BackroomsFlashlight"
    backrooms_flashlight.position = Vector3(0.12, -0.10, -0.09)
    backrooms_flashlight.light_color = Color(0.97, 0.96, 0.90)
    backrooms_flashlight.light_energy = BACKROOMS_FLASHLIGHT_ENERGY
    backrooms_flashlight.set_meta("_return_base_energy", BACKROOMS_FLASHLIGHT_ENERGY)
    backrooms_flashlight.spot_range = BACKROOMS_FLASHLIGHT_RANGE
    backrooms_flashlight.spot_angle = 34.0
    backrooms_flashlight.spot_angle_attenuation = 0.85
    backrooms_flashlight.spot_attenuation = 1.0
    backrooms_flashlight.light_projector = BACKROOMS_FLASHLIGHT_PROJECTOR
    backrooms_flashlight.light_specular = 0.55
    backrooms_flashlight.light_volumetric_fog_energy = 0.35
    backrooms_flashlight.shadow_enabled = true
    backrooms_flashlight.shadow_blur = 1.25
    backrooms_flashlight.light_bake_mode = Light3D.BAKE_DISABLED
    camera.add_child(backrooms_flashlight)
    interaction_vibration()
    return true


func _unhandled_input(event: InputEvent) -> void:
    if interaction_locked:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        var relative: Vector2 = event.relative
        if float(_setting("mouse_smoothing", 0.0)) > 0.0:
            _mouse_pending += relative
        else:
            _apply_look(relative)
    elif Controls.pressed(event, "sprint") and not backrooms_mode and str(_setting("sprint_mode", "hold")) == "toggle":
        _sprint_toggled = not _sprint_toggled
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func interaction_vibration() -> void:
    if _options == null or not bool(_options.get_meta("_using_gamepad", false)) or not bool(_setting("controller_enabled", true)):
        return
    var strength := float(_setting("controller_vibration", 0.0))
    if strength > 0.0:
        for device in Input.get_connected_joypads():
            Input.start_joy_vibration(device, strength * 0.5, strength * 0.2, 0.12)

func _apply_look(relative: Vector2) -> void:
    var sensitivity := MOUSE_SENSITIVITY * float(_setting("mouse_sensitivity", 1.0))
    rotate_y(-relative.x * sensitivity * (-1.0 if bool(_setting("invert_x", false)) else 1.0))
    camera.rotate_x(-relative.y * sensitivity * float(_setting("mouse_vertical_multiplier", 1.0)) * (-1.0 if bool(_setting("invert_y", false)) else 1.0))
    camera.rotation.x = clampf(camera.rotation.x, -1.25, 1.25)


func _process(delta: float) -> void:
    if not interaction_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        if _mouse_pending.length_squared() > 0.0001:
            var smoothing := float(_setting("mouse_smoothing", 0.0))
            var fraction := 1.0 if smoothing <= 0.0 else 1.0 - exp(-lerpf(50.0, 12.0, smoothing) * delta)
            var portion := _mouse_pending * fraction
            _mouse_pending -= portion
            _apply_look(portion)
        if bool(_setting("controller_enabled", true)):
            var stick := Input.get_vector("casino_look_left", "casino_look_right", "casino_look_up", "casino_look_down")
            var turn := stick * float(_setting("controller_sensitivity", 1.0)) * 2.4 * delta
            rotate_y(-turn.x * (-1.0 if bool(_setting("invert_x", false)) else 1.0))
            camera.rotation.x = clampf(camera.rotation.x - turn.y * (-1.0 if bool(_setting("invert_y", false)) else 1.0), -1.25, 1.25)
    else:
        _mouse_pending = Vector2.ZERO
    if not camera_motion_enabled or bool(_setting("reduced_motion", false)):
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

    var breath_y := sin(_breath_clock) * breathing_strength * float(_setting("breathing_motion", 1.0))
    var step_y := sin(_step_clock * 2.0) * walk_bob_strength * _walk_blend * float(_setting("head_bob", 1.0))
    var step_x := cos(_step_clock) * walk_bob_strength * 0.38 * _walk_blend * float(_setting("camera_sway", 1.0))
    var target := _camera_home + Vector3(step_x, breath_y + step_y, 0.0)
    var smooth := 1.0 - exp(-10.0 * delta)
    camera.position = camera.position.lerp(target, smooth)

    # Extremely slight side-to-side sway while walking; no camera pitch.
    var lateral := velocity.dot(camera.global_transform.basis.x) / SPRINT_SPEED
    var roll := _camera_roll_home + 0.003 * sin(_step_clock) * _walk_blend \
            - 0.004 * clampf(lateral, -1.0, 1.0)
    camera.rotation.z = lerpf(camera.rotation.z, lerpf(_camera_roll_home, roll, float(_setting("camera_sway", 1.0))), smooth)

func movement_speed(sprint_requested: bool) -> float:
    if backrooms_mode:
        return BACKROOMS_WALK_SPEED
    return SPRINT_SPEED if sprint_requested else WALK_SPEED


func _physics_process(delta: float) -> void:
    if interaction_locked:
        velocity = Vector3.ZERO
        return
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0

    var axis := Input.get_vector("casino_move_left", "casino_move_right", "casino_move_forward", "casino_move_back")
    # Movement MUST be world-space relative to the live view.
    # Reparenting to a hall rotated by 180 degrees must not reverse WASD.
    var direction := _movement_direction(axis)
    var sprint := _sprint_toggled if str(_setting("sprint_mode", "hold")) == "toggle" \
        else Input.is_action_pressed("casino_sprint")
    sprint = sprint and not backrooms_mode
    var speed := movement_speed(sprint)
    var target := direction * speed * minf(axis.length(), 1.0)
    var acceleration := WALK_ACCELERATION if axis.length_squared() > 0.0 else WALK_DECELERATION
    velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
    velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
    var before := global_position
    move_and_slide()
    if collision_diagnostics:
        _report_collision_contacts()
    var displacement := global_position - before
    var traveled := Vector2(displacement.x, displacement.z).length()
    # Use actual ground speed, not the held sprint key (e.g. at a wall).
    var running := not backrooms_mode and traveled / maxf(delta, 0.0001) > WALK_SPEED + 0.15
    _update_footsteps(traveled, running)


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
        return "wet_carpet"
    var room := get_parent() as Node3D
    if room == null or not room.has_node("RedCarpet"):
        return "wood" # Tutorial has no carpet.
    return classify_casino_surface(room.to_local(global_position))


func _update_footsteps(traveled: float, sprinting: bool) -> void:
    if not is_on_floor() or traveled < 0.001:
        return
    _footstep_distance += traveled
    var stride := 1.05 if backrooms_mode else (1.95 if sprinting else 1.50)
    if _footstep_distance < stride:
        return
    _footstep_distance = fmod(_footstep_distance, stride)
    var sound := get_node_or_null("/root/AudioDirector")
    if sound != null:
        var surface := _surface_underfoot()
        var room := get_parent() as Node3D
        if not backrooms_mode and room != null:
            var flood := room.get_node_or_null("AnomalyFlood")
            if flood != null:
                var local := room.to_local(global_position)
                if bool(flood.call("contains_water",local)):
                    surface = "water"
                    flood.call("register_step",local,sprinting)
        sound.play_footstep(surface, sprinting)
        var comfort := get_node_or_null("ComfortHUD")
        if comfort != null:
            comfort.call("announce", "steps")
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


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _mouse_pending = Vector2.ZERO
        _sprint_toggled = false
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and bool(_setting("pause_unfocused", false)) and not interaction_locked and not _streaming_handoff and not get_tree().paused:
        var loading := get_node_or_null("/root/SceneLoader")
        var dev := get_node_or_null("AnomalyDevMenu")
        var pause_menu := get_node_or_null("InGameMenu")
        if pause_menu != null and not (loading != null and bool(loading.get("active"))) and not (dev != null and dev.visible):
            pause_menu.call("_pause")

func _exit_tree() -> void:
    if not _streaming_handoff:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
