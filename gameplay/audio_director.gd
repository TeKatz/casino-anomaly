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


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    menu_player = AudioStreamPlayer.new()
    menu_player.name = "MenuMusic"
    menu_player.bus = "MUSIC"
    menu_player.process_mode = Node.PROCESS_MODE_ALWAYS
    menu_player.volume_db = -60.0
    add_child(menu_player)

    room_player = AudioStreamPlayer.new()
    room_player.name = "ContinuousRoomTone"
    room_player.bus = "SFX"
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
    if _ambience_fade != null and _ambience_fade.is_running():
        _ambience_fade.kill()
    if enabled:
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
        if pressure_player != null:
            pressure_player.stop()
        if footstep_player != null:
            footstep_player.stop()


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
    AudioServer.set_bus_send(index, "SFX")
    if AudioServer.get_bus_effect_count(index) == 0:
        world_reverb = AudioEffectReverb.new()
        world_reverb.room_size = 0.53
        world_reverb.damping = 0.72
        world_reverb.wet = 0.045
        world_reverb.dry = 1.0
        AudioServer.add_bus_effect(index, world_reverb)
    else:
        world_reverb = AudioServer.get_bus_effect(index, 0) as AudioEffectReverb
    for surface in ["wood", "carpet", "corridor"]:
        for variant in range(2):
            step_sounds[surface + str(variant)] = ImmersionSynth.footstep(surface, variant)
    for kind in ["cabinet", "bar", "vent", "pressure", "backrooms_hum"]:
        procedural_loops[kind] = ImmersionSynth.ambience(kind)
    footstep_player = AudioStreamPlayer.new()
    footstep_player.name = "FootstepCue"
    footstep_player.bus = "WORLD"
    footstep_player.max_polyphony = 3
    footstep_player.volume_db = -11.0
    add_child(footstep_player)
    pressure_player = AudioStreamPlayer.new()
    pressure_player.name = "PressureBed"
    pressure_player.bus = "SFX"
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
        world_reverb.wet = lerpf(world_reverb.wet, wet, 1.0 - exp(-4.0 * delta))
    if pressure_player != null and pressure_player.playing:
        var state := get_node_or_null("/root/LoopState")
        var visits := int(state.visited_loops) if state != null else 0
        pressure_player.volume_db = lerpf(pressure_player.volume_db,
                -60.0 if backrooms_mode else pressure_db_for_visits(visits), 1.0 - exp(-0.50 * delta))
