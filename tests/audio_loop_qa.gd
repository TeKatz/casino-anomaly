extends SceneTree
## Verify global ambience persists while only the main menu enables music.
## The audio ZIP is user-uploaded separately; until then this is a code test.
const MENU = preload("res://menu.tscn")
const TUTORIAL = preload("res://gameplay/tutorial.tscn")
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
            or ambience.bus != "AMBIENCE":
        _fail("Audio streams do not use independent MUSIC and AMBIENCE buses")
        return
    if not (director.process_mode == Node.PROCESS_MODE_ALWAYS):
        _fail("Continuous ambience must survive the paused game and scene swaps")
        return
    var has_music := ResourceLoader.exists(MENU_AUDIO)
    var has_ambience := ResourceLoader.exists(ROOM_AUDIO)
    if has_music != has_ambience:
        _fail("The menu and ambient loops must be imported together")
        return

    if ambience.playing or music.playing:
        _fail("Neither audio stream may play before a scene enables it")
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
        if ambience.playing or music.playing:
            _fail("Both streams must remain stopped before menu or first-person entry")
            return
    else:
        print("Casino audio ZIP not uploaded: runtime switching is tested without binary streams.")

    var initial_ambience := ambience
    var menu := MENU.instantiate() as Control
    root.add_child(menu)
    await process_frame
    if not bool(director.get("menu_enabled")) \
            or bool(director.get("world_ambience_enabled")):
        _fail("In the main menu, only menu music may be enabled")
        return
    if has_music and (not music.playing or ambience.playing):
        _fail("The main menu must play music but no ambient white noise")
        return

    menu.queue_free()
    await process_frame
    await process_frame
    if bool(director.get("menu_enabled")):
        _fail("Menu music must be disabled after leaving the menu")
        return

    # Enter the actual first-person tutorial. Its real Player script, not an
    # artificial test-only audio call, must activate ambient playback.
    var world := TUTORIAL.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    if world.get_node_or_null("Player/Camera3D") == null:
        _fail("Tutorial has no first-person Player")
        return
    if not bool(director.get("world_ambience_enabled")):
        _fail("Ambient tone did not enable upon entering the first-person world")
        return
    if has_music and not ambience.playing:
        _fail("White noise must start once the first-person Player becomes active")
        return
    if not is_instance_valid(initial_ambience) or ambience != initial_ambience:
        _fail("The persistent ambient player was recreated on gameplay entry")
        return

    # A streamed hall's second Player also runs _ready. It must not restart
    # or recreate the continuous sound.
    director.set_world_ambience_enabled(true)
    await process_frame
    if not bool(director.get("world_ambience_enabled")) \
            or (has_music and not ambience.playing) \
            or ambience != initial_ambience:
        _fail("Repeated world entry must preserve the existing room-tone loop")
        return

    await create_timer(0.55).timeout
    if has_music and music.playing:
        _fail("The menu track must stop after the menu exit crossfade")
        return

    # Returning to main menu must stop the continuous ambience immediately,
    # including when the user leaves through the in-game pause menu.
    world.queue_free()
    await process_frame
    await process_frame
    var returned_menu := MENU.instantiate() as Control
    root.add_child(returned_menu)
    await process_frame
    if bool(director.get("world_ambience_enabled")) \
            or not bool(director.get("menu_enabled")):
        _fail("Returning to menu did not switch to music-only mode")
        return
    if ambience.playing or (has_music and not music.playing):
        _fail("Returning to menu must stop ambient white noise and play menu music")
        return
    returned_menu.queue_free()
    await process_frame
    await process_frame
    # Close the real Ogg decoder/playback objects before quitting headless.
    # Otherwise Godot 4.5.1 reports four live Ogg/audio resources on exit,
    # even though the functional assertions have already passed.
    music.stop()
    ambience.stop()
    director.queue_free()
    await process_frame
    await process_frame
    await create_timer(0.15).timeout
    print("Casino Anomaly persistent audio and menu-only loop QA PASS")
    quit(0)
