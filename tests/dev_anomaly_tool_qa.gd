extends SceneTree
## Regression for hidden G developer menu, catalog, one-shot overrides, live
## staged-room replacement and normal/auto choices. Runs in the release CI.
const StateScript = preload("res://gameplay/loop_state.gd")
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const ROOM = preload("res://gameplay/casino/main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    paused = false
    push_error("Casino anomaly developer tool QA: " + why)
    quit(1)

func _run() -> void:
    var isolated := StateScript.new()
    isolated.save_path = "user://casino_dev_picker_state_qa.cfg"
    isolated.start_new_run()
    isolated.complete_tutorial()
    var options: Array[String] = ["bar_label", "entrance_label"]
    if isolated.debug_queue_next_round("missing", options):
        _fail("Unknown anomaly IDs cannot be scheduled")
        return
    if not isolated.debug_queue_next_round("bar_label", options):
        _fail("Known anomaly could not be queued")
        return
    isolated.prepare_round(options)
    if not isolated.round_ready or not isolated.anomaly_id.is_empty() \
            or not isolated.debug_next_round_requested:
        _fail("G must never inject anomalies into the initial baseline room")
        return
    isolated.decide(false)
    isolated.prepare_round(options)
    if isolated.anomaly_id != "bar_label" or isolated.debug_next_round_requested:
        _fail("The queued anomaly was not consumed exactly once in the next room")
        return

    isolated.decide(true)
    if not isolated.debug_queue_next_round("", options):
        _fail("Forced normal round cannot be queued")
        return
    isolated.prepare_round(options)
    if not isolated.anomaly_id.is_empty() or isolated.debug_next_round_requested:
        _fail("Forced normal round was not respected")
        return
    isolated.decide(false)
    isolated.prepare_round(options)
    if not isolated.round_ready or isolated.debug_next_round_requested:
        _fail("Normal gameplay was not restored after the one-shot override")
        return
    if not isolated.debug_queue_next_round("entrance_label", options):
        _fail("Second active sign could not be queued")
        return
    isolated.save_run()
    var resumed := StateScript.new()
    resumed.save_path = isolated.save_path
    if not resumed.load_run() or resumed.debug_next_round_requested:
        _fail("Developer override must not survive save/load")
        return
    resumed.free()
    isolated.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://casino_dev_picker_state_qa.cfg"))

    var state = root.get_node_or_null("LoopState")
    if state == null:
        _fail("Loop state autoload missing")
        return
    state.save_path = "user://casino_dev_picker_runtime_qa.cfg"
    state.start_new_run()
    state.complete_tutorial()
    var scene := ROOM.instantiate() as Node3D
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    await process_frame
    var loop := scene.get_node_or_null("LoopController")
    var player := scene.get_node_or_null("Player") as CharacterBody3D
    var menu := player.get_node_or_null("AnomalyDevMenu") as CanvasLayer if player != null else null
    if loop == null or menu == null or menu.visible or state.anomaly_id != "":
        _fail("The hidden menu must exist only during gameplay and start closed")
        return
    if Catalog.entries().size() != 49 or (loop.call("debug_available_ids") as Array).size() < 13:
        _fail("Developer picker lost an active effect")
        return
    var available_ids: Array = loop.call("debug_available_ids")
    for retired_id in ["table_label","entrance_label__reverse","table_label__reverse","bust_turned","bust_turned__subtle","candleholder_shifted__other","crooked_painting__reverse","crooked_painting__subtle","plant_misplaced","plant_misplaced__subtle","stool_out_of_line__other","stool_out_of_line__subtle","breathing_wall","cool_ceiling_light__other"]:
        if available_ids.has(retired_id) or bool(loop.call("debug_select_next_anomaly", retired_id)):
            _fail("Developer picker accepted retired effect: " + retired_id)
            return
    if not available_ids.has("bust_turned__reverse"):
        _fail("Developer picker lost surviving bust variant")
        return
    var g := InputEventKey.new()
    g.keycode = KEY_G
    g.pressed = true
    menu.call("_input", g)
    if not menu.visible or not paused or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
        _fail("G must open the menu and release the cursor while pausing gameplay")
        return
    var list := menu.get("listing") as VBoxContainer
    var search := menu.get("search") as LineEdit
    if list == null or search == null or list.get_node_or_null("Anomaly_bar_label") == null \
            or list.get_node_or_null("Anomaly_table_label") != null \
            or list.get_node_or_null("Anomaly_entrance_label") == null \
            or list.get_node_or_null("Anomaly_crooked_painting") == null \
            or list.get_node_or_null("Anomaly_horse_spotlight_off") == null:
        _fail("All catalog entries must appear in the generated list")
        return
    var rows := 0
    for row in list.get_children():
        if str(row.name).begins_with("Anomaly_"):
            rows += 1
    if rows != 49:
        _fail("Developer picker must list exactly 49 active forms")
        return
    search.text = "Bar"
    menu.call("_rebuild_catalog")
    if list.get_node_or_null("Anomaly_bar_label") == null \
            or list.get_node_or_null("Anomaly_entrance_label") != null:
        _fail("The dynamic catalog search did not filter the rows")
        return
    menu.call("_choose_anomaly", "bar_label")
    if menu.visible or paused or not state.debug_next_round_requested \
            or state.debug_next_anomaly_id != "bar_label" or not state.anomaly_id.is_empty():
        _fail("Selecting an effect must close the menu and queue only the NEXT room")
        return
    loop.call("_stage_next", "left")
    var staged := loop.get("staged") as Node3D
    if staged == null or staged.get_node_or_null("AnomalyDevMenu") != null:
        _fail("A prepared room must not contain a second developer menu")
        return
    loop.call("_commit_choice", "left")
    var bar := staged.get_node("CornerBar/Sign_MIDNIGHT_BAR") as Label3D
    var table_sign := staged.get_node("Decor/Sign_TABLE_GAMES") as Label3D
    if state.anomaly_id != "bar_label" or bar.text != "MIDNIGHT B4R" \
            or state.debug_next_round_requested:
        _fail("Forced anomaly failed to apply to the staged room")
        return

    # The player is still in the connector. Changing G selection must
    # immediately replace the ALREADY prepared next room and its save state.
    menu.call("_open_menu")
    var entrance_entry := Catalog.get_entry("entrance_label")
    var entrance_sign := staged.get_node(str(entrance_entry["target_path"])) as Label3D
    var original_entrance := entrance_sign.text
    var original_table_color := table_sign.modulate
    menu.call("_choose_anomaly", "entrance_label")
    if paused or state.anomaly_id != "entrance_label" \
            or bar.text != "MIDNIGHT BAR" or entrance_sign.text != "CASINO AN0MALY" or table_sign.text != "TABLE GAMES" or table_sign.modulate != original_table_color:
        _fail("Changing the queued effect after preloading did not update the room")
        return
    menu.call("_open_menu")
    menu.call("_force_normal")
    if state.anomaly_id != "" or table_sign.text != "TABLE GAMES" or table_sign.modulate != original_table_color or entrance_sign.text != original_entrance:
        _fail("Normal override did not restore the original room appearance")
        return
    menu.call("_open_menu")
    menu.call("_restore_random")
    if not state.round_ready or state.debug_next_round_requested:
        _fail("Restore random failed to reroll the staged room")
        return

    loop.call("_handoff")
    var second := loop.get("room") as Node3D
    if second == null or player.get_parent() != second \
            or player.get_node_or_null("AnomalyDevMenu") != menu:
        _fail("The developer menu did not follow the persistent player")
        return
    var pause_menu := player.get_node_or_null("InGameMenu")
    pause_menu.call("_pause")
    menu.call("_open_menu")
    if menu.visible or not paused:
        _fail("The developer picker must not open over the normal pause menu")
        return
    pause_menu.call("_resume")
    second.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
    print("Casino Anomaly developer anomaly picker QA PASS")
    root.get_node("AudioDirector").call("request_quit")
