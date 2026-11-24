extends Node
## Five independent player profiles. Run state, journal and statistics live in
## separate files. The canonical anomaly IDs, NOT a cached catalog, are saved.
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const Progress = preload("res://gameplay/progression.gd")
const Modes = preload("res://gameplay/run_modes.gd")
const SLOT_COUNT := 5
const ROOT := "user://profiles"
const LEGACY_RUN := "user://anomaly_run.cfg"
const VERSION := 1
const HISTORY_LIMIT := 20

signal profile_changed
signal progress_changed

var active_slot := 0
var active_mode := "classic"
var records: Dictionary = {}
var stats: Dictionary = {}
var history: Array = []


func _ready() -> void:
    _migrate_legacy_run()


func _valid(slot: int) -> bool:
    return slot >= 1 and slot <= SLOT_COUNT


func _directory(slot: int) -> String:
    return ROOT.path_join("slot_%02d" % slot)


func profile_path(slot: int) -> String:
    return _directory(slot).path_join("profile.cfg")


func run_path(slot: int, mode: String = "classic") -> String:
    var normalized := Modes.normalize(mode)
    return _directory(slot).path_join("run.cfg" if normalized == "classic" else "run_" + normalized + ".cfg")


func progress_path(slot: int) -> String:
    return _directory(slot).path_join("progress.cfg")


func profile_exists(slot: int) -> bool:
    return _valid(slot) and FileAccess.file_exists(profile_path(slot))


func _ensure_directory(slot: int) -> bool:
    return DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(_directory(slot))) == OK


func _normalize_name(name: String, slot: int) -> String:
    var clean := name.strip_edges().substr(0, 32)
    return clean if not clean.is_empty() else "Profil %d" % slot


func _write_profile(slot: int, name: String) -> bool:
    if not _ensure_directory(slot):
        return false
    var config := ConfigFile.new()
    config.set_value("profile", "version", VERSION)
    config.set_value("profile", "name", _normalize_name(name, slot))
    return config.save(profile_path(slot)) == OK


func create_profile(slot: int, name: String = "") -> bool:
    if not _valid(slot) or profile_exists(slot):
        return false
    if not _write_profile(slot, name):
        return false
    if select_profile(slot):
        _save_progress()
        return true
    return false


func select_profile(slot: int) -> bool:
    if not profile_exists(slot):
        return false
    var previous_mode := active_mode if active_slot == slot else "classic"
    active_slot = slot
    _load_progress()
    return select_mode(previous_mode)


func select_mode(mode: String) -> bool:
    if not profile_exists(active_slot):
        return false
    active_mode = Modes.normalize(mode)
    if not Modes.unlock(active_mode, stats, records):
        active_mode = "classic"
    var loop := get_node_or_null("/root/LoopState")
    if loop != null:
        loop.save_path = run_path(active_slot, active_mode)
        loop.reset_runtime()
        loop.mode = active_mode
        loop.load_run()
    profile_changed.emit()
    return true


func rename_profile(slot: int, name: String) -> bool:
    if not profile_exists(slot) or name.strip_edges().is_empty():
        return false
    var result := _write_profile(slot, name)
    if result:
        profile_changed.emit()
    return result


func delete_profile(slot: int) -> bool:
    if not profile_exists(slot):
        return false
    if slot == active_slot:
        active_slot = 0
        active_mode = "classic"
        records.clear()
        stats.clear()
        history.clear()
        var loop := get_node_or_null("/root/LoopState")
        if loop != null:
            loop.reset_runtime()
            loop.save_path = loop.DEFAULT_SAVE_PATH
    var paths := [profile_path(slot), progress_path(slot)]
    for mode in Modes.IDS:
        paths.append(run_path(slot, mode))
    for filename in paths:
        var path := ProjectSettings.globalize_path(filename)
        if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
            return false
    # Leave a directory behind only when additional files are present.
    DirAccess.remove_absolute(ProjectSettings.globalize_path(_directory(slot)))
    profile_changed.emit()
    return true


func _read_progress(slot: int) -> Dictionary:
    var config := ConfigFile.new()
    if not _valid(slot) or config.load(progress_path(slot)) != OK:
        return {"records": {}, "stats": {}, "history": []}
    if int(config.get_value("progress", "version", 0)) != VERSION:
        return {"records": {}, "stats": {}, "history": []}
    var saved_records: Variant = config.get_value("progress", "records", {})
    var saved_stats: Variant = config.get_value("progress", "stats", {})
    var saved_history: Variant = config.get_value("progress", "history", [])
    var result := {
        "records": saved_records if saved_records is Dictionary else {},
        "stats": saved_stats if saved_stats is Dictionary else {},
        "history": saved_history if saved_history is Array else []
    }
    Progress.migrate(result["stats"], result["records"])
    Progress.evaluate(result["stats"], result["records"])
    return result


func _load_progress() -> void:
    var data := _read_progress(active_slot)
    records = data["records"]
    stats = data["stats"]
    history = data["history"]
    Progress.migrate(stats, records)
    Progress.evaluate(stats, records)


func _save_progress() -> void:
    if not profile_exists(active_slot):
        return
    var config := ConfigFile.new()
    config.set_value("progress", "version", VERSION)
    config.set_value("progress", "records", records)
    config.set_value("progress", "stats", stats)
    config.set_value("progress", "history", history)
    if config.save(progress_path(active_slot)) != OK:
        push_warning("Could not save anomaly progress for profile %d" % active_slot)
    else:
        progress_changed.emit()


func _recognized_count(saved_records: Dictionary) -> int:
    var total := 0
    for id in Catalog.discoverable_ids():
        var record: Dictionary = saved_records.get(id, {})
        if bool(record.get("recognized", false)):
            total += 1
    return total


func get_summary(slot: int, mode: String = "classic") -> Dictionary:
    if not profile_exists(slot):
        return {"exists": false, "slot": slot}
    var metadata := ConfigFile.new()
    metadata.load(profile_path(slot))
    var progress := _read_progress(slot)
    var saved_records: Dictionary = progress["records"]
    var saved_stats: Dictionary = progress["stats"]
    var catalog_total := Catalog.discoverable_ids().size()
    var discovered := _recognized_count(saved_records)
    var level := 0
    var can_continue := false
    var run := ConfigFile.new()
    if run.load(run_path(slot, mode)) == OK:
        level = maxi(0, int(run.get_value("run", "correct_streak", 0)))
        can_continue = bool(run.get_value("run", "active", false)) \
            and not bool(run.get_value("run", "finished", false))
    return {
        "exists": true, "slot": slot,
        "name": str(metadata.get_value("profile", "name", "Profil %d" % slot)),
        "discovered": discovered, "total": catalog_total,
        "percent": 0.0 if catalog_total == 0 else 100.0 * discovered / catalog_total,
        "level": level, "can_continue": can_continue,
        "completions": int(saved_stats.get("completions", 0)),
        "player_level": Progress.level_info(int(saved_stats.get("xp", 0)))["level"],
        "xp": int(saved_stats.get("xp", 0)),
        "achievements": saved_stats.get("achievements", {}).size()
    }


func active_summary() -> Dictionary:
    return get_summary(active_slot, active_mode)


func get_records() -> Dictionary:
    return records.duplicate(true)


func get_stats() -> Dictionary:
    return stats.duplicate(true)


func get_history() -> Array:
    return history.duplicate(true)


func latest_report() -> Dictionary:
    return history.back().duplicate(true) if not history.is_empty() else {}


func record_decision(verdict: Dictionary) -> void:
    # Developer-forced rooms never count toward player collection/statistics.
    if not profile_exists(active_slot) or not bool(verdict.get("valid", false)) \
            or bool(verdict.get("debugged", false)):
        return
    Progress.migrate(stats, records)
    var id := str(verdict.get("anomaly_id", ""))
    var correct := bool(verdict.get("correct", false))
    stats["rooms"] = int(stats.get("rooms", 0)) + 1
    if correct:
        stats["correct"] = int(stats.get("correct", 0)) + 1
    else:
        stats["mistakes"] = int(stats.get("mistakes", 0)) + 1
        if id.is_empty():
            stats["false_alarms"] = int(stats.get("false_alarms", 0)) + 1
    if not bool(verdict.get("assisted", false)) and str(verdict.get("mode", "classic")) == "classic":
        stats["best_streak"] = maxi(int(stats.get("best_streak", 0)), int(verdict.get("streak", 0)))
    if bool(verdict.get("finished", false)) and not bool(verdict.get("failed", false)) and not bool(verdict.get("assisted", false)):
        stats["completions"] = int(stats.get("completions", 0)) + 1
    var first := false
    if not id.is_empty() and not Catalog.get_entry(id).is_empty():
        var family := Catalog.family(id)
        var record: Dictionary = records.get(family, {})
        record["encounters"] = int(record.get("encounters", 0)) + 1
        if correct:
            first = not bool(record.get("recognized", false))
            record["recognized"] = true
            record["correct"] = int(record.get("correct", 0)) + 1
            var variants: Dictionary = record.get("variants", {})
            variants[id] = true
            record["variants"] = variants
        else:
            # An encountered-but-missed effect remains explicitly locked.
            # Never revoke an unlock earned during an earlier run.
            record["recognized"] = bool(record.get("recognized", false))
            record["missed"] = int(record.get("missed", 0)) + 1
        records[family] = record
    if not id.is_empty():
        stats["discovery_drought"] = 0 if first else int(stats.get("discovery_drought", 0)) + 1
    var report := verdict.duplicate(true)
    report["xp_earned"] = Progress.award(stats, records, verdict, first)
    Progress.evaluate(stats, records)
    history.append(report)
    while history.size() > HISTORY_LIMIT:
        history.pop_front()
    _save_progress()


func _migration_marker() -> String:
    return ROOT.path_join("legacy_migration_done.flag")


func _mark_migrated() -> void:
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT)) != OK:
        return
    var marker := FileAccess.open(_migration_marker(), FileAccess.WRITE)
    if marker != null:
        marker.store_string("1")


func _migrate_legacy_run() -> void:
    # Never resurrect a deliberately deleted slot after importing once.
    if not FileAccess.file_exists(LEGACY_RUN) or FileAccess.file_exists(_migration_marker()):
        return
    if profile_exists(1):
        _mark_migrated()
        return
    var legacy := ConfigFile.new()
    if legacy.load(LEGACY_RUN) != OK or int(legacy.get_value("run", "version", 0)) != 1:
        return
    if not _ensure_directory(1):
        return
    if DirAccess.copy_absolute(ProjectSettings.globalize_path(LEGACY_RUN),
            ProjectSettings.globalize_path(run_path(1))) != OK:
        return
    if _write_profile(1, "Profil 1 (importiert)"):
        _mark_migrated()
    else:
        push_warning("Legacy anomaly save was copied but profile creation failed")
