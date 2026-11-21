extends Node
## Persisting 2D audio controller. Ambient tone never restarts during
## tutorial -> hall -> next hall transitions; music is restricted to menu.tscn.
const MENU_PATH := "res://audio/hmm_menu_seamless.ogg"
const ROOM_PATH := "res://audio/casino_room_tone_seamless.ogg"
const MENU_DB := -7.0
const ROOM_DB := -2.0
const FADE_SECONDS := 0.45

var menu_player: AudioStreamPlayer
var room_player: AudioStreamPlayer
var menu_enabled := false
var _fade: Tween


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
    if room_player.stream != null:
        room_player.play()


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
    _fade = null
    # Release the stream decoders before Godot closes AudioServer. This also
    # avoids headless QA's 'resources still in use at exit' warning once the
    # verified real Ogg assets have been uploaded.
    if menu_player != null:
        menu_player.stop()
        menu_player.stream = null
    if room_player != null:
        room_player.stop()
        room_player.stream = null
