extends RefCounted
const Actor = preload("res://gameplay/anomalies/escort_actor.gd")
const Rig = preload("res://gameplay/anomalies/escort_rig.gd")
var effect: CharacterBody3D

func can_apply(room: Node3D, entry: Dictionary) -> bool:
    return is_instance_valid(room) and not room.has_meta("_menu_showcase") and room.has_node(str(entry["target_path"])) and Rig.available()

func apply(room: Node3D, entry: Dictionary) -> bool:
    clear()
    if not can_apply(room,entry):
        return false
    effect = Actor.new()
    effect.name = "AnomalyEscort"
    room.add_child(effect)
    if not bool(effect.call("configure",room)):
        clear()
        return false
    return true

func clear() -> void:
    if is_instance_valid(effect):
        effect.free()
    effect = null
