extends Node
## Active profile run state; a ProfileManager owns the five save-slot paths.
## Never writes into res:// or the designer-authored casino scene.

const REQUIRED_CORRECT := 12
const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://anomaly_run.cfg"

var save_path: String = DEFAULT_SAVE_PATH
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


func start_new_run() -> void:
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
    if available_anomalies.is_empty() or rng.randf() >= 0.5:
        return ""
    var candidates := available_anomalies.duplicate()
    if candidates.size() > 1:
        candidates.erase(last_anomaly_id)
    return candidates[rng.randi_range(0, candidates.size() - 1)]


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
    var actual_id := anomaly_id
    var previous_streak := correct_streak
    var correct := choose_anomaly == not actual_id.is_empty()
    visited_loops += 1
    if correct:
        correct_streak += 1
    else:
        correct_streak = 0
        mistakes += 1
    finished = correct_streak >= REQUIRED_CORRECT
    if finished:
        active = false
    var verdict := {
        "valid": true, "correct": correct, "finished": finished,
        "streak": correct_streak, "previous_streak": previous_streak,
        "visited": visited_loops, "mistakes": mistakes,
        "anomaly_id": actual_id, "choice_anomaly": choose_anomaly,
        "expected_anomaly": not actual_id.is_empty(),
        "debugged": round_debugged
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
                and save_path == profiles.run_path(profiles.active_slot):
            profiles.record_decision(verdict)
    return verdict


func save_run() -> void:
    var config := ConfigFile.new()
    config.set_value("run", "version", SAVE_VERSION)
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
    active = bool(config.get_value("run", "active", false))
    tutorial_done = bool(config.get_value("run", "tutorial_done", false))
    finished = bool(config.get_value("run", "finished", false))
    round_ready = bool(config.get_value("run", "round_ready", false))
    correct_streak = clampi(int(config.get_value("run", "correct_streak", 0)), 0, REQUIRED_CORRECT)
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
