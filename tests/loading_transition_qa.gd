extends SceneTree
## Regression for both entry points and actual threaded resource loading.
## Do not preload main.tscn here: the loader must perform that work itself.

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

    if not loader.travel_to("res://main.tscn", true):
        _fail("Start-door loading cannot begin")
        return
    if not await _wait_for_scene("res://main.tscn", loader):
        _fail("Threaded casino transition did not finish")
        return
    if not state.tutorial_done or not state.round_ready:
        _fail("Intro completion or first clean casino round was lost")
        return
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
    quit(0)
