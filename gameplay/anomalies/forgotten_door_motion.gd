extends Node3D
## The original wall stays solid. A black opaque recess is the entire view
## through the gap. The hinge carries every moving detail and its collider.
const KNOCK_PATH := "res://audio/anomalies/forgotten_door_knock.ogg"
const OPEN_ANGLE := 16.0
var hall: Node3D
var hinge: Node3D
var knock: AudioStreamPlayer3D
var opening := 0.0
var knock_clock := 9.0
var rng := RandomNumberGenerator.new()


func configure(room: Node3D, pivot: Node3D) -> void:
    hall = room
    hinge = pivot
    rng.randomize()
    if ResourceLoader.exists(KNOCK_PATH, "AudioStream"):
        var stream := load(KNOCK_PATH) as AudioStream
        if stream != null:
            # Never mutate a shared imported audio resource.
            stream = stream.duplicate() as AudioStream
            if stream is AudioStreamOggVorbis:
                (stream as AudioStreamOggVorbis).loop = false
            knock = AudioStreamPlayer3D.new()
            knock.name = "DoorKnock"
            knock.stream = stream
            knock.bus = "HORROR"
            knock.volume_db = -21.0
            knock.unit_size = 1.5
            knock.max_distance = 12.0
            add_child(knock)
            knock.position = Vector3(0.0, 0.15, 0.04)


static func proximity(distance: float) -> float:
    return 1.0 - smoothstep(1.35, 4.0, distance)


func advance(delta: float, distance: float, reduced: bool) -> void:
    var target := proximity(distance) * deg_to_rad(OPEN_ANGLE)
    # No restart or reversal tween: this bounded continuous response works
    # even when the player repeatedly crosses the activation range.
    opening = lerpf(opening, target, 1.0 - exp(-delta * (0.85 if reduced else 1.65)))
    hinge.rotation.y = opening


func _process(delta: float) -> void:
    if not is_instance_valid(hall) or hall.has_meta("_streaming_standby"):
        return
    var player := hall.get_node_or_null("Player") as Node3D
    if player == null:
        return
    var offset := player.global_position - global_position
    var distance := Vector2(offset.x, offset.z).length()
    var settings := hall.get_node_or_null("/root/GameSettings")
    var reduced := settings != null and bool(settings.call("get_option", "reduced_motion"))
    advance(delta, distance, reduced)
    if knock != null and distance < 10.0:
        knock_clock -= delta
        if knock_clock <= 0.0 and not knock.playing:
            knock.play()
            knock_clock = rng.randf_range(13.0, 29.0)
