extends Node3D
## Runtime-only positional audio. Staged halls do not double-play sound.
var _sources: Array[AudioStreamPlayer3D] = []
var _target_db: Array[float] = []
var _built := false
var _active := false
var _fade: Tween


func _ready() -> void:
    call_deferred("_build")


func _build() -> void:
    if _built:
        return
    _built = true
    var room := get_parent() as Node3D
    var sound := get_node_or_null("/root/AudioDirector")
    if room == null or sound == null:
        return
    var slots := room.get_node_or_null("SlotMachines") as Node3D
    if slots != null:
        var index := 0
        for unit in slots.get_children():
            if not (unit is Node3D) or not str(unit.name).begins_with("Slot_"):
                continue
            if index % 3 == 0:
                _source("Cabinet_%02d" % index,
                    (unit as Node3D).position + Vector3(0.0, 1.30, 0.0),
                    "cabinet", -19.5, 10.0)
            index += 1
    _source("BarRefrigeration", Vector3(2.0, 2.0, -10.5),
        "bar", -22.0, 9.0)
    _source("ExitVentilation", Vector3(-43.0, 2.55, -6.6),
        "vent", -22.0, 9.0)
    if not room.has_meta("_streaming_standby"):
        activate()


func _source(label: String, at: Vector3, kind: String, level: float,
        reach: float) -> void:
    var sound := get_node_or_null("/root/AudioDirector")
    var stream = sound.get_immersion_loop(kind) if sound != null else null
    if stream == null:
        return
    var emitter := AudioStreamPlayer3D.new()
    emitter.name = label
    emitter.position = at
    emitter.stream = stream
    emitter.bus = "WORLD"
    emitter.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
    emitter.unit_size = 1.6
    emitter.max_distance = reach
    emitter.volume_db = -60.0
    add_child(emitter)
    _sources.append(emitter)
    _target_db.append(level)


func activate() -> void:
    if not _built:
        _build()
    if _active:
        return
    _active = true
    if _fade != null and _fade.is_running():
        _fade.kill()
    _fade = create_tween().set_parallel(true)
    for i in range(_sources.size()):
        var source := _sources[i]
        if not source.playing:
            source.volume_db = -60.0
            source.play()
        _fade.tween_property(source, "volume_db", _target_db[i], 1.35)


func _exit_tree() -> void:
    if _fade != null and _fade.is_running():
        _fade.kill()
    for source in _sources:
        if is_instance_valid(source):
            source.stop()
