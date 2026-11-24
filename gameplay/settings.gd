extends Node
## Persistent preferences; display previews are transactional and slider writes
## are debounced. Renderer quality never edits an authored scene on disk.
signal options_changed(key: String)
signal display_preview_changed(active: bool)

const Controls = preload("res://gameplay/input_bindings.gd")
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
    "hud_visible": true,
    "key_bindings": Controls.DEFAULTS,
    "mouse_vertical_multiplier": 1.0,
    "invert_x": false,
    "mouse_smoothing": 0.0,
    "controller_enabled": true,
    "controller_sensitivity": 1.0,
    "controller_deadzone": 0.20,
    "controller_vibration": 0.0,
    "ambience_volume": 1.0,
    "footstep_volume": 1.0,
    "cabinet_volume": 1.0,
    "horror_volume": 1.0,
    "pressure_volume": 1.0,
    "reverb_mode": "normal",
    "audio_dynamic_range": "normal",
    "audio_device": "Default",
    "mute_unfocused": false,
    "mono_audio": false,
    "audio_balance": 0.0,
    "head_bob": 1.0,
    "breathing_motion": 1.0,
    "camera_sway": 1.0,
    "crosshair": "off",
    "crosshair_size": 1.0,
    "crosshair_color": "white",
    "interaction_hints": true,
    "tutorial_hints": true,
    "skip_tutorial": false,
    "skip_creator_intro": false,
    "pause_unfocused": false,
    "confirm_quit": false,
    "confirm_new_run": true,
    "loading_motion": true,
    "reduce_light_motion": false,
    "soft_light_transitions": false,
    "reduced_motion": false,
    "reduced_menu_motion": false,
    "ui_scale": 1.0,
    "ui_text_size": "normal",
    "high_contrast_ui": false,
    "sound_captions": false,
    "caption_size": "normal",
    "caption_background": 0.7,
    "color_assistance": "off",
    "door_symbols": false,
    "reduced_horror_audio": false,
    "auto_updates": true
}
const PRESETS := {
    "low": {
        "render_scale": 0.67,
        "upscaling": "fsr1",
        "aa_mode": "fxaa",
        "anisotropy": 2,
        "texture_filter": "trilinear",
        "voxel_gi": false,
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
        "texture_filter": "trilinear",
        "voxel_gi": true,
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
        "texture_filter": "original",
        "voxel_gi": true,
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
        "voxel_gi": true,
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
const VOLUME_KEYS := ["master_volume", "music_volume", "sfx_volume", "ui_volume", "ambience_volume", "footstep_volume", "cabinet_volume", "horror_volume", "pressure_volume"]
const AUDIO_KEYS := ["master_volume", "music_volume", "sfx_volume", "ui_volume", "ambience_volume", "footstep_volume", "cabinet_volume", "horror_volume", "pressure_volume", "reverb_mode", "audio_dynamic_range", "audio_device", "mute_unfocused", "mono_audio", "audio_balance"]
const CONTROL_KEYS := ["mouse_sensitivity", "mouse_vertical_multiplier", "invert_y", "invert_x", "mouse_smoothing", "sprint_mode", "key_bindings", "controller_enabled", "controller_sensitivity", "controller_deadzone", "controller_vibration"]
const GAMEPLAY_KEYS := ["fov", "camera_motion", "head_bob", "breathing_motion", "camera_sway", "hud_visible", "crosshair", "crosshair_size", "crosshair_color", "interaction_hints", "tutorial_hints", "skip_tutorial", "skip_creator_intro", "pause_unfocused", "confirm_quit", "confirm_new_run", "loading_motion"]
const ACCESS_KEYS := ["reduce_light_motion", "soft_light_transitions", "reduced_motion", "reduced_menu_motion", "ui_scale", "ui_text_size", "high_contrast_ui", "sound_captions", "caption_size", "caption_background", "color_assistance", "door_symbols", "reduced_horror_audio"]
const UI_KEYS := ["ui_text_size", "high_contrast_ui", "color_assistance"]
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
var filtered_materials: Dictionary = {}
var _material_registrations := 0
# IDs do not retain retired rooms. Track only graphics-relevant nodes.
var _quality_nodes: Dictionary = {"environment": {}, "light": {}, "particle": {}, "reflection": {}, "mesh": {}}
var _pending_meshes: Dictionary = {}
var _mesh_flush_queued := false
var dirty := false
var audio_unfocused := false
var master_effects: Dictionary = {}
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
    _index_quality_tree(get_tree().root)
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)
    apply_options()
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
    var groups := [GRAPHICS_KEYS, AUDIO_KEYS, CONTROL_KEYS, GAMEPLAY_KEYS, ["language", "auto_updates"], ACCESS_KEYS]
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
        "ui_scale":
            return clampf(float(value), 0.75, 1.5)
        "crosshair_size":
            return clampf(float(value), 0.5, 2.0)
        "crosshair":
            return str(value) if str(value) in ["off", "dot", "cross"] else "off"
        "crosshair_color":
            return str(value) if str(value) in ["white", "yellow", "cyan", "green", "black"] else "white"
        "ui_text_size", "caption_size":
            return str(value) if str(value) in ["small", "normal", "large", "very_large"] else "normal"
        "color_assistance":
            return str(value) if str(value) in ["off", "protan", "deutan", "tritan"] else "off"
        "key_bindings":
            return Controls.sanitize(value)
        "mouse_vertical_multiplier", "controller_sensitivity":
            return clampf(float(value), 0.25, 3.0)
        "controller_deadzone":
            return clampf(float(value), 0.05, 0.45)
        "audio_balance":
            return clampf(float(value), -1.0, 1.0)
        "reverb_mode":
            return str(value) if str(value) in ["off", "reduced", "normal"] else "normal"
        "audio_dynamic_range":
            return str(value) if str(value) in ["night", "normal", "full"] else "normal"
        "audio_device":
            return str(value).left(256)
        "master_volume", "music_volume", "sfx_volume", "ui_volume", "ambience_volume", "footstep_volume", "cabinet_volume", "horror_volume", "pressure_volume", "mouse_smoothing", "controller_vibration", "head_bob", "breathing_motion", "camera_sway", "caption_background":
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
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
        audio_unfocused = what == NOTIFICATION_APPLICATION_FOCUS_OUT
        _apply_volume("master_volume")

func _exit_tree() -> void:
    if dirty:
        save_options()
    for name in master_effects.keys():
        _remove_master_effect(name)

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
    if keys.has("mute_unfocused"):
        _apply_volume("master_volume")
    if keys.has("reduced_horror_audio"):
        _apply_volume("horror_volume")
        _apply_volume("pressure_volume")
    if keys.has("ui_scale"):
        get_tree().root.content_scale_factor = float(options["ui_scale"])
    if _intersects(keys, UI_KEYS):
        _apply_ui_tree(get_tree().root)
    if keys.has("audio_device") and DisplayServer.get_name() != "headless":
        var device := str(options["audio_device"])
        AudioServer.output_device = device if device in AudioServer.get_output_device_list() else "Default"
    if _intersects(keys, ["mono_audio", "audio_balance", "audio_dynamic_range"]):
        _apply_audio_effects()
    if _intersects(keys, ["key_bindings", "controller_enabled", "controller_deadzone"]):
        Controls.apply(options["key_bindings"], bool(options["controller_enabled"]), float(options["controller_deadzone"]))
    if keys.has("texture_filter"):
        _refresh_material_filters()
    if _intersects(keys, ENV_KEYS) or _intersects(keys, NODE_KEYS):
        _apply_registered_quality(keys)
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

func _apply_node(node: Node, keys: Array, seen_materials: Dictionary = {}) -> void:
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
            # Quality may drop shadows, not the actual illumination (which
            # is also a gameplay clue). Keep authored light-fade distance,
            # or a distant bound for lights with no authored fade.
            light.distance_fade_begin = float(original[3]) if distance == "original" or bool(original[1]) else 10000.0
            light.distance_fade_length = float(original[4])
    elif (node is CPUParticles3D or node is GPUParticles3D) and keys.has("particle_quality"):
        if not str(node.name).begins_with("AmbientDust"):
            return
        if not node.has_meta("_particle_base"):
            node.set_meta("_particle_base", [node.amount, node.emitting])
        var original: Array = node.get_meta("_particle_base")
        var level := str(options["particle_quality"])
        var amount := maxi(1, roundi(float(original[0]) * (0.25 if level == "low" else (0.5 if level == "medium" else 1.0))))
        var emitting := bool(original[1]) and level != "off"
        # Avoid resetting a live emitter when its budget is unchanged.
        if node.amount != amount:
            node.amount = amount
        if node.emitting != emitting:
            node.emitting = emitting
    elif node is ReflectionProbe and keys.has("reflection_quality") and node.has_meta("_reflection_requested"):
        _apply_reflection(node)
    elif node is MeshInstance3D and keys.has("texture_filter"):
        _apply_mesh_filter(node as MeshInstance3D, seen_materials)

func _apply_scene(node: Node, keys: Array) -> void:
    if node == self or node.has_meta("_baking_room"):
        return
    _apply_node(node, keys, {})
    for child in node.get_children():
        _apply_scene(child, keys)

func _quality_kind(node: Node) -> String:
    if node is WorldEnvironment:
        return "environment"
    if node is Light3D:
        return "light"
    if node is CPUParticles3D or node is GPUParticles3D:
        return "particle"
    if node is ReflectionProbe:
        return "reflection"
    if node is MeshInstance3D:
        return "mesh"
    return ""

func _register_quality_node(node: Node) -> String:
    var kind := _quality_kind(node)
    if not kind.is_empty():
        var bucket: Dictionary = _quality_nodes[kind]
        bucket[node.get_instance_id()] = true
    return kind

func _index_quality_tree(node: Node) -> void:
    _register_quality_node(node)
    for child in node.get_children():
        _index_quality_tree(child)

func _quality_eligible(node: Node) -> bool:
    if not is_instance_valid(node) or not node.is_inside_tree():
        return false
    var ancestor := node
    while ancestor != null:
        if ancestor == self or ancestor.has_meta("_baking_room"):
            return false
        ancestor = ancestor.get_parent()
    return true

func _apply_registered_quality(keys: Array) -> void:
    var kinds: Array[String] = []
    if _intersects(keys, ENV_KEYS):
        kinds.append("environment")
    if keys.has("shadow_quality") or keys.has("shadow_distance"):
        kinds.append("light")
    if keys.has("particle_quality"):
        kinds.append("particle")
    if keys.has("reflection_quality"):
        kinds.append("reflection")
    if keys.has("texture_filter"):
        kinds.append("mesh")
    var seen: Dictionary = {}
    for kind in kinds:
        var bucket: Dictionary = _quality_nodes[kind]
        for id in bucket.keys():
            var node := instance_from_id(int(id)) as Node
            if not is_instance_valid(node):
                bucket.erase(id)
            elif _quality_eligible(node):
                _apply_node(node, keys, seen)

func _on_node_added(node: Node) -> void:
    var kind := _register_quality_node(node)
    # Keep UI, lighting and environment initialization ordering unchanged.
    if node is Control and (options["ui_text_size"] != "normal" or options["high_contrast_ui"] or options["color_assistance"] != "off"):
        call_deferred("_apply_new_ui", weakref(node))
    if kind in ["environment", "light", "particle"]:
        call_deferred("_apply_new_node", weakref(node))
    elif kind == "mesh" and options["texture_filter"] != "original":
        _pending_meshes[node.get_instance_id()] = true
        if not _mesh_flush_queued:
            _mesh_flush_queued = true
            call_deferred("_flush_pending_meshes")

func _on_node_removed(node: Node) -> void:
    var kind := _quality_kind(node)
    if not kind.is_empty():
        var bucket: Dictionary = _quality_nodes[kind]
        bucket.erase(node.get_instance_id())
    _pending_meshes.erase(node.get_instance_id())

func _flush_pending_meshes() -> void:
    _mesh_flush_queued = false
    var pending := _pending_meshes
    _pending_meshes = {}
    var seen: Dictionary = {}
    for id in pending:
        var mesh := instance_from_id(int(id)) as MeshInstance3D
        if _quality_eligible(mesh):
            _apply_mesh_filter(mesh, seen)

func _apply_new_node(reference: WeakRef) -> void:
    var node := reference.get_ref() as Node
    if _quality_eligible(node):
        _apply_node(node, ENV_KEYS + NODE_KEYS, {})

func _apply_mesh_filter(mesh: MeshInstance3D, seen: Dictionary = {}) -> void:
    # Apply real Godot sampler modes to standard 3D materials. Shader
    # materials keep their authored sampler settings; no texture is reimported.
    if mesh.material_override != null:
        _filter_once(mesh.material_override, seen)
    elif mesh.mesh != null:
        for index in range(mesh.mesh.get_surface_count()):
            _filter_once(mesh.get_active_material(index), seen)
    if mesh.material_overlay != null:
        _filter_once(mesh.material_overlay, seen)

func _filter_once(material: Material, seen: Dictionary) -> void:
    if material == null:
        return
    var id := material.get_instance_id()
    if seen.has(id):
        return
    seen[id] = true
    _apply_material_filter(material)

func _apply_material_filter(material: Material) -> void:
    if not material is BaseMaterial3D:
        return
    var mat := material as BaseMaterial3D
    var mode := str(options["texture_filter"])
    if mode == "original":
        if mat.has_meta("_original_sampler") and mat.texture_filter != int(mat.get_meta("_original_sampler")):
            mat.texture_filter = int(mat.get_meta("_original_sampler"))
        return
    if not mat.has_meta("_original_sampler"):
        mat.set_meta("_original_sampler", mat.texture_filter)
    var id := mat.get_instance_id()
    if not filtered_materials.has(id) or (filtered_materials[id] as WeakRef).get_ref() != mat:
        filtered_materials[id] = weakref(mat)
        _material_registrations += 1
        # Streamed rooms may contain unique material instances. WeakRef does
        # not retain them, but dead dictionary entries must also be pruned.
        if _material_registrations >= 256:
            _material_registrations = 0
            _prune_filtered_materials()
    var selected: int = {"bilinear": BaseMaterial3D.TEXTURE_FILTER_LINEAR, "trilinear": BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "anisotropic": BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC}[mode]
    if mat.texture_filter != selected:
        mat.texture_filter = selected

func _prune_filtered_materials() -> void:
    for id in filtered_materials.keys():
        var reference: WeakRef = filtered_materials[id]
        if not is_instance_valid(reference.get_ref()):
            filtered_materials.erase(id)

func _refresh_material_filters() -> void:
    # Packed scenes and imported material resources can be cached even when
    # their nodes are gone. Restore all still-live modified resources, not
    # just materials belonging to the currently visible scene.
    for id in filtered_materials.keys():
        var reference: WeakRef = filtered_materials[id]
        var material = reference.get_ref()
        if not is_instance_valid(material):
            filtered_materials.erase(id)
        else:
            _apply_material_filter(material)
    if options["texture_filter"] == "original":
        filtered_materials.clear()

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
    for bus_name in ["MUSIC", "SFX", "UI", "AMBIENCE", "FOOTSTEP", "CABINET", "HORROR", "PRESSURE"]:
        if AudioServer.get_bus_index(bus_name) == -1:
            var idx := AudioServer.get_bus_count()
            AudioServer.add_bus(idx)
            AudioServer.set_bus_name(idx, bus_name)
    for name in ["AMBIENCE", "HORROR", "PRESSURE"]:
        AudioServer.set_bus_send(AudioServer.get_bus_index(name), "SFX")

func _apply_volume(key: String) -> void:
    var bus_name: String = "Master" if key == "master_volume" else key.trim_suffix("_volume").to_upper()
    var idx := AudioServer.get_bus_index(bus_name)
    if idx >= 0:
        var volume := float(options[key])
        if key in ["horror_volume", "pressure_volume"] and bool(options["reduced_horror_audio"]):
            volume *= 0.35
        AudioServer.set_bus_mute(idx, volume <= 0.0001 or (key == "master_volume" and audio_unfocused and bool(options["mute_unfocused"])))
        AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.0001)))

func _apply_new_ui(reference: WeakRef) -> void:
    var node = reference.get_ref()
    if is_instance_valid(node) and node.is_inside_tree():
        _apply_ui_node(node)

func _apply_ui_tree(node: Node) -> void:
    if node is SubViewport:
        return
    if node is Control:
        _apply_ui_node(node)
    for child in node.get_children():
        _apply_ui_tree(child)

func _apply_ui_node(node: Control) -> void:
    if node.get_viewport() is SubViewport or node.has_meta("_independent_caption"):
        return
    if options["ui_text_size"] == "normal" and not options["high_contrast_ui"] and options["color_assistance"] == "off" and not node.has_meta("_accessible_font") and not node.has_meta("_accessible_panel") and not node.has_meta("_accessible_icon"):
        return
    if node is Label or node is Button or node is LineEdit or node is CheckButton:
        if not node.has_meta("_accessible_font"):
            node.set_meta("_accessible_font", [node.has_theme_font_size_override("font_size"), node.get_theme_font_size("font_size")])
        var base: Array = node.get_meta("_accessible_font")
        var multiplier: float = {"small": 0.90, "normal": 1.0, "large": 1.15, "very_large": 1.30}[options["ui_text_size"]]
        if multiplier == 1.0 and not bool(base[0]):
            node.remove_theme_font_size_override("font_size")
        else:
            node.add_theme_font_size_override("font_size", maxi(10, roundi(float(base[1]) * multiplier)))
        var colors := ["font_color", "font_hover_color", "font_pressed_color"] if node is Button else ["font_color"]
        for key in colors:
            if not node.has_meta("_accessible_" + key):
                node.set_meta("_accessible_" + key, [node.has_theme_color_override(key), node.get_theme_color(key)])
            var original: Array = node.get_meta("_accessible_" + key)
            if options["high_contrast_ui"]:
                node.add_theme_color_override(key, Color.WHITE)
            elif bool(original[0]):
                node.add_theme_color_override(key, original[1])
            else:
                node.remove_theme_color_override(key)
    if node is Button and node.has_meta("_premium_accent"):
        var accent := str(node.get_meta("_premium_accent"))
        if accent in ["red", "green"]:
            if not node.has_meta("_accessible_icon"):
                node.set_meta("_accessible_icon", node.get_theme_color("icon_normal_color"))
            var palette := str(options["color_assistance"])
            var color: Color = node.get_meta("_accessible_icon")
            if palette in ["protan", "deutan"]:
                color = Color("#7bbdfb") if accent == "green" else Color("#ffbd75")
            elif palette == "tritan":
                color = Color("#8be0b0") if accent == "green" else Color("#ff9fa6")
            node.add_theme_color_override("icon_normal_color", color)
    if node is PanelContainer:
        if not node.has_meta("_accessible_panel"):
            node.set_meta("_accessible_panel", [node.has_theme_stylebox_override("panel"), node.get_theme_stylebox("panel")])
        var original: Array = node.get_meta("_accessible_panel")
        if options["high_contrast_ui"] and original[1] is StyleBoxFlat:
            var panel := (original[1] as StyleBoxFlat).duplicate() as StyleBoxFlat
            panel.bg_color = Color("#06090f")
            panel.border_color = Color("#e9dfc3")
            panel.set_border_width_all(2)
            node.add_theme_stylebox_override("panel", panel)
        elif bool(original[0]):
            node.add_theme_stylebox_override("panel", original[1])
        else:
            node.remove_theme_stylebox_override("panel")

func _remove_master_effect(name: String) -> void:
    if not master_effects.has(name):
        return
    var effect: AudioEffect = master_effects[name]
    for index in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
        if AudioServer.get_bus_effect(0, index) == effect:
            AudioServer.remove_bus_effect(0, index)
    master_effects.erase(name)

func _apply_audio_effects() -> void:
    if not bool(options["mono_audio"]):
        _remove_master_effect("mono")
    elif not master_effects.has("mono"):
        var mono := AudioEffectStereoEnhance.new()
        mono.pan_pullout = 0.0
        master_effects["mono"] = mono
        AudioServer.add_bus_effect(0, mono)
    if is_zero_approx(float(options["audio_balance"])):
        _remove_master_effect("balance")
    else:
        if not master_effects.has("balance"):
            var balance := AudioEffectPanner.new()
            master_effects["balance"] = balance
            AudioServer.add_bus_effect(0, balance)
        (master_effects["balance"] as AudioEffectPanner).pan = float(options["audio_balance"])
    if options["audio_dynamic_range"] != "night":
        _remove_master_effect("compression")
    elif not master_effects.has("compression"):
        var compressor := AudioEffectCompressor.new()
        compressor.threshold = -24.0
        compressor.ratio = 4.0
        compressor.gain = 3.0
        master_effects["compression"] = compressor
        AudioServer.add_bus_effect(0, compressor)

func rebind(action: String, slot: int, code: int) -> String:
    if not Controls.ACTIONS.has(action) or slot not in [0, 1] or not Controls.valid(code, action):
        return "reserved"
    var bindings: Dictionary = options["key_bindings"].duplicate(true)
    for other in Controls.ACTIONS:
        for index in range(2):
            if code != 0 and int(bindings[other][index]) == code and (other != action or index != slot):
                return other
    bindings[action][slot] = code
    if bindings[action] == [0, 0]:
        return "required"
    set_option("key_bindings", bindings)
    return ""

func _input(event: InputEvent) -> void:
    var old := bool(get_meta("_using_gamepad", false))
    var pad := old
    if event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
        pad = true
    elif event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed or event is InputEventMouseMotion and event.relative.length() > 3.0:
        pad = false
    if old != pad:
        set_meta("_using_gamepad", pad)
        options_changed.emit("input_device")

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
        if perf_label.text != message:
            perf_label.text = message
    perf_elapsed = 0.0
    perf_worst = 0.0
