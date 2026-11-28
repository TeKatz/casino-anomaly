extends SceneTree
## Regression for both entry points and actual threaded resource loading.
## Do not preload gameplay/casino/main.tscn here: the loader must perform that work itself.

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("Casino Anomaly loading transition QA: " + message)
    quit(1)


func _wait_for_scene(expected: String, loader: Node, max_msec: int = 120000) -> bool:
    var started := Time.get_ticks_msec()
    while Time.get_ticks_msec() - started < max_msec:
        await process_frame
        if not loader.get("active") and current_scene != null:
            return current_scene.scene_file_path == expected
        if loader.get("failed"):
            return false
    return false


func _run() -> void:
    var loader := root.get_node_or_null("SceneLoader")
    var state := root.get_node_or_null("LoopState")
    if loader == null or state == null:
        _fail("SceneLoader or LoopState autoload missing")
        return
    # Explicit policy regression: headless tests alone would otherwise
    # exercise only the existing serial-worker branch.
    for record in [
        ["res://gameplay/casino/main.tscn",true,false,false],
        ["res://gameplay/casino/main.tscn",false,false,true],
        ["res://gameplay/tutorial.tscn",false,false,true],
        ["res://gameplay/casino/main.tscn",true,true,false],
        ["res://gameplay/casino/main.tscn",false,true,false],
        ["res://gameplay/tutorial.tscn",false,true,false]
    ]:
        if loader.call("_use_parallel_dependencies",record[0],record[1],record[2])!=record[3]:
            _fail("Initial loading worker policy changed: "+str(record))
            return
    if loader.get_node_or_null("LoadingOverlay/Background") == null:
        _fail("Persistent loader has no rendered background")
        return
    if loader.travel_to("res://not_a_scene.tscn"):
        _fail("SceneLoader must reject unsupported destinations")
        return
    if str(ProjectSettings.get_setting("application/config/icon")) != "res://branding/casino_anomaly_icon.png" or str(ProjectSettings.get_setting("application/config/windows_native_icon")) != "res://branding/casino_anomaly.ico":
        _fail("Approved application or Windows native icon missing")
        return
    var mark := loader.get("mark") as TextureRect
    var wordmark := loader.find_child("BrandWordmark",true,false) as TextureRect
    if mark == null or mark.texture == null or mark.texture.resource_path != "res://branding/casino_anomaly_emblem.png" or wordmark == null or wordmark.texture == null or wordmark.texture.resource_path != "res://branding/casino_anomaly_wordmark.png" or mark.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED or wordmark.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
        _fail("Loading screen lost the approved branding or aspect ratio")
        return

    var journal := root.get_node_or_null("CrashJournal")
    if journal == null:
        _fail("CrashJournal autoload missing")
        return
    var journal_dir := "user://crash_journal_qa_"+str(OS.get_process_id())
    journal.call("begin_session",journal_dir)
    if not bool(journal.get("enabled")):
        _fail("Crash journal could not start")
        return
    var previous_save: String = state.save_path
    var test_save := "user://loading_transition_qa.cfg"
    state.save_path = test_save
    state.start_new_run()
    if not loader.travel_to("res://gameplay/tutorial.tscn"):
        _fail("New Game cannot initiate threaded loading")
        return
    if not loader.get("active") or not (loader.get("overlay") as Control).visible:
        _fail("Loading overlay is not visible immediately")
        return
    if not await _wait_for_scene("res://gameplay/tutorial.tscn", loader):
        _fail("Threaded tutorial transition did not finish")
        return
    if state.tutorial_done:
        _fail("New Game must not skip the tutorial")
        return

    # Exercise the actual live tutorial input path, not a direct loader call.
    var intro := current_scene as Node3D
    var door := intro.get_node_or_null("SideGalleries/EastGallery/AccessBays/MainCasinoEntrance") as Node3D
    var player := intro.get_node_or_null("Player") as CharacterBody3D
    var camera := intro.get_node_or_null("Player/Camera3D") as Camera3D
    if door == null or player == null or camera == null or intro.get_node_or_null("CroupierStation")==null:
        _fail("Canonical tutorial path did not load the new hall")
        return
    var marker := door.get_node("DestinationMarker") as Node3D
    var objective := player.get_node_or_null("ObjectiveHUD") as CanvasLayer
    if objective == null or (objective.get("card") as Control).visible:
        _fail("Fresh tutorial has premature objective HUD")
        return
    if marker.visible or bool(intro.get("has_spoken")):
        _fail("Fresh tutorial has premature destination guidance")
        return
    # The existing optional tutorial remains skippable by using the door
    # directly, even with no conversation or marker.
    player.global_position = door.to_global(Vector3(0,1.02,2.0))
    camera.look_at(door.to_global(Vector3(0,1.55,0)),Vector3.UP)
    if not bool(intro.call("_is_looking_at_door")):
        _fail("Grand entrance active casino door cannot be targeted")
        return
    var event := InputEventAction.new()
    event.action = "casino_interact"
    event.pressed = true
    intro.call("_unhandled_input",event)
    if (objective.get("card") as Control).visible or marker.visible or not bool(loader.get("active")) or not bool(intro.get("changing")) or not bool(player.get("interaction_locked")) or state.tutorial_done:
        _fail("Start-door interaction did not lock input and start loading before completing tutorial")
        return
    intro.call("_unhandled_input",event)
    var escape := InputEventKey.new()
    escape.keycode = KEY_ESCAPE
    escape.pressed = true
    player.get_node("InGameMenu").call("_input",escape)
    if paused or bool(player.get_node("InGameMenu").get("open")):
        _fail("Pause menu intercepted the active loading transition")
        return
    if str(loader.get("target_path")) != "res://gameplay/casino/main.tscn":
        _fail("Repeated door interaction changed the transition")
        return
    if not await _wait_for_scene("res://gameplay/casino/main.tscn", loader):
        _fail("Threaded casino transition did not finish")
        return
    if current_scene.get_node_or_null("Player/ObjectiveHUD")!=null or is_instance_valid(objective):
        _fail("Tutorial objective survived the casino handoff")
        return
    if not state.tutorial_done or not state.round_ready or not str(state.anomaly_id).is_empty():
        _fail("Intro completion or first clean casino round was lost")
        return
    var journal_path := journal_dir.path_join("events.jsonl")
    var journal_text := FileAccess.get_file_as_string(journal_path)
    for event_name in ["load_overlay_requested", "load_threaded_request_begin", "load_threaded_request_returned", "load_resources_ready", "load_get_packed_begin", "load_activate_scene_begin", "load_scene_ready", "casino_door_interacted", "tutorial_tree_exit", "load_complete_tutorial_begin", "load_complete_tutorial_returned", "load_first_frame_after_activation", "load_second_frame_after_activation", "casino_hall_ready_begin", "casino_hall_ready_end", "casino_controller_ready_begin", "casino_controller_ready_end", "casino_first_round_begin", "casino_first_round_end", "casino_voxel_gi_load_begin", "casino_voxel_gi_load_end", "casino_polyhaven_population_begin", "casino_polyhaven_population_end", "casino_sketchfab_population_begin", "casino_sketchfab_population_end"]:
        if not journal_text.contains('"event":"'+event_name+'"'):
            _fail("Missing persisted crash breadcrumb: "+event_name)
            return
    var serial_request_seen := false
    for line in journal_text.split("\n",false):
        var entry: Variant = JSON.parse_string(line)
        if entry is Dictionary and entry.get("event")=="load_threaded_request_begin":
            var details: Dictionary = entry.get("details",{})
            if details.get("target")=="res://gameplay/casino/main.tscn" and details.get("parallel_dependencies")==false:
                serial_request_seen = true
    if not serial_request_seen:
        _fail("Actual initial casino request did not use serial dependency workers")
        return
    # A late call must not write synchronous breadcrumbs during normal play.
    var trace_script := load("res://gameplay/initial_load_trace.gd")
    trace_script.record(current_scene,"unexpected_streaming_trace")
    if FileAccess.get_file_as_string(journal_path).contains("unexpected_streaming_trace"):
        _fail("Initial activation tracer leaked into normal gameplay")
        return
    journal.set("enabled",false)
    for file_name in DirAccess.get_files_at(journal_dir):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(journal_dir.path_join(file_name)))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(journal_dir))
    state.save_path = previous_save
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
    # Release the actual active scene before stopping the renderer.
    var finished_scene := current_scene
    current_scene = null
    if is_instance_valid(finished_scene):
        finished_scene.queue_free()
    await process_frame
    await process_frame
    print("Casino Anomaly threaded scene loading QA PASS")
    root.get_node("AudioDirector").call("request_quit")
