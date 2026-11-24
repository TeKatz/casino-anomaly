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
    if not require(ids.size() >= 14 and Catalog.entries().size() >= 30 and Catalog.family("bust_turned__reverse") == "bust_turned", "Family or variant registry incorrect"):
        return
    var definitions := Progress.achievement_definitions()
    var seen := {}
    for entry in definitions:
        if not require(not seen.has(entry["id"]), "Duplicate achievement ID"):
            return
        seen[entry["id"]] = true
    if not require(definitions.size() >= 40, "Achievement list incomplete"):
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
    _answer(live, "bust_turned", true)
    if not require(int(profiles.get_stats()["xp"]) == 275, "Base form awarded duplicate family discovery"):
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
    var picker := Picker.new()
    var archive := Archive.new()
    root.add_child(picker)
    root.add_child(archive)
    await process_frame
    for tab in ["archive", "stats", "achievements", "modes", "last"]:
        archive.show_mode(tab)
        await process_frame
    if not require(profiles.delete_profile(5), "Could not remove test profile"):
        return
    picker.queue_free()
    archive.queue_free()
    await process_frame
    print("Casino Anomaly progression QA PASS")
    quit(0)
