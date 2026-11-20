extends RefCounted
## One reversible switch for every chandelier-related light in the casino.
## Existing authored fixtures are kept; only their real-time lights are
## disabled. Lighting unrelated to the chandeliers stays untouched.
##
## The recursive search also catches nested/added chandelier glow lights
## without needing to update the anomaly catalog as the room grows.

const EXTRA_FIXTURE_LIGHTS := [
    "Lighting/WarmCasinoLamp_03",
    "Lighting/WarmCasinoLamp_05"
]

var original: Array[Dictionary] = []


func _append_chandelier_lights(node: Node, result: Array[Light3D]) -> void:
    for child in node.get_children():
        if child is Light3D and str(child.name).begins_with("ChandelierWarmLight_"):
            result.append(child as Light3D)
        _append_chandelier_lights(child, result)


func lights_for(room: Node3D) -> Array[Light3D]:
    var result: Array[Light3D] = []
    if room == null:
        return result
    var furniture := room.get_node_or_null("ModelInteriors")
    if furniture != null:
        _append_chandelier_lights(furniture, result)
    for path in EXTRA_FIXTURE_LIGHTS:
        var light := room.get_node_or_null(path) as Light3D
        if light != null and not result.has(light):
            result.append(light)
    return result


func can_apply(room: Node3D, _definition: Dictionary) -> bool:
    # Do not show a no-op anomaly if the authored fixtures are absent.
    return lights_for(room).size() >= 2


func apply(room: Node3D, definition: Dictionary) -> bool:
    if not can_apply(room, definition):
        return false
    clear()
    for light in lights_for(room):
        original.append({
            "node": light,
            "energy": light.light_energy,
            "visible": light.visible
        })
        # Both properties are changed so future visibility-sync code or
        # renderer differences cannot silently restore illumination.
        light.light_energy = 0.0
        light.visible = false
    return true


func clear() -> void:
    for record in original:
        var light := record["node"] as Light3D
        if light != null and is_instance_valid(light):
            light.light_energy = float(record["energy"])
            light.visible = bool(record["visible"])
    original.clear()
