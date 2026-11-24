extends SceneTree
const Settings = preload("res://gameplay/settings.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("Graphics settings QA: " + message)
    quit(1)

func _run() -> void:
    var settings = root.get_node("GameSettings")
    var saved: Dictionary = settings.options.duplicate(true)
    settings.set_option("graphics_preset", "low")
    if settings.get_option("shadow_quality") != "low" or settings.get_option("voxel_gi") or not is_equal_approx(root.scaling_3d_scale, 0.67):
        _fail("Low preset not applied to renderer")
        return
    settings.set_option("render_scale", 0.9)
    if settings.get_option("graphics_preset") != "custom":
        _fail("Custom modification not reflected in preset")
        return
    settings.set_option("graphics_preset", "high")
    settings.set_option("aa_mode", "msaa4")
    if root.msaa_3d != Viewport.MSAA_4X or root.use_taa:
        _fail("AA selection not applied")
        return
    settings.set_option("upscaling", "fsr2")
    if root.scaling_3d_mode != Viewport.SCALING_3D_MODE_FSR2 or root.msaa_3d != Viewport.MSAA_DISABLED:
        _fail("FSR2 did not replace conflicting anti-aliasing")
        return
    settings.set_option("fps_limit", 120)
    settings.set_option("menu_fps_limit", 30)
    settings.set_menu_context(true)
    if Engine.max_fps != 30:
        _fail("Menu FPS cap missing")
        return
    settings.set_menu_context(false)
    if Engine.max_fps != 120:
        _fail("Gameplay FPS cap not restored")
        return
    var before: String = settings.get_option("resolution")
    settings.preview_display("resolution", "3440x1440")
    settings.save_options()
    var config := ConfigFile.new()
    if config.load(Settings.FILE_PATH) != OK or str(config.get_value("settings", "resolution")) != before:
        _fail("Unconfirmed display preview persisted")
        return
    settings.cancel_display_preview()
    if settings.get_option("resolution") != before:
        _fail("Display rollback missing")
        return
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.volumetric_fog_enabled = true
    env.ssao_enabled = true
    env.glow_enabled = true
    env.glow_intensity = 0.6
    world.environment = env
    root.add_child(world)
    var light := OmniLight3D.new()
    light.shadow_enabled = true
    root.add_child(light)
    var probe := ReflectionProbe.new()
    root.add_child(probe)
    settings.reflection_requested(probe, true)
    var particles := CPUParticles3D.new()
    particles.name = "AmbientDust_QA"
    particles.amount = 20
    particles.emitting = true
    root.add_child(particles)
    await process_frame
    settings.set_option("graphics_preset", "low")
    if env.volumetric_fog_enabled or env.ssao_enabled or env.glow_enabled or probe.visible or particles.emitting:
        _fail("Live scene effects not disabled by preset")
        return
    settings.set_option("shadow_quality", "off")
    if light.shadow_enabled:
        _fail("Shadows not disabled")
        return
    settings.set_option("graphics_preset", "high")
    settings.set_option("brightness", 1.15)
    settings.set_option("saturation", 0.7)
    if not env.volumetric_fog_enabled or not env.ssao_enabled or not env.glow_enabled or not probe.visible or not light.shadow_enabled or not particles.emitting or not is_equal_approx(env.adjustment_brightness, 1.15) or not is_equal_approx(env.adjustment_saturation, 0.7):
        _fail("Authored effects not restored or calibration failed")
        return
    settings.set_option("camera_motion", false)
    settings.set_option("menu_camera_motion", true)
    if settings.get_option("camera_motion") or not settings.get_option("menu_camera_motion"):
        _fail("Menu and gameplay motion not independent")
        return
    world.free()
    light.free()
    probe.free()
    particles.free()
    settings._change(saved, true)
    settings.save_options()
    print("Casino Anomaly extended graphics settings QA PASS")
    quit(0)
