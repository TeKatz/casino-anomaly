extends RefCounted
## The anomaly is resolved by LoopController, not by mutating a casino prop.
func can_apply(room: Node3D, definition: Dictionary) -> bool:
    return room != null and room.has_node(str(definition.get("target_path", "")))

func apply(room: Node3D, definition: Dictionary) -> bool:
    return can_apply(room, definition)

func clear() -> void:
    pass
