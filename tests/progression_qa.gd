extends SceneTree
const State = preload("res://gameplay/loop_state.gd")
const Progress = preload("res://gameplay/progression.gd")
const Modes = preload("res://gameplay/run_modes.gd")
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const Archive = preload("res://ui/anomaly_archive_panel.gd")
const Picker = preload("res://ui/profile_panel.gd")

func _initialize() -> void:
    call_deferred("_run")

func require(condition: bool, message: String) -> bool:
    if not condition:
        push_error("Progression QA: " + message)
        quit(1)
    return condition

func _start(state: Node, mode: String) -> void:
    state.start_new_run(mode)
    state.complete_tutorial()

func _answer(state: Node, id: String, yes: bool) -> Dictionary:
    state.anomaly_id = id
    state.round_ready = true
    return state.decide(yes)

func _run() -> void:
    var stats := {"correct": 5, "completions": 1, "best_streak": 12}
    var records := {"bar_label": {"recognized": true, "correct": 2, "missed": 1}}
    Progress.migrate(stats, records)
    var xp := int(stats["xp"])
    Progress.migrate(stats, records)
    if not require(xp == 825 and int(stats["xp"]) == xp and bool(records["bar_label"]["variants"]["bar_label"]), "Legacy migration must be accurate and idempotent"):
        return
    Progress.evaluate(stats, records)
    if not require(bool(stats["achievements"].get("classic_completions_1", false)), "Retroactive achievements missing"):
        return
    var ids := Catalog.discoverable_ids()
    if not require(ids.size() >= 14 and Catalog.entries().size() == 49 and Catalog.family("bust_turned__reverse") == "bust_turned", "Family or variant registry incorrect"):
        return
    # A retired cool variant retains its historical family discovery but is
    # not an active form and cannot resolve as a selectable definition.
    var retired_cool := {"cool_ceiling_light": {"recognized": true, "correct": 5, "variants": {"cool_ceiling_light__other": true}}}
    var cool_counts := Progress.counts(retired_cool)
    if not require(Catalog.get_entry("cool_ceiling_light__other").is_empty() and Catalog.family_entries("cool_ceiling_light").size() == 1 and cool_counts["discovered"] == 1 and cool_counts["mastered"] == 1 and cool_counts["variants"] == 0, "Retired cool variant changed legacy family progress or active forms"):
        return
    # Historical records retain the original family and retired form IDs.
    var old_records := {
        "bust_turned": {"recognized": true, "correct": 5, "variants": {"bust_turned": true, "bust_turned__subtle": true}},
        "plant_misplaced": {"recognized": true, "correct": 5, "variants": {"plant_misplaced": true}},
        "breathing_wall": {"recognized": true, "correct": 5, "variants": {"breathing_wall": true}},
        "table_label": {"recognized": true, "correct": 5, "missed": 2, "variants": {"table_label": true}}
    }
    var old_stats := {"progression_version": Progress.VERSION, "xp": 4321, "classic_completions": 1, "achievements": {"archive_complete": true}}
    var old_snapshot := old_records.duplicate(true)
    Progress.migrate(old_stats, old_records)
    Progress.evaluate(old_stats, old_records)
    var counts := Progress.counts(old_records)
    if not require(counts["discovered"] == 1 and counts["mastered"] == 1 and counts["variants"] == 0 and old_records == old_snapshot and old_stats["xp"] == 4321 and old_stats["achievements"]["archive_complete"] and Modes.unlock("nightmare", old_stats, old_records), "Retirement altered legacy records, XP, unlocks or active counts"):
        return
    var full_collection := {}
    for family_id in ids:
        var forms := {}
        for form in Catalog.family_entries(family_id):
            forms[form["id"]] = true
        full_collection[family_id] = {"recognized":true,"correct":5,"variants":forms}
    var full_counts := Progress.counts(full_collection)
    var full_stats := {"progression_version":Progress.VERSION,"xp":4321}
    Progress.evaluate(full_stats,full_collection)
    if not require(not ids.has("table_label") and int(full_counts["variant_total"])==49 and int(full_counts["variants"])==49 and int(full_counts["discovered"])==ids.size() and bool(full_stats["achievements"].get("archive_complete",false)) and bool(full_stats["achievements"].get("mastery_complete",false)), "Active archive or mastery completion still requires retired Table Games"):
        return
    var definitions := Progress.achievement_definitions()
    var seen := {}
    for entry in definitions:
        if not require(not seen.has(entry["id"]), "Duplicate achievement ID"):
            return
        seen[entry["id"]] = true
    if not require(definitions.size() >= 40, "Achievement list incomplete"):
        return
    for entry in definitions:
        var metric := str(entry["metric"])
        if metric in ["discovered", "mastered", "variants"]:
            var maximum := int(counts["variant_total"]) if metric == "variants" else ids.size()
            if not require(int(entry["goal"]) <= maximum, "Unreachable collection achievement: " + str(entry["id"])):
                return
    var state := State.new()
    state.save_path = "user://progression_rules_qa.cfg"
    _start(state, "endless")
    for i in range(15):
        if not require(not bool(_answer(state, "", false)["finished"]), "Endless incorrectly capped at 12"):
            return
    var failed := _answer(state, "", true)
    if not require(bool(failed["finished"]) and bool(failed["failed"]) and int(failed["previous_streak"]) == 15, "Endless did not preserve final streak"):
        return
    _start(state, "nightmare")
    if not require(bool(_answer(state, "", true)["failed"]), "Nightmare allowed a mistake"):
        return
    _start(state, "research")
    _answer(state, "", false)
    _answer(state, "", true)
    if not require(state.correct_streak == 1 and state.active, "Research reset progress"):
        return
    for i in range(18):
        _answer(state, "", false)
    if not require(state.finished and state.visited_loops == 20, "Research goal incorrect"):
        return
    _start(state, "time_trial")
    state.tick_play_time(100.0)
    _answer(state, "", true)
    for i in range(11):
        _answer(state, "", false)
    if not require(state.finished and is_equal_approx(float(state.last_verdict["score_seconds"]), 120.0), "Time-trial penalty or completion incorrect"):
        return
    _start(state, "expedition")
    _answer(state, "", false)
    var available: Array[String] = ["backrooms", "bar_label"]
    state.prepare_round(available)
    if not require(state.anomaly_id == "backrooms" and not bool(state.decide(false)["valid"]), "Expedition did not select actual traversal"):
        return
    if not require(bool(state.complete_backrooms(false)["finished"]), "Expedition completion incorrect"):
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
    state.free()

    var profiles := root.get_node("ProfileManager")
    var live := root.get_node("LoopState")
    if not require(profiles.create_profile(5, "Progression QA"), "Could not create isolated profile"):
        return
    _start(live, "classic")
    _answer(live, "", false)
    _answer(live, "bust_turned__reverse", true)
    var before: Dictionary = profiles.get_stats()
    if not require(int(before["xp"]) == 225 and bool(profiles.get_records()["bust_turned"]["variants"]["bust_turned__reverse"]), "Variant discovery did not award family XP"):
        return
    _answer(live, "bust_turned__reverse", true)
    if not require(int(profiles.get_stats()["xp"]) == 275, "Repeat of surviving form awarded duplicate family discovery"):
        return
    live.round_debugged = true
    _answer(live, "bar_label", true)
    if not require(int(profiles.get_stats()["xp"]) == 275 and not profiles.get_records().has("bar_label"), "Developer tools awarded permanent progress"):
        return
    if not require(profiles.select_mode("endless"), "Mode selection failed"):
        return
    _start(live, "endless")
    for i in range(13):
        _answer(live, "", false)
    if not require(profiles.select_mode("classic") and live.visited_loops == 4, "Endless overwrote classic save"):
        return
    if not require(profiles.select_mode("endless") and live.correct_streak == 13, "Endless save truncated streak or lost mode"):
        return
    _answer(live, "", true)
    if not require(int(profiles.get_stats()["mode_records"]["endless"]["best"]) == 13, "Endless record missing"):
        return
    # Load a real old profile file, not just an in-memory metric fixture.
    var legacy := ConfigFile.new()
    if not require(legacy.load(profiles.progress_path(5)) == OK, "Could not read profile save"):
        return
    var saved_records: Dictionary = legacy.get_value("progress", "records", {})
    saved_records["plant_misplaced"] = old_records["plant_misplaced"]
    saved_records["breathing_wall"] = old_records["breathing_wall"]
    saved_records["table_label"] = old_records["table_label"]
    var saved_bust: Dictionary = saved_records["bust_turned"]
    saved_bust["variants"]["bust_turned"] = true
    saved_records["bust_turned"] = saved_bust
    legacy.set_value("progress", "records", saved_records)
    var saved_stats: Dictionary = legacy.get_value("progress", "stats", {})
    saved_stats["achievements"]["archive_complete"] = true
    legacy.set_value("progress", "stats", saved_stats)
    if not require(legacy.save(profiles.progress_path(5)) == OK and profiles.select_profile(5), "Could not reload historical profile"):
        return
    if not require(profiles.get_records() == saved_records and profiles.get_stats()["xp"] == saved_stats["xp"] and profiles.get_stats()["achievements"]["archive_complete"] and Progress.counts(profiles.get_records())["variants"] == 1, "Historical profile was rewritten or retired forms counted"):
        return
    var picker := Picker.new()
    var archive := Archive.new()
    root.add_child(picker)
    root.add_child(archive)
    await process_frame
    for tab in ["archive", "stats", "achievements", "modes", "last"]:
        archive.show_mode(tab)
        await process_frame
    # A real Classic completion awards the new Nightmare unlock, keeps
    # the entire run's discoveries and level delta, and survives reload.
    if not require(profiles.select_mode("classic"),"Could not switch to Classic for results"):
        return
    _start(live,"classic")
    _answer(live,"",false)
    _answer(live,"entrance_label",true)
    _answer(live,"",true)
    for i in range(12):
        _answer(live,"",false)
    var report: Dictionary = live.get_run_report()
    if not require(live.finished and live.report_pending and int(report.get("rooms",0)) == 15 and int(report.get("resets",0)) == 1 and int(report.get("identified",{}).get("entrance_label",0)) == 1 and bool(report.get("new_discoveries",{}).get("entrance_label",false)) and bool(report.get("new_modes",{}).get("nightmare",false)) and bool(report.get("new_achievements",{}).get("classic_completions_1",false)) and int(report.get("xp_earned",0)) > 0,"Run results lost discoveries, resets, XP or actual first-clear unlock"):
        return
    if not require(live.load_run() and live.report_pending and live.get_run_report() == report,"Completed run report lost on reload"):
        return
    var results = preload("res://ui/run_results_panel.gd").new()
    results.set_report(report)
    root.add_child(results)
    await process_frame
    if not require(results.find_child("RunResultsContinue",true,false) != null,"Results screen missing continue button"):
        return
    results.queue_free()
    live.acknowledge_run_report()
    if not require(live.load_run() and not live.report_pending and live.get_run_report() == report,"Dismissed results must not reopen or erase the report"):
        return
    if not require(profiles.delete_profile(5), "Could not remove test profile"):
        return
    picker.queue_free()
    archive.queue_free()
    await process_frame
    print("Casino Anomaly progression QA PASS")
    quit(0)
