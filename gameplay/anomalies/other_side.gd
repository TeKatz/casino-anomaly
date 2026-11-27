extends RefCounted
## Major event 02. Isolated render world, room-local reversible wall.
const OtherSide = preload("res://gameplay/anomalies/other_side_event.gd")
var effect: Node3D


func can_apply(room: Node3D, entry: Dictionary) -> bool:
    if not is_instance_valid(room) or room.has_meta("_menu_showcase"):
        return false
    var wall := room.get_node_or_null(str(entry["target_path"])) as MeshInstance3D
    return wall != null and wall.mesh is BoxMesh and wall.visible and room.has_node("Architecture/OakWestWing")


func apply(room: Node3D, entry: Dictionary) -> bool:
    clear()
    if not can_apply(room,entry):
        return false
    effect = OtherSide.new()
    effect.name = "AnomalyOtherSide"
    room.add_child(effect)
    if not bool(effect.call("configure",room,room.get_node(str(entry["target_path"])))):
        clear()
        return false
    return true


func clear() -> void:
    if is_instance_valid(effect):
        effect.free()
    effect = null
