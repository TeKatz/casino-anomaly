extends RefCounted
## Reversible changes to existing authored lights. The original color,
## intensity and visibility are restored exactly after the room decision.
## No extra lights, geometry, editor changes or GI bake required.
var target: Light3D
var old_color := Color.WHITE
var old_energy := 1.0
var old_visible := true


func can_apply(room: Node3D, definition: Dictionary) -> bool:
    if room == null:
        return false
    return room.get_node_or_null(str(definition.get("target_path", ""))) is Light3D


func apply(room: Node3D, definition: Dictionary) -> bool:
    if not can_apply(room, definition):
        return false
    target = room.get_node(str(definition["target_path"])) as Light3D
    old_color = target.light_color
    old_energy = target.light_energy
    old_visible = target.visible

    if definition.has("color"):
        target.light_color = definition["color"]
    if definition.has("energy_scale"):
        target.light_energy = old_energy * float(definition["energy_scale"])
    if definition.has("visible"):
        target.visible = bool(definition["visible"])
    return true


func clear() -> void:
    if target != null and is_instance_valid(target):
        target.light_color = old_color
        target.light_energy = old_energy
        target.visible = old_visible
    target = null
