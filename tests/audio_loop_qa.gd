extends SceneTree
## Verify global ambience persists while only the main menu enables music.
## The audio ZIP is user-uploaded separately; until then this is a code test.
const MENU = preload("res://menu.tscn")
const MENU_AUDIO := "res://audio/hmm_menu_seamless.ogg"
const ROOM_AUDIO := "res://audio/casino_room_tone_seamless.ogg"


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("Casino audio loop QA: " + why)
    quit(1)


func _run() -> void:
    var director := root.get_node_or_null("AudioDirector")
    if director == null:
        _fail("AudioDirector autoload missing")
        return
    var music := director.get_node_or_null("MenuMusic") as AudioStreamPlayer
    var ambience := director.get_node_or_null("ContinuousRoomTone") as AudioStreamPlayer
    if music == null or ambience == null or music.bus != "MUSIC" \
            or ambience.bus != "SFX":
        _fail("Audio streams do not use the existing MUSIC and SFX buses")
        return
    if not (director.process_mode == Node.PROCESS_MODE_ALWAYS):
        _fail("Continuous ambience must survive the paused game and scene swaps")
        return
    var has_music := ResourceLoader.exists(MENU_AUDIO)
    var has_ambience := ResourceLoader.exists(ROOM_AUDIO)
    if has_music != has_ambience:
        _fail("The menu and ambient loops must be imported together")
        return

    if has_music:
        var menu_stream := music.stream as AudioStreamOggVorbis
        var tone_stream := ambience.stream as AudioStreamOggVorbis
        if menu_stream == null or tone_stream == null \
                or not menu_stream.loop or not tone_stream.loop:
            _fail("Both imported Ogg Vorbis streams must loop natively")
            return
        if absf(menu_stream.get_length() - 92.754) > 0.08 \
                or absf(tone_stream.get_length() - 13.219) > 0.08:
            _fail("Processed loop durations differ: %s / %s" % [
                str(menu_stream.get_length()), str(tone_stream.get_length())])
            return
        if not ambience.playing or music.playing:
            _fail("Ambience must play from startup, and menu music starts only with menu")
            return
    else:
        print("Casino audio ZIP not uploaded: runtime switching is tested without binary streams.")

    var initial_ambience := ambience
    var menu := MENU.instantiate() as Control
    root.add_child(menu)
    await process_frame
    if not bool(director.get("menu_enabled")):
        _fail("Music must be enabled only when menu scene is active")
        return
    if has_music and (not music.playing or music.stream == ambience.stream):
        _fail("Main menu is not playing its own music stream")
        return

    menu.queue_free()
    await process_frame
    await process_frame
    if bool(director.get("menu_enabled")):
        _fail("Main menu music remains enabled after scene exit")
        return
    if not is_instance_valid(initial_ambience) or initial_ambience != ambience:
        _fail("The global ambience node was destroyed by the menu transition")
        return
    if has_music and not ambience.playing:
        _fail("Room tone stopped during menu to gameplay transition")
        return
    print("Casino Anomaly persistent audio and menu-only loop QA PASS")
    quit(0)
