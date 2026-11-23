extends SceneTree
## Integration coverage for automatic catalog, five independent profiles,
## run separation, discovery status, debug exclusion and player-facing UI.
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const ProfilePanel = preload("res://ui/profile_panel.gd")
const ArchivePanel = preload("res://ui/anomaly_archive_panel.gd")
const WorldVerdictDisplay = preload("res://gameplay/world_verdict_display.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("Casino Anomaly profile/archive QA: " + reason)
    quit(1)

func _all_label_text(parent: Node) -> String:
    var combined := ""
    for child in parent.find_children("*", "Label", true, false):
        combined += (child as Label).text + "\n"
    return combined




func _run() -> void:
    var profiles := root.get_node_or_null("ProfileManager")
    var state := root.get_node_or_null("LoopState")
    if profiles == null or state == null:
        _fail("ProfileManager/LoopState autoload missing")
        return
    var entries: Array[Dictionary] = Catalog.entries()
    if entries.size() < 13 or Catalog.discoverable_ids().size() < 13:
        _fail("Packaged anomaly registry lost existing definitions")
        return
    for entry in entries:
        if Catalog.get_entry(str(entry.get("id", ""))).is_empty():
            _fail("Registry lookup does not match dynamic entries")
            return
    if not profiles.create_profile(4, "QA Four") or not profiles.create_profile(5, "QA Five"):
        _fail("Could not create isolated profile slots")
        return
    if not profiles.select_profile(4) or state.save_path != profiles.run_path(4):
        _fail("Selecting slot 4 did not bind the run save")
        return
    state.start_new_run()
    state.complete_tutorial()
    var ids: Array[String] = ["bar_label"]
    state.prepare_round(ids)
    if not state.decide(false).get("correct", false):
        _fail("Normal reference room must be scored")
        return
    state.prepare_round(ids)
    state.anomaly_id = "bar_label"
    state.round_ready = true
    var verdict: Dictionary = state.decide(true)
    if not bool(verdict.get("correct", false)) or str(verdict.get("anomaly_id", "")) != "bar_label":
        _fail("Verdict lost its anomaly ID")
        return
    var four: Dictionary = profiles.get_summary(4)
    if int(four.get("discovered", -1)) != 1 \
            or int(four.get("total", 0)) != Catalog.discoverable_ids().size():
        _fail("Discovered count must be derived from active catalog IDs")
        return
    if not bool(profiles.get_records().get("bar_label", {}).get("recognized", false)):
        _fail("Recognized anomaly was not persisted")
        return
    state.start_new_run()
    if int(profiles.get_summary(4).get("discovered", -1)) != 1:
        _fail("New run must preserve player collection")
        return
    if not profiles.select_profile(5) or int(profiles.get_summary(5).get("discovered", -1)) != 0:
        _fail("Profile 5 inherited another player's discoveries")
        return
    state.start_new_run()
    state.complete_tutorial()
    state.prepare_round(ids)
    state.decide(false)
    state.prepare_round(ids)
    if not state.debug_replace_prepared_round("bar_label", ids):
        _fail("Cannot force test anomaly")
        return
    var testing: Dictionary = state.decide(true)
    if not bool(testing.get("debugged", false)) \
            or int(profiles.get_summary(5).get("discovered", -1)) != 0:
        _fail("Developer selection incorrectly counted as discovery")
        return
    # Missing a real anomaly records an encounter but must never reveal
    # the name, category or description in the archive or last verdict.
    state.prepare_round(ids)
    state.anomaly_id = "bar_label"
    state.round_ready = true
    state.round_debugged = false
    var missed: Dictionary = state.decide(false)
    if bool(missed.get("correct", true)) \
            or not bool(profiles.get_records().has("bar_label")) \
            or bool(profiles.get_records().get("bar_label", {}).get("recognized", true)):
        _fail("Missing an anomaly must keep its archive entry locked")
        return
    if int(profiles.get_summary(5).get("discovered", -1)) != 0:
        _fail("Encountering an anomaly incorrectly unlocked its description")
        return
    if not profiles.rename_profile(5, "QA Renamed") \
            or str(profiles.get_summary(5).get("name", "")) != "QA Renamed":
        _fail("Profile rename not saved")
        return
    if not profiles.select_profile(4) or int(profiles.get_summary(4).get("discovered", -1)) != 1:
        _fail("Profile 4 progress did not survive a profile switch")
        return

    var picker := ProfilePanel.new()
    var archive := ArchivePanel.new()
    var plaque := WorldVerdictDisplay.new()
    root.add_child(picker)
    root.add_child(archive)
    root.add_child(plaque)
    plaque.place_for_lane("left", -52.0, -3.7, 1.22)
    plaque.set_result({"valid": true, "correct": false, "anomaly_id": "bar_label",
        "visited": 3, "previous_streak": 2, "streak": 0})
    await process_frame
    if not profiles.select_profile(5):
        _fail("Could not select unidentified-anomaly profile for UI check")
        return
    archive.show_mode("archive")
    var catalog_entry := Catalog.get_entry("bar_label")
    for field in ["title_de", "title_en", "description_de", "description_en", "category_de", "category_en"]:
        var private_value := str(catalog_entry.get(field, ""))
        if not private_value.is_empty() and _all_label_text(archive).contains(private_value):
            _fail("Archive exposed locked anomaly detail: " + field)
            return
    archive.show_mode("last")
    for field in ["title_de", "title_en", "description_de", "description_en"]:
        var private_value := str(catalog_entry.get(field, ""))
        if not private_value.is_empty() and _all_label_text(archive).contains(private_value):
            _fail("Last review exposed locked anomaly detail: " + field)
            return
    if not profiles.select_profile(4):
        _fail("Could not switch back to identified-anomaly profile")
        return
    archive.show_mode("archive")
    if not _all_label_text(archive).contains(str(catalog_entry.get("title_en", ""))) \
            and not _all_label_text(archive).contains(str(catalog_entry.get("title_de", ""))):
        _fail("Correct identification did not unlock the archive entry")
        return
    archive.show_mode("stats")
    archive.show_mode("last")
    if picker.get_node_or_null(".") == null or archive.get_child_count() == 0:
        _fail("Player-facing archive/profile UI did not instantiate")
        return
    if plaque.get_node_or_null("DecisionResult") == null \
            or plaque.get_child_count() < 6 or plaque is CanvasLayer:
        _fail("The verdict must be a physical 3D plaque, never a HUD")
        return
    var text_combined := ""
    for item in plaque.get_children():
        if item is Label3D:
            text_combined += (item as Label3D).text + " "
    if text_combined.contains("bar_label") or text_combined.contains("Bar sign") \
            or text_combined.contains("Barschild"):
        _fail("The corridor leaked an anomaly identity")
        return
    picker.queue_free()
    archive.queue_free()
    plaque.queue_free()
    if not profiles.delete_profile(4) or not profiles.delete_profile(5):
        _fail("Could not safely delete test profiles")
        return
    await process_frame
    print("Casino Anomaly profile archive QA PASS")
    quit(0)
