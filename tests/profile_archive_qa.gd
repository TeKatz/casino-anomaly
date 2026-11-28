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
    if entries.size() != 49 or Catalog.discoverable_ids().has("table_label"):
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
    if profiles.has_prior_run(4) or profiles.has_prior_run(5):
        _fail("A newly created profile must not have a prior run")
        return
    state.start_new_run()
    if bool(state.get("returning_guest")) or not profiles.has_prior_run(4):
        _fail("First run was classified as a returning guest")
        return
    if not profiles.select_profile(4) or bool(state.get("returning_guest")):
        _fail("Continuing the first run changed the guest identity")
        return
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
    # A formerly mastered Table Games family stays in the profile file,
    # but does not inflate the current archive, statistics or XP.
    var legacy := ConfigFile.new()
    if legacy.load(profiles.progress_path(4)) != OK:
        _fail("Could not read historical profile")
        return
    var historical: Dictionary = legacy.get_value("progress","records",{})
    historical["table_label"] = {"recognized":true,"correct":5,"missed":2,"variants":{"table_label":true}}
    var historical_stats: Dictionary = legacy.get_value("progress","stats",{})
    legacy.set_value("progress","records",historical)
    if legacy.save(profiles.progress_path(4)) != OK or not profiles.select_profile(4):
        _fail("Could not reload historical Table Games profile")
        return
    four = profiles.get_summary(4)
    if profiles.get_records() != historical or int(four["discovered"]) != 1 or int(four["total"]) != Catalog.discoverable_ids().size() or int(four["xp"]) != int(historical_stats.get("xp",0)):
        _fail("Retirement changed historical profile or active summary")
        return
    state.start_new_run()
    if not bool(state.get("returning_guest")) or not profiles.select_profile(4) or not bool(state.get("returning_guest")):
        _fail("Restarted profile failed to remember the returning guest")
        return
    if int(profiles.get_summary(4).get("discovered", -1)) != 1:
        _fail("New run must preserve player collection")
        return
    if not profiles.select_profile(5) or int(profiles.get_summary(5).get("discovered", -1)) != 0:
        _fail("Profile 5 inherited another player's discoveries")
        return
    state.start_new_run()
    if bool(state.get("returning_guest")):
        _fail("A separate profile inherited returning-guest status")
        return
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
            or bool(profiles.get_records().get("bar_label", {}).get("recognized", false)):
        _fail("Missing an anomaly must keep its archive entry locked")
        return
    if int(profiles.get_summary(5).get("discovered", -1)) != 0:
        _fail("Encountering an anomaly incorrectly unlocked its description")
        return
    # A legacy profile save without the optional flag still represents an
    # established guest. Renaming and selecting another mode retain history.
    var old_run := ConfigFile.new()
    if old_run.load(profiles.run_path(5)) != OK:
        _fail("Could not read run for legacy recognition regression")
        return
    old_run.erase_section_key("run", "returning_guest")
    if old_run.save(profiles.run_path(5)) != OK or not profiles.select_profile(5) or not bool(state.get("returning_guest")):
        _fail("Legacy save lost returning-guest recognition")
        return
    if not profiles.rename_profile(5, "QA Renamed") \
            or str(profiles.get_summary(5).get("name", "")) != "QA Renamed":
        _fail("Profile rename not saved")
        return
    if not profiles.select_profile(4) or int(profiles.get_summary(4).get("discovered", -1)) != 1 or not bool(state.get("returning_guest")):
        _fail("Profile 4 progress or guest recognition did not survive a profile switch")
        return

    for entry in Catalog.entries():
        var id := str(entry["id"])
        for de in [false, true]:
            var clue := Catalog.review_hint(id, de)
            if clue.is_empty() or clue == str(entry["description_de" if de else "description_en"]):
                _fail("Missing or overly explicit localized hint: " + id)
                return
    if not Catalog.missed_review_hint({"anomaly_id": "bar_label", "correct": true}, false).is_empty() or not Catalog.missed_review_hint({"anomaly_id": "", "correct": false, "choice_anomaly": true}, false).is_empty():
        _fail("Hints must appear only for missed anomalies")
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
    var clue_en := Catalog.review_hint("bar_label", false)
    var clue_de := Catalog.review_hint("bar_label", true)
    if not _all_label_text(archive).contains(clue_en) and not _all_label_text(archive).contains(clue_de):
        _fail("Missed hint absent from verdict menu")
        return
    var plaque_hint := plaque.get_node_or_null("MissedHint") as Label3D
    if plaque_hint == null or not plaque_hint.visible or (not plaque_hint.text.contains(clue_en) and not plaque_hint.text.contains(clue_de)):
        _fail("Missed hint absent from physical plaque")
        return
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
    var active_total := Catalog.discoverable_ids().size()
    if not _all_label_text(archive).contains("1 / %d" % active_total) or _all_label_text(archive).contains("Table Games sign") or _all_label_text(archive).contains("Table-Games-Schild") or not _all_label_text(archive).contains("1 / 49"):
        _fail("Archive displays retired Table Games or wrong active totals")
        return
    archive.show_mode("stats")
    if not _all_label_text(archive).contains("1 / %d" % active_total):
        _fail("Statistics display wrong current family total")
        return
    archive.show_mode("last")
    if picker.get_node_or_null(".") == null or archive.get_child_count() == 0:
        _fail("Player-facing archive/profile UI did not instantiate")
        return
    if plaque.get_node_or_null("DecisionResult") == null \
            or plaque.get_child_count() < 6:
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
    if not profiles.create_profile(4, "QA Recreated") or profiles.has_prior_run(4):
        _fail("Recreated profile inherited deleted guest history")
        return
    state.start_new_run()
    if bool(state.get("returning_guest")) or not profiles.delete_profile(4):
        _fail("Recreated profile did not start as a fresh guest")
        return
    await process_frame
    print("Casino Anomaly profile archive QA PASS")
    quit(0)
