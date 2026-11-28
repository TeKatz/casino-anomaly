extends Node
## Durable, local-only diagnostic breadcrumbs. Never participates in save
## data or changes the loading path. The external monitor survives native crashes.
const ROOT := "user://crash_reports"
const MAX_JOURNAL_BYTES := 262144
var session_dir := ""
var enabled := false
var _version: Dictionary = {}
var _heartbeat_elapsed := 0.0
var _scene_path := ""
var _heartbeat_interval := 15.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if DisplayServer.get_name() == "headless":
        set_process(false)
        return
    var stamp := Time.get_datetime_string_from_system(true).replace(":", "-")
    var folder := ROOT.path_join(stamp + "-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec()))
    begin_session(folder)
    if enabled and OS.get_name() == "Windows" and not OS.has_feature("editor"):
        _launch_monitor()


func begin_session(folder: String) -> void:
    if enabled:
        return
    session_dir = folder
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
        push_warning("Crash journal directory unavailable")
        return
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://version.json"))
    _version = data if data is Dictionary else {}
    var header := {
        "schema": 1, "pid": OS.get_process_id(),
        "started_utc": Time.get_datetime_string_from_system(true),
        "version": _version.get("version", "unknown"),
        "commit": _version.get("commit", "unknown"),
        "engine": Engine.get_version_info().get("string", "unknown"),
        "os": OS.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
        "gpu": RenderingServer.get_video_adapter_name(),
        "driver": RenderingServer.get_current_rendering_driver_name()
    }
    if not _write_json(session_dir.path_join("session.json"), header):
        push_warning("Crash journal session header unavailable")
        return
    enabled = true
    set_process(true)
    record("session_started")


func _write_json(path: String, data: Dictionary) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(data) + "\n")
    file.flush()
    var ok := file.get_error() == OK
    file.close()
    return ok


func record(event: String, details: Dictionary = {}) -> void:
    if not enabled:
        return
    var path := session_dir.path_join("events.jsonl")
    if FileAccess.file_exists(path):
        var previous := FileAccess.open(path, FileAccess.READ)
        if previous != null:
            var size := previous.get_length()
            previous.close()
            if size >= MAX_JOURNAL_BYTES:
                var absolute := ProjectSettings.globalize_path(path)
                var rotated := ProjectSettings.globalize_path(session_dir.path_join("events.previous.jsonl"))
                if FileAccess.file_exists(rotated):
                    DirAccess.remove_absolute(rotated)
                if DirAccess.rename_absolute(absolute, rotated) != OK:
                    return
    var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
    if file == null:
        return
    file.seek_end()
    var current := get_tree().current_scene
    var entry := {
        "utc": Time.get_datetime_string_from_system(true),
        "ticks_ms": Time.get_ticks_msec(), "event": event,
        "scene": current.scene_file_path if current != null else "",
        "details": details,
        "memory": {
            "engine_static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
            "video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
            "texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
            "buffer_bytes": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)
        }
    }
    file.store_line(JSON.stringify(entry))
    file.flush()
    file.close()


func _process(delta: float) -> void:
    if not enabled:
        return
    var current := get_tree().current_scene
    var path: String = current.scene_file_path if current != null else ""
    if path != _scene_path:
        _scene_path = path
        record("scene_changed", {"path": path})
    _heartbeat_elapsed += delta
    if _heartbeat_elapsed >= _heartbeat_interval:
        _heartbeat_elapsed = 0.0
        record("heartbeat")


func _launch_monitor() -> void:
    var source := OS.get_executable_path().get_base_dir().path_join("tools/updater/CasinoAnomaly.Updater.exe")
    if not FileAccess.file_exists(source):
        record("monitor_unavailable", {"reason": "missing_helper"})
        return
    # Keep the monitor outside the installation, just as the updater is.
    # A content-keyed copy avoids rewriting the helper on every launch and
    # prevents the old helper from holding a lock during an in-game update.
    var hash_value := FileAccess.get_sha256(source)
    if hash_value.length() != 64:
        record("monitor_unavailable", {"reason": "helper_hash"})
        return
    var helper_dir := OS.get_user_data_dir().path_join("crash-helper").path_join(hash_value)
    if DirAccess.make_dir_recursive_absolute(helper_dir) != OK:
        record("monitor_unavailable", {"reason": "helper_directory"})
        return
    var helper := helper_dir.path_join("CasinoAnomaly.Updater.exe")
    if not FileAccess.file_exists(helper) or FileAccess.get_sha256(helper) != hash_value:
        var temporary := helper + "." + str(OS.get_process_id()) + ".tmp"
        if DirAccess.copy_absolute(source, temporary) != OK:
            record("monitor_unavailable", {"reason": "helper_copy"})
            return
        if FileAccess.get_sha256(temporary) != hash_value:
            DirAccess.remove_absolute(temporary)
            record("monitor_unavailable", {"reason": "helper_copy_hash"})
            return
        if DirAccess.rename_absolute(temporary, helper) != OK:
            DirAccess.remove_absolute(temporary)
            if not FileAccess.file_exists(helper) or FileAccess.get_sha256(helper) != hash_value:
                record("monitor_unavailable", {"reason": "helper_install"})
                return
    var pid := OS.create_process(helper, PackedStringArray(["--monitor-crash", str(OS.get_process_id()), ProjectSettings.globalize_path(session_dir)]), false)
    record("monitor_launched" if pid > 0 else "monitor_unavailable", {"monitor_pid": pid})


func _exit_tree() -> void:
    if not enabled:
        return
    record("engine_shutdown")
    _write_json(session_dir.path_join("shutdown.json"), {"pid": OS.get_process_id(), "utc": Time.get_datetime_string_from_system(true)})
    enabled = false
