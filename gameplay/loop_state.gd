extends Node
## Active profile run state; a ProfileManager owns the five save-slot paths.
## Never writes into res:// or the designer-authored casino scene.

const Modes = preload("res://gameplay/run_modes.gd")
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const REQUIRED_CORRECT := 12
const BACKROOMS_ID := "backrooms"
const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://anomaly_run.cfg"

var save_path: String = DEFAULT_SAVE_PATH
var mode := "classic"
var elapsed_seconds := 0.0
var run_assisted := false
var active := false
var tutorial_done := false
var finished := false
var round_ready := false
var correct_streak := 0
var visited_loops := 0
var mistakes := 0
var anomaly_id := ""
var last_anomaly_id := ""
var round_debugged := false
var last_verdict: Dictionary = {}
# Developer overrides are one-shot and intentionally not written to saves.
var debug_next_round_requested := false
var debug_next_anomaly_id := ""
var rng := RandomNumberGenerator.new()


func _ready() -> void:
    rng.randomize()
    # A run is loaded only after selecting an explicit player profile.


func reset_runtime() -> void:
    mode = "classic"
    elapsed_seconds = 0.0
    run_assisted = false
    active = false
    tutorial_done = false
    finished = false
    round_ready = false
    correct_streak = 0
    visited_loops = 0
    mistakes = 0
    anomaly_id = ""
    last_anomaly_id = ""
    round_debugged = false
    last_verdict.clear()
    debug_clear_next_round()


func has_continue() -> bool:
    return active and not finished and FileAccess.file_exists(save_path)


func start_new_run(next_mode: String = "classic") -> void:
    mode = Modes.normalize(next_mode)
    elapsed_seconds = 0.0
    run_assisted = false
    active = true
    tutorial_done = false
    finished = false
    round_ready = false
    correct_streak = 0
    visited_loops = 0
    mistakes = 0
    anomaly_id = ""
    last_anomaly_id = ""
    round_debugged = false
    last_verdict.clear()
    debug_clear_next_round()
    save_run()


func complete_tutorial() -> void:
    if not active:
        return
    tutorial_done = true
    save_run()


func prepare_round(available_anomalies: Array[String]) -> void:
    if not active or finished or not tutorial_done:
        return
    # The first playable casino room is a guaranteed reference room.
    # This also sanitizes old/incomplete saves that had already rolled a
    # random anomaly before this rule was introduced.
    if visited_loops == 0:
        anomaly_id = ""
        round_debugged = false
        round_ready = true
        save_run()
        return
    if round_ready and (anomaly_id.is_empty() or available_anomalies.has(anomaly_id)):
        return
    if debug_next_round_requested:
        # Consume once only AFTER the guaranteed clean first casino hall.
        anomaly_id = debug_next_anomaly_id
        round_debugged = true
        debug_clear_next_round()
    else:
        anomaly_id = _roll_random_anomaly(available_anomalies)
        round_debugged = false
    if not anomaly_id.is_empty():
        last_anomaly_id = anomaly_id
    round_ready = true
    save_run()


func _roll_random_anomaly(available_anomalies: Array[String]) -> String:
    if mode == "expedition":
        return BACKROOMS_ID if available_anomalies.has(BACKROOMS_ID) else ""
    if available_anomalies.is_empty() or rng.randf() >= (0.75 if mode == "research" else 0.5):
        return ""
    var groups := {}
    for id in available_anomalies:
        var family := Catalog.family(id)
        if not groups.has(family):
            groups[family] = []
        groups[family].append(id)
    if groups.size() > 1:
        groups.erase(Catalog.family(last_anomaly_id))
    var records := {}
    if is_inside_tree():
        var profiles := get_node_or_null("/root/ProfileManager")
        if profiles != null and profiles.active_slot > 0 and save_path == profiles.run_path(profiles.active_slot, mode):
            records = profiles.get_records()
    var weights := PackedFloat32Array()
    var families := groups.keys()
    for family in families:
        var entry := Catalog.get_entry(str(family))
        var weight := Catalog.rarity_weight(str(entry.get("rarity", "common")))
        if not bool(records.get(family, {}).get("recognized", false)):
            weight *= 8.0 if mode == "research" else 2.5
        weights.append(weight)
    var selected := str(families[rng.rand_weighted(weights)])
    var candidates: Array = groups[selected]
    var variant_weights := PackedFloat32Array()
    for id in candidates:
        var entry := Catalog.get_entry(str(id))
        var difficulty := int(entry.get("difficulty", 2))
        var weight := float(difficulty * difficulty) if mode == "nightmare" else 1.0
        if mode == "research" and not bool(records.get(selected, {}).get("variants", {}).get(id, false)):
            weight *= 3.0
        variant_weights.append(weight)
    return str(candidates[rng.rand_weighted(variant_weights)])


func tick_play_time(delta: float) -> void:
    if active and tutorial_done and mode == "time_trial":
        elapsed_seconds += maxf(delta, 0.0)


func progress_number() -> int:
    if mode in ["time_trial", "research", "expedition"]:
        return visited_loops
    return correct_streak


func _debug_allowed(id: String, available_anomalies: Array[String]) -> bool:
    return active and tutorial_done and not finished         and (id.is_empty() or available_anomalies.has(id))


func debug_queue_next_round(id: String, available_anomalies: Array[String]) -> bool:
    if not _debug_allowed(id, available_anomalies):
        return false
    debug_next_round_requested = true
    debug_next_anomaly_id = id
    return true


func debug_clear_next_round() -> void:
    debug_next_round_requested = false
    debug_next_anomaly_id = ""


func debug_replace_prepared_round(id: String, available_anomalies: Array[String]) -> bool:
    if not _debug_allowed(id, available_anomalies) or not round_ready or visited_loops == 0:
        return false
    anomaly_id = id
    round_debugged = true
    if not id.is_empty():
        last_anomaly_id = id
    save_run()
    return true


func debug_reroll_prepared_round(available_anomalies: Array[String]) -> bool:
    if not active or not tutorial_done or finished or not round_ready or visited_loops == 0:
        return false
    anomaly_id = _roll_random_anomaly(available_anomalies)
    round_debugged = true
    if not anomaly_id.is_empty():
        last_anomaly_id = anomaly_id
    save_run()
    return true


func decide(choose_anomaly: bool) -> Dictionary:
    if not active or not tutorial_done or not round_ready or finished:
        return {"valid": false, "correct": false, "finished": false}
    if visited_loops == 0:
        anomaly_id = ""
    # Backrooms is a traversal, never a binary door verdict.
    if anomaly_id == BACKROOMS_ID:
        return {"valid": false, "correct": false, "finished": false}
    return _resolve_decision(choose_anomaly, choose_anomaly == not anomaly_id.is_empty())


func complete_backrooms(choose_anomaly: bool) -> Dictionary:
    if not active or not tutorial_done or not round_ready or finished \
            or visited_loops == 0 or anomaly_id != BACKROOMS_ID:
        return {"valid": false, "correct": false, "finished": false}
    return _resolve_decision(choose_anomaly, true)


func _resolve_decision(choose_anomaly: bool, correct: bool) -> Dictionary:
    var actual_id := anomaly_id
    var previous_streak := correct_streak
    visited_loops += 1
    if correct:
        correct_streak += 1
    else:
        mistakes += 1
        if mode not in ["research", "time_trial", "expedition"]:
            correct_streak = 0
    run_assisted = run_assisted or round_debugged
    var failed := false
    match mode:
        "endless":
            finished = not correct
            failed = finished
        "nightmare":
            finished = not correct or correct_streak >= REQUIRED_CORRECT
            failed = not correct
        "research", "time_trial":
            finished = visited_loops >= Modes.target(mode)
        "expedition":
            finished = actual_id == BACKROOMS_ID and correct
        _:
            finished = correct_streak >= REQUIRED_CORRECT
    if finished:
        active = false
    var verdict := {
        "valid": true, "correct": correct, "finished": finished,
        "streak": correct_streak, "previous_streak": previous_streak,
        "visited": visited_loops, "mistakes": mistakes,
        "anomaly_id": actual_id, "choice_anomaly": choose_anomaly,
        "expected_anomaly": not actual_id.is_empty(),
        "debugged": round_debugged,
        "traversal": actual_id == BACKROOMS_ID,
        "mode": mode, "failed": failed, "assisted": run_assisted,
        "progress": progress_number(), "goal": Modes.target(mode),
        "elapsed_seconds": elapsed_seconds,
        "score_seconds": elapsed_seconds + mistakes * Modes.PENALTY_SECONDS
    }
    round_ready = false
    anomaly_id = ""
    round_debugged = false
    last_verdict = verdict.duplicate(true)
    save_run()
    # Local QA instances may use the same script; only the live autoload
    # can update the selected player's permanent discovery history.
    if self == get_node_or_null("/root/LoopState"):
        var profiles := get_node_or_null("/root/ProfileManager")
        if profiles != null and profiles.active_slot > 0 \
                and save_path == profiles.run_path(profiles.active_slot, mode):
            profiles.record_decision(verdict)
    return verdict


func save_run() -> void:
    var config := ConfigFile.new()
    config.set_value("run", "version", SAVE_VERSION)
    config.set_value("run", "mode", mode)
    config.set_value("run", "elapsed_seconds", elapsed_seconds)
    config.set_value("run", "assisted", run_assisted)
    config.set_value("run", "active", active)
    config.set_value("run", "tutorial_done", tutorial_done)
    config.set_value("run", "finished", finished)
    config.set_value("run", "round_ready", round_ready)
    config.set_value("run", "correct_streak", correct_streak)
    config.set_value("run", "visited_loops", visited_loops)
    config.set_value("run", "mistakes", mistakes)
    config.set_value("run", "anomaly_id", anomaly_id)
    config.set_value("run", "last_anomaly_id", last_anomaly_id)
    config.set_value("run", "round_debugged", round_debugged)
    config.set_value("run", "last_verdict", last_verdict)
    var error := config.save(save_path)
    if error != OK:
        push_warning("Anomaly run could not be saved: %s" % error)


func load_run() -> bool:
    var config := ConfigFile.new()
    if config.load(save_path) != OK:
        return false
    if int(config.get_value("run", "version", -1)) != SAVE_VERSION:
        return false
    mode = Modes.normalize(str(config.get_value("run", "mode", "classic")))
    elapsed_seconds = maxf(0.0, float(config.get_value("run", "elapsed_seconds", 0.0)))
    run_assisted = bool(config.get_value("run", "assisted", false))
    active = bool(config.get_value("run", "active", false))
    tutorial_done = bool(config.get_value("run", "tutorial_done", false))
    finished = bool(config.get_value("run", "finished", false))
    round_ready = bool(config.get_value("run", "round_ready", false))
    correct_streak = maxi(0, int(config.get_value("run", "correct_streak", 0)))
    if mode in ["classic", "nightmare"]:
        correct_streak = mini(correct_streak, REQUIRED_CORRECT)
    visited_loops = maxi(0, int(config.get_value("run", "visited_loops", 0)))
    mistakes = maxi(0, int(config.get_value("run", "mistakes", 0)))
    anomaly_id = str(config.get_value("run", "anomaly_id", ""))
    last_anomaly_id = str(config.get_value("run", "last_anomaly_id", ""))
    round_debugged = bool(config.get_value("run", "round_debugged", false))
    var saved_verdict: Variant = config.get_value("run", "last_verdict", {})
    last_verdict = saved_verdict if saved_verdict is Dictionary else {}
    debug_clear_next_round()
    if visited_loops == 0 and round_ready:
        anomaly_id = ""
    if finished:
        active = false
    return true
