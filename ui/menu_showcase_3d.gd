extends Control
## Visual-only view of the authored casino, with a separate 3D world.
const CASINO_PATH := "res://main.tscn"
const PERIOD := 42.0
const SWEEP := 0.39
const Occlusion = preload("res://gameplay/streaming_occlusion.gd")

@onready var viewport: SubViewport = $RenderSurface/World
@onready var stage: Node3D = $RenderSurface/World/Showcase
@onready var rig: Node3D = $RenderSurface/World/Showcase/CameraRig
@onready var camera: Camera3D = $RenderSurface/World/Showcase/CameraRig/PanoramaCamera
var room: Node3D
var loading := false
var suspended := false
var elapsed := 0.0
var motion_enabled := true
var ready_for_display := false
var base_position := Vector3.ZERO
var reveal_tween: Tween
var loaded_scene: PackedScene

func _ready() -> void:
    base_position = rig.position
    var settings := get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_setting)
        _on_setting("camera_motion")
    set_process(false)
    if DisplayServer.get_name() != "headless":
        call_deferred("_request_room")

func _on_setting(key: String) -> void:
    if key == "camera_motion":
        var settings := get_node_or_null("/root/GameSettings")
        motion_enabled = settings == null or bool(settings.get_option("camera_motion"))
    if ready_for_display:
        _sync_rendering()

func _request_room() -> void:
    if loading or is_instance_valid(room) or suspended:
        return
    if loaded_scene != null:
        install_room(loaded_scene)
        loaded_scene = null
        return
    var err := ResourceLoader.load_threaded_request(CASINO_PATH, "PackedScene", false)
    if err != OK:
        push_warning("Menu panorama could not request casino scene: " + str(err))
        return
    loading = true
    set_process(true)

func _process(delta: float) -> void:
    if loading:
        var status := ResourceLoader.load_threaded_get_status(CASINO_PATH)
        if status == ResourceLoader.THREAD_LOAD_LOADED:
            loading = false
            loaded_scene = ResourceLoader.load_threaded_get(CASINO_PATH) as PackedScene
            if not suspended:
                install_room(loaded_scene)
                loaded_scene = null
            _sync_rendering()
        elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            loading = false
            set_process(false)
            push_warning("Menu panorama could not load casino scene")
        return
    if ready_for_display and not suspended and motion_enabled:
        elapsed = fmod(elapsed + delta, PERIOD)
        update_pose(elapsed)

func install_room(packed: PackedScene) -> bool:
    if packed == null or is_instance_valid(room):
        return false
    var visual := packed.instantiate() as Node3D
    if visual == null:
        return false
    visual.name = "CasinoVisual"
    visual.set_meta("_menu_showcase", true)
    for node_name in ["Player", "LoopController", "RoomSoundscape", "StreamingPortals", "VoxelGIRig", "NeonLevelSign"]:
        var unwanted := visual.get_node_or_null(node_name)
        if unwanted != null:
            unwanted.free()
    var world := visual.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if world == null or world.environment == null:
        visual.free()
        return false
    var environment := world.environment.duplicate() as Environment
    environment.volumetric_fog_enabled = false
    environment.ssil_enabled = false
    environment.sdfgi_enabled = false
    environment.ambient_light_energy = maxf(environment.ambient_light_energy, 0.22)
    world.environment = environment
    for probe in visual.find_children("*", "ReflectionProbe", true, false):
        probe.free()
    for probe in visual.find_children("*", "VoxelGI", true, false):
        probe.free()
    for other_camera in visual.find_children("*", "Camera3D", true, false):
        other_camera.free()
    room = visual
    stage.add_child(room)
    camera.make_current()
    update_pose(0.0)
    call_deferred("_finish_room")
    return true

func _finish_room() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if not is_inside_tree() or not is_instance_valid(room):
        return
    Occlusion.casino_walls(room)
    for item in room.find_children("*", "CollisionObject3D", true, false):
        (item as CollisionObject3D).collision_layer = 0
        (item as CollisionObject3D).collision_mask = 0
    for particle in room.find_children("*", "CPUParticles3D", true, false):
        (particle as CPUParticles3D).emitting = false
    for particle in room.find_children("*", "GPUParticles3D", true, false):
        (particle as GPUParticles3D).emitting = false
    for item in room.find_children("*", "Light3D", true, false):
        var light := item as Light3D
        if light is OmniLight3D or room.to_local(light.global_position).x < -8.0:
            light.shadow_enabled = false
    room.process_mode = Node.PROCESS_MODE_DISABLED
    camera.make_current()
    ready_for_display = true
    _sync_rendering()
    if DisplayServer.get_name() == "headless":
        modulate.a = 1.0
        return
    if suspended:
        return
    await RenderingServer.frame_post_draw
    if not is_inside_tree() or suspended:
        return
    _reveal()

func _reveal() -> void:
    if reveal_tween != null and reveal_tween.is_running():
        reveal_tween.kill()
    reveal_tween = create_tween()
    reveal_tween.tween_property(self, "modulate:a", 1.0, 0.65)

func update_pose(seconds: float) -> void:
    var angle := TAU * seconds / PERIOD
    rig.rotation = Vector3(-0.025, sin(angle) * SWEEP, 0.0)
    rig.position = base_position + Vector3(sin(angle) * 0.62, 0.0, -0.28 * (1.0 - cos(angle)))

func set_suspended(value: bool) -> void:
    suspended = value
    _sync_rendering()
    if not value and not loading and not is_instance_valid(room) and DisplayServer.get_name() != "headless":
        _request_room()
    elif not value and ready_for_display and modulate.a < 1.0:
        _reveal()

func _sync_rendering() -> void:
    if not ready_for_display or suspended:
        viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    elif motion_enabled:
        viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    else:
        viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    set_process(loading or (ready_for_display and not suspended and motion_enabled))
