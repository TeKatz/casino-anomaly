extends Node
## Persistent 2D audio controller. The menu is MUSIC only; room tone begins
## with a first-person Player and keeps playing through in-world room handoffs.
const MENU_PATH := "res://audio/hmm_menu_seamless.ogg"
const ROOM_PATH := "res://audio/casino_room_tone_seamless.ogg"
const MENU_DB := -7.0
const ROOM_DB := -2.0
const FADE_SECONDS := 0.45
const ImmersionSynth = preload("res://gameplay/immersion_synth.gd")

var menu_player: AudioStreamPlayer
var room_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer
var pressure_player: AudioStreamPlayer
var world_reverb: AudioEffectReverb
var procedural_loops: Dictionary = {}
var step_sounds: Dictionary = {}
var steps_played := 0
var corridor_target := false
var _created_world_bus := false
var menu_enabled := false
var world_ambience_enabled := false
var backrooms_mode := false
var _fade: Tween
var _ambience_fade: Tween
var _settings: Node
var _loop_state: Node


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _settings = get_node_or_null("/root/GameSettings")
    _loop_state = get_node_or_null("/root/LoopState")
    set_process(world_ambience_enabled)
    menu_player = AudioStreamPlayer.new()
    menu_player.name = "MenuMusic"
    menu_player.bus = "MUSIC"
    menu_player.process_mode = Node.PROCESS_MODE_ALWAYS
    menu_player.volume_db = -60.0
    add_child(menu_player)

    room_player = AudioStreamPlayer.new()
    room_player.name = "ContinuousRoomTone"
    room_player.bus = "AMBIENCE"
    room_player.process_mode = Node.PROCESS_MODE_ALWAYS
    room_player.volume_db = ROOM_DB
    add_child(room_player)

    menu_player.stream = _load_loop(MENU_PATH)
    room_player.stream = _load_loop(ROOM_PATH)
    _prepare_immersion()
    # Startup is the main menu: ambient noise must not play until the player
    # physically enters a first-person world. An autoload alone is not enough.


func _load_loop(path: String) -> AudioStreamOggVorbis:
    if not ResourceLoader.exists(path):
        # The verified, processed audio ZIP has not been uploaded/imported yet.
        # Avoid breaking the first playable game before that one-time step.
        return null
    var loaded := load(path) as AudioStreamOggVorbis
    if loaded == null:
        push_warning("Casino audio is not an Ogg Vorbis stream: " + path)
        return null
    loaded.loop = true
    loaded.loop_offset = 0.0
    return loaded


func set_world_ambience_enabled(enabled: bool) -> void:
    # Called from the first-person Player on entering the world, and from
    # the main menu on return. Never restart ambience during hall streaming.
    if world_ambience_enabled == enabled:
        return
    world_ambience_enabled = enabled
    set_process(enabled)
    if _ambience_fade != null and _ambience_fade.is_running():
        _ambience_fade.kill()
    if enabled:
        if room_player != null and room_player.stream == null:
            room_player.stream = _load_loop(ROOM_PATH)
        if pressure_player != null and pressure_player.stream == null:
            pressure_player.stream = get_immersion_loop("pressure")
        if room_player != null and room_player.stream != null:
            if not room_player.playing:
                room_player.volume_db = -45.0
                room_player.play()
            _ambience_fade = create_tween()
            _ambience_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
            _ambience_fade.tween_property(room_player, "volume_db", ROOM_DB, FADE_SECONDS)
        if pressure_player != null and not pressure_player.playing:
            pressure_player.volume_db = -65.0
            pressure_player.play()
    else:
        # The main menu must be music-only, including procedural sounds.
        corridor_target = false
        backrooms_mode = false
        if world_reverb != null:
            world_reverb.wet = 0.045
        if room_player != null:
            room_player.stop()
            room_player.stream = null
        if pressure_player != null:
            pressure_player.stop()
            pressure_player.stream = null
        if footstep_player != null:
            footstep_player.stop()
            footstep_player.stream = null


func set_backrooms_mode(enabled: bool) -> void:
    if backrooms_mode == enabled:
        return
    backrooms_mode = enabled
    if not world_ambience_enabled or room_player == null:
        return
    if _ambience_fade != null and _ambience_fade.is_running():
        _ambience_fade.kill()
    _ambience_fade = create_tween()
    _ambience_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _ambience_fade.tween_property(room_player, "volume_db", -60.0 if enabled else ROOM_DB, 0.25)


func set_menu_music_enabled(enabled: bool) -> void:
    if enabled == menu_enabled:
        return
    menu_enabled = enabled
    if _fade != null and _fade.is_running():
        _fade.kill()

    if menu_player.stream == null:
        return
    if enabled:
        if not menu_player.playing:
            menu_player.volume_db = -60.0
            menu_player.play()
        _fade = create_tween()
        _fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _fade.tween_property(menu_player, "volume_db", MENU_DB, FADE_SECONDS)
    elif menu_player.playing:
        _fade = create_tween()
        _fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _fade.tween_property(menu_player, "volume_db", -60.0, FADE_SECONDS)
        _fade.tween_callback(menu_player.stop)


func _exit_tree() -> void:
    if _fade != null and _fade.is_running():
        _fade.kill()
    if _ambience_fade != null and _ambience_fade.is_running():
        _ambience_fade.kill()
    _fade = null
    _ambience_fade = null
    if footstep_player != null:
        footstep_player.stop()
        footstep_player.stream = null
    if pressure_player != null:
        pressure_player.stop()
        pressure_player.stream = null
    # Release the stream decoders before Godot closes AudioServer. This also
    # avoids headless QA's 'resources still in use at exit' warning once the
    # verified real Ogg assets have been uploaded.
    if menu_player != null:
        menu_player.stop()
        menu_player.stream = null
    if room_player != null:
        room_player.stop()
        room_player.stream = null
    # Release the effects graph before shutdown; headless Godot otherwise
    # reports live reverb resources even after all streams have stopped.
    if _created_world_bus:
        var index := AudioServer.get_bus_index("WORLD")
        if index >= 0:
            AudioServer.remove_bus(index)
    world_reverb = null
    procedural_loops.clear()
    step_sounds.clear()


func _prepare_immersion() -> void:
    var index := AudioServer.get_bus_index("WORLD")
    if index < 0:
        _created_world_bus = true
        index = AudioServer.get_bus_count()
        AudioServer.add_bus(index)
        AudioServer.set_bus_name(index, "WORLD")
    var first_child := AudioServer.get_bus_index("FOOTSTEP")
    if first_child >= 0 and index > first_child:
        AudioServer.move_bus(index, first_child)
        index = AudioServer.get_bus_index("WORLD")
    AudioServer.set_bus_send(index, "SFX")
    for name in ["FOOTSTEP", "CABINET"]:
        var child_index := AudioServer.get_bus_index(name)
        if child_index >= 0:
            AudioServer.set_bus_send(child_index, "WORLD")
    var horror := AudioServer.get_bus_index("HORROR")
    if horror >= 0:
        AudioServer.set_bus_send(horror, "SFX")
    var pressure := AudioServer.get_bus_index("PRESSURE")
    if pressure >= 0:
        AudioServer.set_bus_send(pressure, "SFX")
    if AudioServer.get_bus_effect_count(index) == 0:
        world_reverb = AudioEffectReverb.new()
        world_reverb.room_size = 0.53
        world_reverb.damping = 0.72
        world_reverb.wet = 0.045
        world_reverb.dry = 1.0
        AudioServer.add_bus_effect(index, world_reverb)
    else:
        world_reverb = AudioServer.get_bus_effect(index, 0) as AudioEffectReverb
    for surface in ["wood", "carpet", "corridor", "water"]:
        for variant in range(2):
            step_sounds[surface + str(variant)] = ImmersionSynth.footstep(surface, variant)
    for kind in ["cabinet", "bar", "vent", "pressure", "backrooms_hum"]:
        procedural_loops[kind] = ImmersionSynth.ambience(kind)
    footstep_player = AudioStreamPlayer.new()
    footstep_player.name = "FootstepCue"
    footstep_player.bus = "FOOTSTEP"
    footstep_player.max_polyphony = 3
    footstep_player.volume_db = -11.0
    add_child(footstep_player)
    pressure_player = AudioStreamPlayer.new()
    pressure_player.name = "PressureBed"
    pressure_player.bus = "PRESSURE"
    pressure_player.stream = procedural_loops["pressure"]
    pressure_player.volume_db = -65.0
    add_child(pressure_player)


func get_immersion_loop(kind: String) -> AudioStreamWAV:
    return procedural_loops.get(kind) as AudioStreamWAV


func get_footstep_stream(surface: String, variant: int) -> AudioStreamWAV:
    return step_sounds.get(surface + str(posmod(variant, 2))) as AudioStreamWAV


func play_footstep(surface: String, sprinting: bool) -> void:
    if not world_ambience_enabled or footstep_player == null:
        return
    var stream := get_footstep_stream(surface, steps_played)
    if stream == null:
        return
    footstep_player.stream = stream
    footstep_player.pitch_scale = (1.045 if sprinting else 1.0) + \
            (0.026 if steps_played % 3 == 0 else -0.020)
    footstep_player.volume_db = -12.0 if surface == "carpet" else -9.0
    footstep_player.play()
    steps_played += 1


func set_corridor_acoustics(in_corridor: bool) -> void:
    corridor_target = in_corridor


func pressure_db_for_visits(visits: int) -> float:
    # Monotonic across mistakes, independent of current anomaly identity.
    return -61.0 + 28.0 * clampf(float(visits) / 14.0, 0.0, 1.0)


func _process(delta: float) -> void:
    if not world_ambience_enabled:
        return
    if world_reverb != null:
        var wet := 0.20 if backrooms_mode else (0.26 if corridor_target else 0.045)
        if not is_instance_valid(_settings):
            _settings = get_node_or_null("/root/GameSettings")
        var mode := str(_settings.call("get_option", "reverb_mode")) if is_instance_valid(_settings) else "normal"
        wet *= 0.0 if mode == "off" else (0.35 if mode == "reduced" else 1.0)
        var next_wet := lerpf(world_reverb.wet, wet, 1.0 - exp(-4.0 * delta))
        if world_reverb.wet != next_wet:
            world_reverb.wet = next_wet
    if pressure_player != null and pressure_player.playing:
        if not is_instance_valid(_loop_state):
            _loop_state = get_node_or_null("/root/LoopState")
        var visits := int(_loop_state.get("visited_loops")) if is_instance_valid(_loop_state) else 0
        var target := -60.0 if backrooms_mode else pressure_db_for_visits(visits)
        var next_db := lerpf(pressure_player.volume_db, target, 1.0 - exp(-0.50 * delta))
        if pressure_player.volume_db != next_db:
            pressure_player.volume_db = next_db
