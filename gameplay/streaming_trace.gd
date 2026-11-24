@tool
extends RefCounted
## Opt-in diagnostic only. No I/O while capturing and no per-frame allocation
## when disabled. Frames and spans share a monotonic microsecond time base.
const PATH := "user://streaming_trace.json"
const MAX_FRAMES := 36000
const MAX_SPANS := 4096
static var enabled := false
static var _origin_us := 0
static var _previous_us := 0
static var _frames: Array[Dictionary] = []
static var _spans: Array[Dictionary] = []
static var _dropped_frames := 0
static var _dropped_spans := 0

static func start() -> void:
    _frames.clear()
    _spans.clear()
    _dropped_frames = 0
    _dropped_spans = 0
    _origin_us = Time.get_ticks_usec()
    _previous_us = 0
    enabled = true

static func begin() -> int:
    return Time.get_ticks_usec() if enabled else -1

static func finish(label: String, started: int) -> void:
    if not enabled or started < _origin_us:
        return
    if _spans.size() >= MAX_SPANS:
        _dropped_spans += 1
        return
    var now := Time.get_ticks_usec()
    _spans.append({"label": label, "frame": Engine.get_process_frames(),
        "start_us": started - _origin_us, "end_us": now - _origin_us,
        "duration_ms": float(now - started) / 1000.0})

static func sample(delta: float, phase: String, local: Vector3, pending: int, staged: bool) -> void:
    if not enabled:
        return
    var now := Time.get_ticks_usec()
    var interval_ms := float(now - _previous_us) / 1000.0 if _previous_us > 0 else 0.0
    _previous_us = now
    if _frames.size() >= MAX_FRAMES:
        _dropped_frames += 1
        return
    _frames.append({"frame": Engine.get_process_frames(), "time_us": now - _origin_us,
        "interval_ms": interval_ms, "delta_ms": delta * 1000.0,
        "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
        "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
        "phase": phase, "x": local.x, "z": local.z, "pending": pending, "staged": staged})

static func report() -> Dictionary:
    return {"version": 1, "frames": _frames, "spans": _spans,
        "dropped_frames": _dropped_frames, "dropped_spans": _dropped_spans,
        "notes": "Frame intervals are wall-clock time between process callbacks. Engine process/physics monitors are not GPU timestamps. Spans measure synchronous calls only; correlate their timestamps with following frame intervals."}

static func stop(save: bool = true) -> void:
    enabled = false
    if save:
        var file := FileAccess.open(PATH, FileAccess.WRITE)
        if file != null:
            file.store_string(JSON.stringify(report()))
            file.close()
            print("[StreamingTrace] Saved ", _frames.size(), " frames, ", _spans.size(),
                " spans to ", ProjectSettings.globalize_path(PATH))
        else:
            push_warning("StreamingTrace could not write " + PATH)
    _frames.clear()
    _spans.clear()
