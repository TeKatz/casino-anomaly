extends RefCounted
## Reusable 3D-label anomaly effect. The registry can also reference other
## modules for geometry, light, animation or sound anomalies later.
var target: Label3D
var previous_text := ""
var previous_color := Color.WHITE

func can_apply(room: Node3D, definition: Dictionary) -> bool:
    return room != null and room.get_node_or_null(
        str(definition.get("target_path", ""))) is Label3D

func apply(room: Node3D, definition: Dictionary) -> bool:
    if not can_apply(room, definition):
        return false
    target = room.get_node(str(definition["target_path"])) as Label3D
    previous_text = target.text
    previous_color = target.modulate
    target.text = str(definition["replacement_text"])
    # The legacy tint remains the default. Letter-only variants explicitly opt out.
    if not bool(definition.get("preserve_label_color", false)):
        target.modulate = Color("#f5a2a2")
    return true

func clear() -> void:
    if target != null and is_instance_valid(target):
        target.text = previous_text
        target.modulate = previous_color
    target = null
