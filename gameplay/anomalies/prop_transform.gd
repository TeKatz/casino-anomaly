extends RefCounted
## A reversible, runtime-only movement/rotation of an existing scene node.
## Move the common parent so imported meshes, supporting subparts and any
## child collision shapes keep their relative layout. Never edit gameplay/casino/main.tscn.
var target: Node3D
var original_transform := Transform3D.IDENTITY


func can_apply(room: Node3D, definition: Dictionary) -> bool:
    if room == null:
        return false
    var node := room.get_node_or_null(str(definition.get("target_path", "")))
    return node is Node3D


func apply(room: Node3D, definition: Dictionary) -> bool:
    if not can_apply(room, definition):
        return false
    target = room.get_node(str(definition["target_path"])) as Node3D
    original_transform = target.transform

    # Positions are room-parent-local, not global: streamed halls may be
    # rotated 180 degrees and these small changes must rotate with them.
    var offset: Vector3 = definition.get("position_offset", Vector3.ZERO)
    target.position += offset
    var turn: Vector3 = definition.get("rotation_degrees", Vector3.ZERO)
    if not is_zero_approx(turn.x):
        target.rotate_object_local(Vector3.RIGHT, deg_to_rad(turn.x))
    if not is_zero_approx(turn.y):
        target.rotate_object_local(Vector3.UP, deg_to_rad(turn.y))
    if not is_zero_approx(turn.z):
        target.rotate_object_local(Vector3.BACK, deg_to_rad(turn.z))
    return true


func clear() -> void:
    if target != null and is_instance_valid(target):
        target.transform = original_transform
    target = null
