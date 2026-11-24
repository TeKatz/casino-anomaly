extends Node
## Persistent preferences; display previews are transactional and slider writes
## are debounced. Renderer quality never edits an authored scene on disk.
signal options_changed(key: String)
signal display_preview_changed(active: bool)

const FILE_PATH := "user://casino_settings.cfg"
const DEFAULTS := {
    "language": "en",
    "window_mode": "windowed",
    "resolution": "1280x720",
    "monitor": -1,
    "vsync": true,
    "vsync_mode": "on",
    "fps_limit": 0,
    "render_scale": 1,
    "image_contrast": 0.85,
    "taa": true,
    "aa_mode": "taa",
    "voxel_gi": true,
    "graphics_preset": "custom",
    "upscaling": "bilinear",
    "anisotropy": 8,
    "texture_filter": "original",
    "dynamic_resolution": false,
    "dynamic_target_fps": 60,
    "shadow_quality": "original",
    "shadow_distance": "original",
    "fog_quality": "original",
    "reflection_quality": "original",
    "ssao_quality": "original",
    "ssil": true,
    "bloom": true,
    "bloom_strength": 1,
    "brightness": 1,
    "saturation": 1,
    "particle_quality": "original",
    "fps_display": false,
    "performance_overlay": false,
    "menu_background": "live",
    "menu_render_scale": 1,
    "menu_fps_limit": -1,
    "menu_camera_motion": true,
    "menu_camera_speed": 1,
    "menu_darkness": 1,
    "master_volume": 1,
    "music_volume": 0.8,
    "sfx_volume": 0.9,
    "ui_volume": 0.9,
    "mouse_sensitivity": 1,
    "invert_y": false,
    "fov": 75,
    "camera_motion": true,
    "sprint_mode": "hold",
    "hud_visible": true
}
const PRESETS := {
    "low": {
        "render_scale": 0.67,
        "upscaling": "fsr1",
        "aa_mode": "fxaa",
        "anisotropy": 2,
        "texture_filter": "anisotropic",
1679 false,
        "shadow_quality": "low",
        "shadow_distance": "low",
        "fog_quality": "off",
        "reflection_quality": "off",
        "ssao_quality": "off",
        "ssil": false,
        "bloom": false,
        "particle_quality": "off"
    },
    "medium": {
        "render_scale": 0.77,
        "upscaling": "fsr2",
        "aa_mode": "taa",
        "anisotropy": 4,
        "texture_filter": "anisotropic",
2085 true,
        "shadow_quality": "medium",
        "shadow_distance": "medium",
        "fog_quality": "low",
        "reflection_quality": "low",
        "ssao_quality": "low",
        "ssil": false,
        "bloom": true,
        "particle_quality": "low"
    },
    "high": {
        "render_scale": 1,
        "upscaling": "bilinear",
        "aa_mode": "taa",
        "anisotropy": 8,
        "texture_filter": "anisotropic",
2494 true,
        "shadow_quality": "original",
        "shadow_distance": "original",
        "fog_quality": "original",
        "reflection_quality": "original",
        "ssao_quality": "original",
        "ssil": true,
        "bloom": true,
        "particle_quality": "original"
    },
    "ultra": {
        "render_scale": 1,
        "upscaling": "bilinear",
        "aa_mode": "taa",
        "anisotropy": 16,
        "texture_filter": "anisotropic",
2927 true,
        "shadow_quality": "ultra",
        "shadow_distance": "high",
        "fog_quality": "high",
        "reflection_quality": "high",
        "ssao_quality": "high",
        "ssil": true,
        "bloom": true,
        "particle_quality": "high"
    }
}
const GRAPHICS_KEYS := ["window_mode","resolution","monitor","vsync","vsync_mode","fps_limit","render_scale","image_contrast","taa","aa_mode","voxel_gi","graphics_preset","upscaling","anisotropy","texture_filter","dynamic_resolution","dynamic_target_fps","shadow_quality","shadow_distance","fog_quality","reflection_quality","ssao_quality","ssil","bloom","bloom_strength","brightness","saturation","particle_quality","fps_display","performance_overlay","menu_background","menu_render_scale","menu_fps_limit","menu_camera_motion","menu_camera_speed","menu_darkness"]
const DISPLAY_KEYS := ["window_mode", "resolution", "monitor"]
const VOLUME_KEYS := ["master_volume", "music_volume", "sfx_volume", "ui_volume"]
const ENV_KEYS := ["image_contrast", "brightness", "saturation", "fog_quality", "ssao_quality", "ssil", "bloom", "bloom_strength"]
const NODE_KEYS := ["shadow_quality", "shadow_distance", "particle_quality", "reflection_quality", "texture_filter"]
const VIEW_KEYS := ["render_scale", "aa_mode", "taa", "upscaling", "anisotropy", "shadow_quality"]
const QUALITY_KEYS := ["fog_quality", "ssao_quality", "reflection_quality"]
const PREVIEW_SECONDS := 15.0

var options: Dictionary = DEFAULTS.duplicate(true)
var save_timer: Timer
var preview_timer: Timer
var preview_before: Dictionary = {}
var preview_screen := -1
var preview_window_size := Vector2i.ZERO
var preview_window_position := Vector2i.ZERO
var dynamic_elapsed := 0.0
var dynamic_frames := 0
var dynamic_bad_windows := 0
var dynamic_good_windows := 0
var dirty := false
var menu_context := false
var overlay: CanvasLayer
var perf_label: Label
var perf_elapsed := 0.0
var perf_worst := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    save_timer = Timer.new()
    save_timer.one_shot = true
    save_timer.wait_time = 0.35
    add_child(save_timer)
    save_timer.timeout.connect(save_options)
    preview_timer = Timer.new()
    preview_timer.one_shot = true
    add_child(preview_timer)
    preview_timer.timeout.connect(cancel_display_preview)
    load_options()
    apply_options()
    get_tree().node_added.connect(_on_node_added)
    set_process(false)
    _update_overlay()

func get_option(key: String) -> Variant:
    return options.get(key, DEFAULTS.get(key))

func set_option(key: String, value: Variant) -> void:
    if not DEFAULTS.has(key):
        push_warning("Unknown setting: " + key)
        return
    if key == "graphics_preset" and PRESETS.has(str(value)):
        var patch: Dictionary = PRESETS[str(value)].duplicate()
        patch["graphics_preset"] = str(value)
        _change(patch, true)
    else:
        _change({key: value}, false)

func _change(patch: Dictionary, keep_preset: bool) -> void:
    var keys: Array[String] = []
    for key in patch:
        if not DEFAULTS.has(key):
            continue
        var value = _sanitize(key, patch[key])
        if options[key] != value:
            options[key] = value
            keys.append(key)
    if keys.has("taa") and not keys.has("aa_mode"):
        options["aa_mode"] = "taa" if options["taa"] else "off"
        keys.append("aa_mode")
    if keys.has("aa_mode"):
        options["taa"] = options["aa_mode"] == "taa"
        if not keys.has("taa"):
            keys.append("taa")
    if keys.has("vsync") and not keys.has("vsync_mode"):
        options["vsync_mode"] = "on" if options["vsync"] else "off"
        keys.append("vsync_mode")
    if keys.has("vsync_mode"):
        options["vsync"] = options["vsync_mode"] != "off"
        if not keys.has("vsync"):
            keys.append("vsync")
    if not keep_preset and not keys.has("graphics_preset"):
        for key in PRESETS["high"]:
            if keys.has(key):
                if options["graphics_preset"] != "custom":
                    options["graphics_preset"] = "custom"
                    keys.append("graphics_preset")
                break
    if keys.is_empty():
        return
    _apply_keys(keys)
    dirty = true
    if save_timer != null:
        save_timer.start()
    for key in keys:
        options_changed.emit(key)

func reset_category(index: int) -> void:
    var groups := [GRAPHICS_KEYS, VOLUME_KEYS, ["mouse_sensitivity", "invert_y", "sprint_mode"], ["fov", "camera_motion", "hud_visible"], ["language"]]
    if index < 0 or index >= groups.size():
        return
    var patch := {}
    for key in groups[index]:
        patch[key] = DEFAULTS[key]
    if index == 0 and _display_differs(patch):
        _begin_display_preview()
    _change(patch, true)

func reset_all() -> void:
    if _display_differs(DEFAULTS):
        _begin_display_preview()
    _change(DEFAULTS, true)

func _display_differs(patch: Dictionary) -> bool:
    for key in DISPLAY_KEYS:
        if patch.has(key) and options[key] != patch[key]:
            return true
    return false

func _begin_display_preview() -> void:
    if preview_before.is_empty():
        if DisplayServer.get_name() != "headless":
            preview_screen = DisplayServer.window_get_current_screen()
            preview_window_size = DisplayServer.window_get_size()
            preview_window_position = DisplayServer.window_get_position()
        for key in DISPLAY_KEYS:
            preview_before[key] = options[key]
    preview_timer.start(PREVIEW_SECONDS)
    display_preview_changed.emit(true)

func preview_display(key: String, value: Variant) -> void:
    if not DISPLAY_KEYS.has(key) or _sanitize(key, value) == options[key]:
        return
    _begin_display_preview()
    set_option(key, value)

func confirm_display_preview() -> void:
    if preview_before.is_empty():
        return
    preview_before.clear()
    preview_timer.stop()
    save_options()
    display_preview_changed.emit(false)

func cancel_display_preview() -> void:
    if preview_before.is_empty():
        return
    var before := preview_before.duplicate()
    preview_before.clear()
    preview_timer.stop()
    _change(before, true)
    if DisplayServer.get_name() != "headless" and preview_screen >= 0 and preview_screen < DisplayServer.get_screen_count():
        # The automatic monitor preference (-1) is not a concrete screen.
        # Restore the actual pre-preview monitor and window geometry too.
        DisplayServer.window_set_current_screen(preview_screen)
        if options["window_mode"] == "windowed":
            DisplayServer.window_set_size(preview_window_size)
            DisplayServer.window_set_position(preview_window_position)
        elif options["window_mode"] == "borderless":
            DisplayServer.window_set_size(DisplayServer.screen_get_size(preview_screen))
            DisplayServer.window_set_position(DisplayServer.screen_get_position(preview_screen))
    save_options()
    display_preview_changed.emit(false)

func display_preview_seconds() -> int:
    return ceili(preview_timer.time_left) if preview_timer != null else 0

func available_resolutions() -> Array[String]:
    var values: Array[String] = ["1024x576", "1280x720", "1280x800", "1366x768", "1600x900", "1920x1080", "1920x1200", "2560x1080", "2560x1440", "3440x1440", "3840x2160", "5120x1440"]
    if DisplayServer.get_name() != "headless":
        var screen := _screen_index()
        var native := DisplayServer.screen_get_size(screen)
        var native_label := "%dx%d" % [native.x, native.y]
        if not values.has(native_label):
            values.append(native_label)
        var filtered: Array[String] = []
        for value in values:
            var dim := _dimensions(value)
            if dim.x <= native.x and dim.y <= native.y:
                filtered.append(value)
        values = filtered
    var current := str(options["resolution"])
    if not values.has(current):
        values.append(current)
    return values

func _screen_index() -> int:
    return clampi(int(options["monitor"]) if int(options["monitor"]) >= 0 else DisplayServer.window_get_current_screen(), 0, maxi(0, DisplayServer.get_screen_count() - 1))

func _dimensions(value: String) -> Vector2i:
    var parts := value.split("x")
    if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
        return Vector2i(1280, 720)
    return Vector2i(clampi(int(parts[0]), 640, 7680), clampi(int(parts[1]), 360, 4320))

func _sanitize(key: String, value: Variant) -> Variant:
    match key:
        "language":
            return str(value) if str(value) in ["en", "de"] else "en"
        "window_mode":
            return str(value) if str(value) in ["windowed", "borderless", "fullscreen"] else "windowed"
        "resolution":
            var dimensions := _dimensions(str(value))
            return "%dx%d" % [dimensions.x, dimensions.y]
        "monitor":
            return clampi(int(value), -1, maxi(-1, DisplayServer.get_screen_count() - 1)) if DisplayServer.get_name() != "headless" else maxi(-1, int(value))
        "fps_limit":
            return int(value) if int(value) in [0, 30, 60, 75, 90, 120, 144, 165, 180, 240, 360] else 0
        "menu_fps_limit":
            return int(value) if int(value) in [-1, 0, 30, 60, 120, 144] else -1
        "vsync_mode":
            return str(value) if str(value) in ["off", "on", "adaptive", "mailbox"] else "on"
        "aa_mode":
            return str(value) if str(value) in ["off", "fxaa", "taa", "msaa2", "msaa4", "msaa8"] else "taa"
        "upscaling":
            return str(value) if str(value) in ["bilinear", "fsr1", "fsr2"] else "bilinear"
        "graphics_preset":
            return str(value) if str(value) in ["custom", "low", "medium", "high", "ultra"] else "custom"
        "anisotropy":
            return int(value) if int(value) in [0, 2, 4, 8, 16] else 8
        "texture_filter":
            return str(value) if str(value) in ["original", "bilinear", "trilinear", "anisotropic"] else "original"
        "dynamic_target_fps":
            return int(value) if int(value) in [30, 60, 90, 120, 144] else 60
        "shadow_quality", "shadow_distance", "fog_quality", "reflection_quality", "ssao_quality", "particle_quality":
            return str(value) if str(value) in ["original", "off", "low", "medium", "high", "ultra"] else "original"
        "menu_background":
            return str(value) if str(value) in ["live", "still", "abstract"] else "live"
        "render_scale", "menu_render_scale":
            return clampf(float(value), 0.5, 1.0)
        "image_contrast":
            return clampf(float(value), 0.70, 1.05)
        "brightness":
            return clampf(float(value), 0.7, 1.3)
        "saturation", "bloom_strength":
            return clampf(float(value), 0.0, 1.5)
        "menu_darkness":
            return clampf(float(value), 0.0, 1.5)
        "menu_camera_speed":
            return clampf(float(value), 0.25, 1.5)
        "master_volume", "music_volume", "sfx_volume", "ui_volume":
            return clampf(float(value), 0.0, 1.0)
        "mouse_sensitivity":
            return clampf(float(value), 0.25, 3.0)
        "fov":
            return clampf(float(value), 60.0, 105.0)
        "sprint_mode":
            return str(value) if str(value) in ["hold", "toggle"] else "hold"
    return bool(value) if DEFAULTS[key] is bool else DEFAULTS[key]

func load_options() -> void:
    var config := ConfigFile.new()
    if config.load(FILE_PATH) != OK:
        return
    for key in DEFAULTS:
        options[key] = _sanitize(key, config.get_value("settings", key, DEFAULTS[key]))
    # Preserve preferences from releases before the extended settings schema.
    if not config.has_section_key("settings", "aa_mode"):
        options["aa_mode"] = "taa" if options["taa"] else "off"
    if not config.has_section_key("settings", "vsync_mode"):
        options["vsync_mode"] = "on" if options["vsync"] else "off"
    if not config.has_section_key("settings", "menu_camera_motion"):
        options["menu_camera_motion"] = options["camera_motion"]
    options["taa"] = options["aa_mode"] == "taa"
    options["vsync"] = options["vsync_mode"] != "off"

func save_options() -> void:
    var config := ConfigFile.new()
    for key in DEFAULTS:
        # Never persist an unconfirmed resolution or monitor selection.
        config.set_value("settings", key, preview_before.get(key, options[key]))
    var result := config.save(FILE_PATH)
    if result != OK:
        push_warning("Failed to save settings: %s" % result)
    else:
        dirty = false

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST and dirty:
        save_options()

func _exit_tree() -> void:
    if dirty:
        save_options()

func apply_options() -> void:
    _ensure_audio_buses()
    _apply_keys(DEFAULTS.keys())

func set_menu_context(enabled: bool) -> void:
    menu_context = enabled
    _apply_fps()
    _reset_dynamic_resolution()
    _update_overlay()

func _apply_fps() -> void:
    var cap := int(options["menu_fps_limit"])
    Engine.max_fps = cap if menu_context and cap >= 0 else int(options["fps_limit"])

func _apply_keys(keys: Array) -> void:
    if keys.has("fps_limit") or keys.has("menu_fps_limit"):
        _apply_fps()
    if _intersects(keys, DISPLAY_KEYS):
        _apply_display()
    if keys.has("vsync_mode") and DisplayServer.get_name() != "headless":
        DisplayServer.window_set_vsync_mode(["off", "on", "adaptive", "mailbox"].find(options["vsync_mode"]))
    if _intersects(keys, VIEW_KEYS):
        apply_viewport(get_tree().root, false, keys)
    if _intersects(keys, QUALITY_KEYS):
        _apply_render_quality(keys)
    for key in VOLUME_KEYS:
        if keys.has(key):
            _apply_volume(key)
    if _intersects(keys, ENV_KEYS) or _intersects(keys, NODE_KEYS):
        _apply_scene(get_tree().root, keys)
    if keys.has("dynamic_resolution") or keys.has("dynamic_target_fps") or keys.has("render_scale"):
        _reset_dynamic_resolution()
    if keys.has("fps_display") or keys.has("performance_overlay") or keys.has("dynamic_resolution"):
        _update_overlay()

func _intersects(a: Array, b: Array) -> bool:
    for key in a:
        if b.has(key):
            return true
    return false

func _apply_display() -> void:
    if DisplayServer.get_name() == "headless":
        return
    var screen := _screen_index()
    var mode := str(options["window_mode"])
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, mode == "borderless")
    DisplayServer.window_set_current_screen(screen)
    if mode == "fullscreen":
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    elif mode == "borderless":
        DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
        DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
    else:
        var bounds := DisplayServer.screen_get_usable_rect(screen)
        var dimensions := _dimensions(str(options["resolution"]))
        dimensions = Vector2i(mini(dimensions.x, bounds.size.x), mini(dimensions.y, bounds.size.y))
        DisplayServer.window_set_size(dimensions)
        DisplayServer.window_set_position(bounds.position + (bounds.size - dimensions) / 2)

func apply_viewport(view: Viewport, is_menu: bool = false, keys: Array = VIEW_KEYS) -> void:
    if view == null:
        return
    if keys.has("render_scale") or keys.has("menu_render_scale") or keys.has("upscaling") or keys.has("aa_mode") or keys.has("taa"):
        var mode := str(options["upscaling"])
        var aa := str(options["aa_mode"])
        # FSR2 already supplies temporal AA; don't stack another AA pass.
        view.use_taa = aa == "taa" and mode != "fsr2"
        view.msaa_3d = {"msaa2": 1, "msaa4": 2, "msaa8": 3}.get(aa, 0) if mode != "fsr2" else 0
        view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == "fxaa" and mode != "fsr2" else Viewport.SCREEN_SPACE_AA_DISABLED
        view.scaling_3d_mode = {"bilinear": 0, "fsr1": 1, "fsr2": 2}[mode]
        view.scaling_3d_scale = float(options["menu_render_scale"] if is_menu else options["render_scale"])
    if keys.has("anisotropy"):
        view.anisotropic_filtering_level = [0, 2, 4, 8, 16].find(int(options["anisotropy"]))
    if keys.has("shadow_quality"):
        view.positional_shadow_atlas_size = {"off": 0, "low": 1024, "medium": 2048, "high": 4096, "ultra": 8192, "original": 2048}[options["shadow_quality"]]

func _apply_render_quality(keys: Array) -> void:
    if DisplayServer.get_name() == "headless":
        return
    if keys.has("fog_quality"):
        var fog := str(options["fog_quality"])
        var size: int = {"off": 32, "low": 48, "medium": 64, "high": 128, "ultra": 128, "original": int(ProjectSettings.get_setting("rendering/environment/volumetric_fog/volume_size", 64))}[fog]
        var depth: int = {"off": 32, "low": 32, "medium": 64, "high": 96, "ultra": 128, "original": int(ProjectSettings.get_setting("rendering/environment/volumetric_fog/volume_depth", 64))}[fog]
        RenderingServer.environment_set_volumetric_fog_volume_size(size, depth)
    if keys.has("ssao_quality"):
        var quality := str(options["ssao_quality"])
        var level: int = {"off": 0, "low": 1, "medium": 2, "high": 3, "ultra": 4, "original": int(ProjectSettings.get_setting("rendering/environment/ssao/quality", 2))}[quality]
        var half_size := bool(ProjectSettings.get_setting("rendering/environment/ssao/half_size", false)) if quality == "original" else level <= 1
        RenderingServer.environment_set_ssao_quality(level, half_size, float(ProjectSettings.get_setting("rendering/environment/ssao/adaptive_target", 0.5)), int(ProjectSettings.get_setting("rendering/environment/ssao/blur_passes", 2)), float(ProjectSettings.get_setting("rendering/environment/ssao/fadeout_from", 50.0)), float(ProjectSettings.get_setting("rendering/environment/ssao/fadeout_to", 300.0)))

func apply_environment(env: Environment, keys: Array = ENV_KEYS) -> void:
    if env == null:
        return
    # Remember the authored toggles once; disabled effects stay absent in
    # rooms such as the Backrooms, even on the Ultra preset.
    if not env.has_meta("_quality_base"):
        env.set_meta("_quality_base", {"fog": env.volumetric_fog_enabled, "ssao": env.ssao_enabled, "ssil": env.ssil_enabled, "glow": env.glow_enabled, "glow_strength": env.glow_intensity, "contrast": env.adjustment_contrast, "brightness": env.adjustment_brightness, "saturation": env.adjustment_saturation, "adjustment": env.adjustment_enabled})
    var base: Dictionary = env.get_meta("_quality_base")
    if keys.has("fog_quality"):
        env.volumetric_fog_enabled = bool(base["fog"]) and options["fog_quality"] != "off"
    if keys.has("ssao_quality"):
        env.ssao_enabled = bool(base["ssao"]) and options["ssao_quality"] != "off"
    if keys.has("ssil"):
        env.ssil_enabled = bool(base["ssil"]) and bool(options["ssil"])
    if keys.has("bloom"):
        env.glow_enabled = bool(base["glow"]) and bool(options["bloom"])
    if keys.has("bloom_strength"):
        env.glow_intensity = float(base["glow_strength"]) * float(options["bloom_strength"])
    if keys.has("image_contrast") or keys.has("brightness") or keys.has("saturation"):
        var casino := bool(env.get_meta("_casino_contrast", false))
        env.adjustment_enabled = casino or bool(base["adjustment"]) or not is_equal_approx(float(options["image_contrast"]), 0.85) or not is_equal_approx(float(options["brightness"]), 1.0) or not is_equal_approx(float(options["saturation"]), 1.0)
        env.adjustment_contrast = float(options["image_contrast"]) if casino else float(base["contrast"]) * float(options["image_contrast"]) / 0.85
        env.adjustment_brightness = float(base["brightness"]) * float(options["brightness"])
        env.adjustment_saturation = float(base["saturation"]) * float(options["saturation"])

func reflection_requested(probe: ReflectionProbe, enabled: bool) -> void:
    probe.set_meta("_reflection_requested", enabled)
    _apply_reflection(probe)

func _apply_reflection(probe: ReflectionProbe) -> void:
    if not probe.has_meta("_reflection_base"):
        probe.set_meta("_reflection_base", probe.intensity)
    var requested := bool(probe.get_meta("_reflection_requested", probe.visible))
    var quality := str(options["reflection_quality"])
    probe.visible = requested and quality != "off"
    probe.intensity = float(probe.get_meta("_reflection_base")) * (0.65 if quality == "low" else 1.0)
    # Low quality removes the more expensive west-wing capture entirely.
    if quality == "low" and probe.name == "WestWingReflection":
        probe.visible = false

func _apply_node(node: Node, keys: Array) -> void:
    if node is WorldEnvironment and _intersects(keys, ENV_KEYS):
        if not node.has_meta("_return_blend"):
            apply_environment(node.environment, keys)
    elif node is Light3D and (keys.has("shadow_quality") or keys.has("shadow_distance")):
        var light := node as Light3D
        if not light.has_meta("_shadow_base"):
            light.set_meta("_shadow_base", [light.shadow_enabled, light.distance_fade_enabled, light.distance_fade_shadow, light.distance_fade_begin, light.distance_fade_length])
        var original: Array = light.get_meta("_shadow_base")
        if keys.has("shadow_quality"):
            light.shadow_enabled = bool(original[0]) and options["shadow_quality"] != "off" and not light.has_meta("_showcase_no_shadow")
        if keys.has("shadow_distance"):
            var distance := str(options["shadow_distance"])
            light.distance_fade_enabled = bool(original[1]) or distance != "original"
            light.distance_fade_shadow = float(original[2]) if distance == "original" else float({"off": 0, "low": 12, "medium": 20, "high": 38, "ultra": 48}[distance])
            light.distance_fade_begin = float(original[3]) if distance == "original" else maxf(light.distance_fade_shadow + 8.0, float(original[3]))
            light.distance_fade_length = float(original[4])
    elif (node is CPUParticles3D or node is GPUParticles3D) and keys.has("particle_quality"):
        if not str(node.name).begins_with("AmbientDust"):
            return
        if not node.has_meta("_particle_base"):
            node.set_meta("_particle_base", [node.amount, node.emitting])
        var original: Array = node.get_meta("_particle_base")
        var level := str(options["particle_quality"])
        node.amount = maxi(1, roundi(float(original[0]) * (0.25 if level == "low" else (0.5 if level == "medium" else 1.0))))
        node.emitting = bool(original[1]) and level != "off"
    elif node is ReflectionProbe and keys.has("reflection_quality") and node.has_meta("_reflection_requested"):
        _apply_reflection(node)
    elif node is MeshInstance3D and keys.has("texture_filter"):
        _apply_mesh_filter(node as MeshInstance3D)

func _apply_scene(node: Node, keys: Array) -> void:
    if node == self or node.has_meta("_baking_room"):
        return
    _apply_node(node, keys)
    for child in node.get_children():
        _apply_scene(child, keys)

func _on_node_added(node: Node) -> void:
    if node is WorldEnvironment or node is Light3D or node is CPUParticles3D or node is GPUParticles3D or (node is MeshInstance3D and options["texture_filter"] != "original"):
        # Newly staged nodes can still be configured in their parent's ready.
        call_deferred("_apply_new_node", weakref(node))

func _apply_new_node(reference: WeakRef) -> void:
    var node = reference.get_ref()
    if is_instance_valid(node) and node.is_inside_tree():
        var ancestor: Node = node
        while ancestor != null:
            if ancestor.has_meta("_baking_room"):
                return
            ancestor = ancestor.get_parent()
        _apply_node(node, ENV_KEYS + NODE_KEYS)

func _apply_mesh_filter(mesh: MeshInstance3D) -> void:
    # Apply real Godot sampler modes to standard 3D materials. Shader
    # materials keep their authored sampler settings; no texture is reimported.
    if mesh.material_override != null:
        _apply_material_filter(mesh.material_override)
    elif mesh.mesh != null:
        for index in range(mesh.mesh.get_surface_count()):
            _apply_material_filter(mesh.get_active_material(index))
    if mesh.material_overlay != null:
        _apply_material_filter(mesh.material_overlay)

func _apply_material_filter(material: Material) -> void:
    if not material is BaseMaterial3D:
        return
    var mat := material as BaseMaterial3D
    var mode := str(options["texture_filter"])
    if mode == "original":
        if mat.has_meta("_original_sampler"):
            mat.texture_filter = int(mat.get_meta("_original_sampler"))
        return
    if not mat.has_meta("_original_sampler"):
        mat.set_meta("_original_sampler", mat.texture_filter)
    var selected: int = {"bilinear": BaseMaterial3D.TEXTURE_FILTER_LINEAR, "trilinear": BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "anisotropic": BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC}[mode]
    if mat.texture_filter != selected:
        mat.texture_filter = selected

func _reset_dynamic_resolution() -> void:
    dynamic_elapsed = 0.0
    dynamic_frames = 0
    dynamic_bad_windows = 0
    dynamic_good_windows = 0
    get_tree().root.scaling_3d_scale = float(options["render_scale"])

func _dynamic_step(current: float, measured_fps: float, target: float) -> float:
    # Multiple consecutive two-second measurements avoid adapting to
    # single streaming spikes. Frame-rate feedback is not GPU timing.
    dynamic_bad_windows = dynamic_bad_windows + 1 if measured_fps < target * 0.90 else 0
    dynamic_good_windows = dynamic_good_windows + 1 if measured_fps >= target * 0.98 else 0
    if dynamic_bad_windows >= 2:
        dynamic_bad_windows = 0
        return maxf(0.5, current - 0.05)
    if dynamic_good_windows >= 3:
        dynamic_good_windows = 0
        return minf(float(options["render_scale"]), current + 0.05)
    return current

func _sample_dynamic_resolution(delta: float) -> void:
    if menu_context or get_tree().paused or get_tree().root.get_camera_3d() == null or DisplayServer.get_name() == "headless":
        dynamic_elapsed = 0.0
        dynamic_frames = 0
        dynamic_bad_windows = 0
        dynamic_good_windows = 0
        return
    dynamic_elapsed += delta
    dynamic_frames += 1
    if dynamic_elapsed < 2.0:
        return
    var target := float(options["dynamic_target_fps"])
    if Engine.max_fps > 0:
        target = minf(target, float(Engine.max_fps))
    if options["vsync_mode"] != "off":
        var refresh := DisplayServer.screen_get_refresh_rate(_screen_index())
        if refresh > 0:
            target = minf(target, refresh)
    var view := get_tree().root
    var scale := _dynamic_step(view.scaling_3d_scale, float(dynamic_frames) / dynamic_elapsed, target)
    if not is_equal_approx(scale, view.scaling_3d_scale):
        view.scaling_3d_scale = scale
    dynamic_elapsed = 0.0
    dynamic_frames = 0

func _ensure_audio_buses() -> void:
    for bus_name in ["MUSIC", "SFX", "UI"]:
        if AudioServer.get_bus_index(bus_name) == -1:
            var idx := AudioServer.get_bus_count()
            AudioServer.add_bus(idx)
            AudioServer.set_bus_name(idx, bus_name)

func _apply_volume(key: String) -> void:
    var bus_name: String = "Master" if key == "master_volume" else key.trim_suffix("_volume").to_upper()
    var idx := AudioServer.get_bus_index(bus_name)
    if idx >= 0:
        var volume := float(options[key])
        AudioServer.set_bus_mute(idx, volume <= 0.0001)
        AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.0001)))

func _update_overlay() -> void:
    var enabled := bool(options["fps_display"]) or bool(options["performance_overlay"])
    if enabled and not is_instance_valid(overlay):
        overlay = CanvasLayer.new()
        overlay.layer = 95
        add_child(overlay)
        perf_label = Label.new()
        perf_label.position = Vector2(12, 8)
        perf_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        perf_label.add_theme_font_size_override("font_size", 15)
        perf_label.add_theme_color_override("font_outline_color", Color.BLACK)
        perf_label.add_theme_constant_override("outline_size", 5)
        overlay.add_child(perf_label)
    if is_instance_valid(overlay):
        overlay.visible = enabled
    set_process(enabled or bool(options["dynamic_resolution"]))

func _process(delta: float) -> void:
    if options["dynamic_resolution"]:
        _sample_dynamic_resolution(delta)
    if not bool(options["fps_display"]) and not bool(options["performance_overlay"]):
        return
    perf_elapsed += delta
    perf_worst = maxf(perf_worst, delta * 1000.0)
    if perf_elapsed < 0.5:
        return
    if is_instance_valid(perf_label):
        var message := "%d FPS" % Engine.get_frames_per_second()
        if options["performance_overlay"]:
            message += " | max %.1f ms | Draws %d | Objects %d | 3D %.0f%%" % [perf_worst, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), 100.0 * float(options["menu_render_scale"] if menu_context else get_tree().root.scaling_3d_scale)]
        perf_label.text = message
    perf_elapsed = 0.0
    perf_worst = 0.0
