extends RefCounted
## Major event 33. Entirely room-owned and reversible.
const Audience = preload("res://gameplay/anomalies/silent_audience_event.gd")
var effect: Node3D


func can_apply(room: Node3D, entry: Dictionary) -> bool:
    return is_instance_valid(room) and not room.has_meta("_menu_showcase") \
        and room.get_node_or_null(str(entry["target_path"])) != null \
        and room.has_node("ModelInteriors/CounterStool_01") \
        and ResourceLoader.exists(Audience.MODEL_PATH, "PackedScene")


func apply(room: Node3D, entry: Dictionary) -> bool:
    clear()
    if not can_apply(room, entry):
        return false
    effect = Audience.new()
    effect.name = "AnomalySilentAudience"
    room.add_child(effect)
    if not bool(effect.call("configure", room)):
        clear()
        return false
    return true


func clear() -> void:
    if is_instance_valid(effect):
        effect.free()
    effect = null
