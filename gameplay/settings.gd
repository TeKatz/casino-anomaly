extends Node
## Persistent, applied user preferences. Gameplay state is saved separately.
signal options_changed(key: String)

const FILE_PATH := "user://casino_settings.cfg"
const DEFAULTS := {
    "window_mode": "windowed",
    "resolution": "1280x720",
    "vsync": true,
    "fps_limit": 0,
    "render_scale": 1.0,
    "taa": true,
    "master_volume": 1.0,
    "music_volume": 0.8,
    "sfx_volume": 0.9,
    "ui_volume": 0.9,
    "mouse_sensitivity": 1.0,
    "invert_y": false,
    "fov": 75.0,
    "camera_motion": true,
    "sprint_mode": "hold",
    "hud_visible": true
}

var options: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
    load_options()
    apply_options()


func get_option(key: String) -> Variant:
    return options.get(key, DEFAULTS.get(key))


func set_option(key: String, value: Variant) -> void:
    if not DEFAULTS.has(key):
        push_warning("Unknown setting: " + key)
        return
    options[key] = _sanitize(key, value)
    apply_options()
    save_options()
    options_changed.emit(key)


func _sanitize(key: String, value: Variant) -> Variant:
    match key:
        "window_mode":
            return str(value) if str(value) in ["windowed", "borderless", "fullscreen"] else "windowed"
        "resolution":
            return str(value) if str(value) in ["1280x720", "1600x900", "1920x1080", "2560x1440"] else "1280x720"
        "fps_limit":
            return int(value) if int(value) in [0, 30, 60, 90, 120, 144, 240] else 0
        "render_scale":
            return clampf(float(value), 0.5, 1.0)
        "master_volume", "music_volume", "sfx_volume", "ui_volume":
            return clampf(float(value), 0.0, 1.0)
        "mouse_sensitivity":
            return clampf(float(value), 0.25, 3.0)
        "fov":
            return clampf(float(value), 60.0, 105.0)
        "sprint_mode":
            return str(value) if str(value) in ["hold", "toggle"] else "hold"
        "vsync", "taa", "invert_y", "camera_motion", "hud_visible":
            return bool(value)
    return value


func load_options() -> void:
    var config := ConfigFile.new()
    if config.load(FILE_PATH) != OK:
        return
    for key in DEFAULTS:
        options[key] = _sanitize(key, config.get_value("settings", key, DEFAULTS[key]))


func save_options() -> void:
    var config := ConfigFile.new()
    for key in DEFAULTS:
        config.set_value("settings", key, options[key])
    var result := config.save(FILE_PATH)
    if result != OK:
        push_warning("Failed to save settings: %s" % result)


func apply_options() -> void:
    Engine.max_fps = int(get_option("fps_limit"))
    if DisplayServer.get_name() != "headless":
        var mode := str(get_option("window_mode"))
        match mode:
            "fullscreen":
                DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
            "borderless":
                DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
                DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
            _:
                DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
                DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
        if mode == "windowed":
            var dimensions: PackedStringArray = str(get_option("resolution")).split("x")
            DisplayServer.window_set_size(Vector2i(int(dimensions[0]), int(dimensions[1])))
        DisplayServer.window_set_vsync_mode(
            DisplayServer.VSYNC_ENABLED if bool(get_option("vsync")) else DisplayServer.VSYNC_DISABLED
        )
    var viewport := get_tree().root
    viewport.scaling_3d_scale = float(get_option("render_scale"))
    viewport.use_taa = bool(get_option("taa"))
    _ensure_audio_buses()
    for volume_key in ["master_volume", "music_volume", "sfx_volume", "ui_volume"]:
        var bus_name: String = "Master" if volume_key == "master_volume" else str(volume_key).trim_suffix("_volume").to_upper()
        var bus_idx := AudioServer.get_bus_index(bus_name)
        if bus_idx >= 0:
            var volume := float(get_option(volume_key))
            AudioServer.set_bus_mute(bus_idx, volume <= 0.0001)
            AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(volume, 0.0001)))


func _ensure_audio_buses() -> void:
    for bus_name in ["MUSIC", "SFX", "UI"]:
        if AudioServer.get_bus_index(bus_name) == -1:
            var idx := AudioServer.get_bus_count()
            AudioServer.add_bus(idx)
            AudioServer.set_bus_name(idx, bus_name)
