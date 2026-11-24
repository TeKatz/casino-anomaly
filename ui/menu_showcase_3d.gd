extends Control
## Visual-only view of the authored casino, with a separate 3D world.
signal panorama_ready
signal panorama_failed

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
var background_mode := "live"
var camera_speed := 1.0
var menu_scale := 1.0
var ready_for_display := false
var base_position := Vector3.ZERO
var first_frame_ready := false
var warming := false
var load_deadline := 0
var loaded_scene: PackedScene

func _ready() -> void:
    base_position = rig.position
    ($RenderSurface as TextureRect).texture = viewport.get_texture()
    get_window().size_changed.connect(_resize_render_target)
    resized.connect(_resize_render_target)
    _resize_render_target()
    var settings := get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_setting)
        _on_setting("")
    set_process(false)
    if DisplayServer.get_name() != "headless":
        call_deferred("_begin_after_cover")

func _begin_after_cover() -> void:
    # Present the branded cover before loading or instantiating geometry.
    await RenderingServer.frame_post_draw
    if is_inside_tree():
        _request_room()


func _resize_render_target() -> void:
    # Canvas-items stretch uses logical UI coordinates. The texture must
    # match the window's actual pixels, not the logical 1280x720 canvas.
    var pixels := get_window().size
    if pixels.x < 2 or pixels.y < 2:
        return
    viewport.size = Vector2i(maxi(2, roundi(pixels.x * menu_scale)), maxi(2, roundi(pixels.y * menu_scale)))
    if ready_for_display and not suspended and not motion_enabled:
        viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _on_setting(key: String) -> void:
    var settings := get_node_or_null("/root/GameSettings")
    if settings == null:
        return
    if key == "" or key == "menu_camera_motion" or key == "menu_background":
        background_mode = str(settings.call("get_option", "menu_background"))
        motion_enabled = background_mode == "live" and bool(settings.call("get_option", "menu_camera_motion"))
        if key == "menu_background":
            if background_mode == "abstract":
                hide()
                panorama_failed.emit()
            elif first_frame_ready:
                show()
                panorama_ready.emit()
            elif DisplayServer.get_name() != "headless":
                _request_room()
    if key == "" or key == "menu_camera_speed":
        camera_speed = float(settings.call("get_option", "menu_camera_speed"))
    if key == "" or key == "menu_render_scale":
        menu_scale = float(settings.call("get_option", "menu_render_scale"))
        _resize_render_target()
    if key == "" or key == "menu_darkness":
        ($ReadabilityGrade.material as ShaderMaterial).set_shader_parameter("dimming", float(settings.call("get_option", "menu_darkness")))
    if key in ["", "aa_mode", "taa", "upscaling", "anisotropy", "shadow_quality"]:
        settings.call("apply_viewport", viewport, true)
    if ready_for_display:
        _sync_rendering()

func _request_room() -> void:
    if background_mode == "abstract":
        panorama_failed.emit()
        return
    if loading or is_instance_valid(room) or suspended:
        return
    if loaded_scene != null:
        install_room(loaded_scene)
        loaded_scene = null
        return
    var err := ResourceLoader.load_threaded_request(CASINO_PATH, "PackedScene", false)
    if err != OK:
        push_warning("Menu panorama could not request casino scene: " + str(err))
        panorama_failed.emit()
        return
    loading = true
    load_deadline = Time.get_ticks_msec() + 30000
    set_process(true)

func _process(delta: float) -> void:
    if loading:
        if load_deadline > 0 and Time.get_ticks_msec() >= load_deadline:
            # Allow the menu to be used if the background cannot load.
            # Keep polling to consume the threaded request, but do not
            # replace the fallback unexpectedly after the failure.
            load_deadline = 0
            panorama_failed.emit()
        var status := ResourceLoader.load_threaded_get_status(CASINO_PATH)
        if status == ResourceLoader.THREAD_LOAD_LOADED:
            loading = false
            loaded_scene = ResourceLoader.load_threaded_get(CASINO_PATH) as PackedScene
            if load_deadline == 0:
                loaded_scene = null
            elif not suspended and background_mode != "abstract":
                if not install_room(loaded_scene):
                    panorama_failed.emit()
                loaded_scene = null
            _sync_rendering()
        elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            loading = false
            set_process(false)
            push_warning("Menu panorama could not load casino scene")
            panorama_failed.emit()
        return
    if first_frame_ready and not suspended and motion_enabled:
        elapsed = fmod(elapsed + delta * camera_speed, PERIOD)
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
    warming = true
    _sync_rendering()
    if DisplayServer.get_name() != "headless":
        # The cover remains opaque during the actual render warmup,
        # including initial shader compilation and temporal AA history.
        for frame in range(6):
            await RenderingServer.frame_post_draw
            if not is_inside_tree():
                return
    warming = false
    first_frame_ready = true
    modulate.a = 1.0
    _sync_rendering()
    if background_mode == "abstract":
        hide()
        panorama_failed.emit()
    else:
        show()
        panorama_ready.emit()

func update_pose(seconds: float) -> void:
    var angle := TAU * seconds / PERIOD
    rig.rotation = Vector3(-0.025, sin(angle) * SWEEP, 0.0)
    rig.position = base_position + Vector3(sin(angle) * 0.62, 0.0, -0.28 * (1.0 - cos(angle)))

func set_suspended(value: bool) -> void:
    suspended = value
    _sync_rendering()
    if not value and not loading and not is_instance_valid(room) and DisplayServer.get_name() != "headless":
        _request_room()


func _sync_rendering() -> void:
    if not ready_for_display or suspended or background_mode == "abstract":
        viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    elif warming or motion_enabled:
        viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    else:
        viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    set_process(loading or (first_frame_ready and not suspended and motion_enabled))
