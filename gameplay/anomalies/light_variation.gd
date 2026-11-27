extends RefCounted
## Reversible changes to existing authored lights. The original color,
## intensity, visibility and any temporary fixture alignment are restored exactly.
## No extra lights, geometry, editor changes or GI bake required.
var target: Light3D
var old_color := Color.WHITE
var old_energy := 1.0
var old_visible := true
var old_position := Vector3.ZERO
var moved_to_anchor := false


func can_apply(room: Node3D, definition: Dictionary) -> bool:
    if room == null:
        return false
    if not (room.get_node_or_null(str(definition.get("target_path", ""))) is Light3D):
        return false
    var reference_path := str(definition.get("energy_reference_path", ""))
    if not reference_path.is_empty() and not (room.get_node_or_null(reference_path) is Light3D):
        return false
    var anchor_path := str(definition.get("light_anchor_path", ""))
    return anchor_path.is_empty() or room.get_node_or_null(anchor_path) is Node3D


func apply(room: Node3D, definition: Dictionary) -> bool:
    if not can_apply(room, definition):
        return false
    clear()
    target = room.get_node(str(definition["target_path"])) as Light3D
    old_color = target.light_color
    old_energy = target.light_energy
    old_visible = target.visible
    old_position = target.position

    var anchor_path := str(definition.get("light_anchor_path", ""))
    if not anchor_path.is_empty():
        var anchor := room.get_node(anchor_path) as Node3D
        # The model wrapper is authored at the lower end of the fixture.
        # Align in world space so nested light transforms and streamed room
        # rotations cannot displace the blue light from the actual fixture.
        target.global_position = anchor.global_position + Vector3.UP * 0.12
        moved_to_anchor = true

    if definition.has("color"):
        target.light_color = definition["color"]
    if definition.has("energy_scale"):
        # Retargeting an effect to a physical fixture must not change its
        # authored anomalous energy just because that fixture has a weaker normal glow.
        var baseline_energy := old_energy
        var reference_path := str(definition.get("energy_reference_path", ""))
        if not reference_path.is_empty():
            var reference := room.get_node(reference_path) as Light3D
            baseline_energy = reference.light_energy
        target.light_energy = baseline_energy * float(definition["energy_scale"])
    if definition.has("visible"):
        target.visible = bool(definition["visible"])
    return true


func clear() -> void:
    if target != null and is_instance_valid(target):
        target.light_color = old_color
        target.light_energy = old_energy
        target.visible = old_visible
        if moved_to_anchor:
            target.position = old_position
    target = null
    moved_to_anchor = false
