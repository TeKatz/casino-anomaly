extends RefCounted
## Major event 01. One runtime root owns every surface, audio source,
## card and particle; the base room, collision and run state stay intact.
const Flood = preload("res://gameplay/anomalies/flood_event.gd")
var effect: Node3D


func can_apply(room: Node3D, entry: Dictionary) -> bool:
    if not is_instance_valid(room):
        return false
    var main := room.get_node_or_null(str(entry["target_path"])) as MeshInstance3D
    var west := room.get_node_or_null("Architecture/OakWestWing") as MeshInstance3D
    return main != null and main.mesh != null and west != null and west.mesh != null and not room.has_meta("_menu_showcase")


func apply(room: Node3D, entry: Dictionary) -> bool:
    clear()
    if not can_apply(room, entry):
        return false
    effect = Flood.new()
    effect.name = "AnomalyFlood"
    room.add_child(effect)
    if not effect.call("configure",room,room.get_node(str(entry["target_path"])),room.get_node("Architecture/OakWestWing")):
        clear()
        return false
    return true


func clear() -> void:
    if is_instance_valid(effect):
        effect.free()
    effect = null
