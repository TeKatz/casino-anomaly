extends Node
## Persistent 2D audio controller. The menu is MUSIC only; room tone begins
## with a first-person Player and keeps playing through in-world room handoffs.
const MENU_PATH := "res://audio/hmm_menu_seamless.ogg"
const ROOM_PATH := "res://audio/casino_room_tone_seamless.ogg"
const MENU_DB := -7.0
const ROOM_DB := -2.0
const FADE_SECONDS := 0.45

var menu_player: AudioStreamPlayer
var room_player: AudioStreamPlayer
var menu_enabled := false
var world_ambience_enabled := false
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
    if room_player == null or room_player.stream == null:
        return
    if enabled:
        if not room_player.playing:
            room_player.volume_db = -45.0
            room_player.play()
        _ambience_fade = create_tween()
        _ambience_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _ambience_fade.tween_property(room_player, "volume_db", ROOM_DB, FADE_SECONDS)
    else:
        # Do not let white noise bleed into the music-only menu. Stop it
        # immediately rather than fading through the first menu seconds.
        room_player.stop()


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
    # Release the stream decoders before Godot closes AudioServer. This also
    # avoids headless QA's 'resources still in use at exit' warning once the
    # verified real Ogg assets have been uploaded.
    if menu_player != null:
        menu_player.stop()
        menu_player.stream = null
    if room_player != null:
        room_player.stop()
        room_player.stream = null
