extends SceneTree
## Exercise the actual selection, verdict, save and resume path with seeded
## runs. The first room, mistakes, debug overrides and empty pools count as
## separate contracts. No statistical flaky pass/fail threshold.
const State = preload("res://gameplay/loop_state.gd")
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const SAVE := "user://classic_distribution_qa.cfg"
const OPTIONS: Array[String] = ["bar_label","bar_label__reverse","entrance_label","bust_turned__reverse"]
const EMPTY: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("Classic distribution QA: "+message)
    quit(1)

func _start(state: Node, seed_value: int, mode_name: String = "classic") -> void:
    state.start_new_run(mode_name)
    state.complete_tutorial()
    state.rng.seed = seed_value

func _answer(state: Node, correct: bool = true) -> Dictionary:
    var has_anomaly: bool = not str(state.anomaly_id).is_empty()
    return state.decide(has_anomaly if correct else not has_anomaly)

func _run() -> void:
    var state = State.new()
    state.save_path = SAVE
    for id in OPTIONS:
        if Catalog.get_entry(id).is_empty():
            _fail("Real catalog fixture missing: "+id)
            return
    var total_anomalies: int = 0
    for seed_value in range(96):
        _start(state,seed_value)
        var count: int = 0
        var normal_tail: int = 0
        var last_family: String = ""
        for round_index in range(12):
            state.prepare_round(OPTIONS)
            var id: String = state.anomaly_id
            var history_before: Array = state.classic_room_history.duplicate()
            state.prepare_round(OPTIONS)
            if state.anomaly_id != id or state.classic_room_history != history_before:
                _fail("Repeated preparation changed an already chosen room")
                return
            if round_index == 0 and not id.is_empty():
                _fail("First reference room must remain normal")
                return
            if id.is_empty():
                normal_tail += 1
                if normal_tail > 3:
                    _fail("Four normal rooms in a row")
                    return
            else:
                if not OPTIONS.has(id) or Catalog.family(id) == last_family:
                    _fail("Selection changed available-pool/family-repeat rules")
                    return
                last_family = Catalog.family(id)
                normal_tail = 0
                count += 1
            var verdict: Dictionary = _answer(state)
            if not bool(verdict.get("correct",false)):
                _fail("Selection interfered with the verdict")
                return
        if count < 7 or not state.finished:
            _fail("Classic completion had fewer than seven anomalies")
            return
        total_anomalies += count
    print("Classic distribution: ",total_anomalies," anomalies across 1152 rooms")

    # Mistakes reset the player's streak, not the encounter history.
    _start(state,271)
    var observed: Array[bool] = []
    for i in range(80):
        state.prepare_round(OPTIONS)
        var has_anomaly: bool = not str(state.anomaly_id).is_empty()
        observed.append(has_anomaly)
        _answer(state,i%4 != 0)
        if observed.size() > 12:
            observed.pop_front()
        if observed.size() == 12 and observed.count(true)<7:
            _fail("Rolling distribution lost its quota after a mistake")
            return
        if state.classic_room_history.size()>11:
            _fail("Encounter history grew beyond its bound")
            return
    # Restore a prepared round and its history without consuming a roll.
    state.prepare_round(OPTIONS)
    var pending: String = state.anomaly_id
    var history: Array = state.classic_room_history.duplicate()
    var resumed = State.new()
    resumed.save_path = SAVE
    if not resumed.load_run() or resumed.classic_room_history != history or resumed.anomaly_id != pending:
        _fail("Save/load lost distribution history or pending anomaly")
        return
    resumed.prepare_round(OPTIONS)
    if resumed.classic_room_history != history or resumed.anomaly_id != pending:
        _fail("Resuming rerolled the prepared room")
        return
    if not resumed.debug_replace_prepared_round("",OPTIONS):
        _fail("Developer override was blocked")
        return
    _answer(resumed)
    if resumed.classic_room_history != history:
        _fail("Developer-forced room consumed the organic distribution")
        return
    # No available effects: a normal room remains legal even at the cap.
    resumed.classic_room_history.assign([false,false,false,false,false])
    resumed.prepare_round(EMPTY)
    if not resumed.round_ready or not resumed.anomaly_id.is_empty():
        _fail("Empty candidate pool must produce a playable normal room")
        return
    _answer(resumed)
    resumed.prepare_round(OPTIONS)
    if resumed.anomaly_id.is_empty():
        _fail("Selection did not recover once anomalies became available")
        return

    # Legacy save with a known long normal streak: next fresh room forced.
    var legacy: ConfigFile = ConfigFile.new()
    legacy.set_value("run","version",State.SAVE_VERSION)
    legacy.set_value("run","mode","classic")
    legacy.set_value("run","active",true)
    legacy.set_value("run","tutorial_done",true)
    legacy.set_value("run","round_ready",false)
    legacy.set_value("run","visited_loops",8)
    legacy.set_value("run","correct_streak",8)
    legacy.set_value("run","normal_chain",8)
    legacy.save(SAVE)
    if not resumed.load_run() or resumed.correct_streak!=8 or resumed.classic_room_history.count(false)!=8:
        _fail("Legacy save lost known normal streak")
        return
    resumed.prepare_round(OPTIONS)
    if resumed.anomaly_id.is_empty():
        _fail("Legacy normal drought was not corrected")
        return

    # The other modes retain their previous distribution and achievements.
    for mode_name in ["endless","nightmare","time_trial","research","expedition"]:
        _start(state,123,mode_name)
        state.prepare_round(OPTIONS)
        _answer(state)
        if not state.classic_room_history.is_empty():
            _fail("Classic history leaked into "+mode_name)
            return
    state.free()
    resumed.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    print("Casino Anomaly Classic room distribution QA PASS")
    quit(0)
