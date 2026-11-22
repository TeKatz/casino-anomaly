extends SceneTree
## Integration coverage for automatic catalog, five independent profiles,
## run separation, discovery status, debug exclusion and player-facing UI.
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const ProfilePanel = preload("res://ui/profile_panel.gd")
const ArchivePanel = preload("res://ui/anomaly_archive_panel.gd")
const Feedback = preload("res://ui/decision_feedback.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("Casino Anomaly profile/archive QA: " + reason)
    quit(1)


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
    if not profiles.rename_profile(5, "QA Renamed") \
            or str(profiles.get_summary(5).get("name", "")) != "QA Renamed":
        _fail("Profile rename not saved")
        return
    if not profiles.select_profile(4) or int(profiles.get_summary(4).get("discovered", -1)) != 1:
        _fail("Profile 4 progress did not survive a profile switch")
        return

    var picker := ProfilePanel.new()
    var archive := ArchivePanel.new()
    var feedback := Feedback.new()
    root.add_child(picker)
    root.add_child(archive)
    root.add_child(feedback)
    await process_frame
    archive.show_mode("archive")
    archive.show_mode("stats")
    archive.show_mode("last")
    feedback.show_verdict({"valid": true, "correct": false, "anomaly_id": "bar_label",
        "visited": 3, "previous_streak": 2})
    if picker.get_node_or_null(".") == null or archive.get_child_count() == 0:
        _fail("Player-facing archive/profile UI did not instantiate")
        return
    picker.queue_free()
    archive.queue_free()
    feedback.queue_free()
    if not profiles.delete_profile(4) or not profiles.delete_profile(5):
        _fail("Could not safely delete test profiles")
        return
    await process_frame
    print("Casino Anomaly profile archive QA PASS")
    quit(0)
