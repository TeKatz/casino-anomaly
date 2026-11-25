extends RefCounted
## Batch 01: reversible, instance-local visual changes. No scene edits,
## collision edits, global resource mutation or gameplay state changes.
var changed: Array[Dictionary] = []


func targets(room: Node3D, entry: Dictionary) -> Array[Node3D]:
    var result: Array[Node3D] = []
    if not is_instance_valid(room):
        return result
    var base := room.get_node_or_null(str(entry.get("target_path", ""))) as Node3D
    if base == null:
        return result
    match str(entry.get("id", "")):
        "blank_reels", "false_jackpot", "dark_marquee":
            var slots: Array[Node3D] = []
            for child in base.get_children():
                if child is Node3D and child.visible and child.has_meta("slot_cabinet_revision"):
                    slots.append(child as Node3D)
            # Stable authored order; distinct cabinets when available.
            var index := 0
            if entry["id"] == "false_jackpot":
                index = 1
            elif entry["id"] == "dark_marquee":
                index = 2
            if slots.size() <= index:
                return result
            var slot := slots[index]
            var parts: Array[String] = []
            match str(entry["id"]):
                "blank_reels": parts = ["ReelGlyph_0", "ReelGlyph_1", "ReelGlyph_2"]
                "false_jackpot": parts = ["MachineTitle"]
                "dark_marquee": parts = ["TopGlow", "MachineTitle"]
            for part in parts:
                var piece := slot.get_node_or_null(part) as Node3D
                if piece == null or not piece.visible:
                    result.clear()
                    return result
                if entry["id"] == "false_jackpot" and not piece is Label3D:
                    result.clear()
                    return result
                result.append(piece)
        "watchful_camera":
            for child in base.get_children():
                if child is Node3D and child.get_meta("placement_group", "") == "WestSecurityCamera":
                    result.append(child as Node3D)
                    break
        "floating_hand", "missing_hand":
            for child in base.get_children():
                if child is Node3D and child.visible and child.has_meta("source_card_index"):
                    result.append(child as Node3D)
                    if result.size() == 4:
                        break
            if result.size() != 4:
                result.clear()
        "burgundy_felt", "blue_runner":
            if base is MeshInstance3D and base.mesh != null and base.mesh.get_surface_count() == 1:
                if base.get_active_material(0) is StandardMaterial3D:
                    result.append(base)
        "empty_reserve":
            for bottle in base.find_children("Signature_*", "Node3D", true, false):
                var liquid := bottle.get_node_or_null("InnerLiquidVolume") as MeshInstance3D
                if liquid != null and liquid.visible:
                    result.append(liquid)
                    if result.size() == 6:
                        break
            if result.size() != 6:
                result.clear()
        "bare_monstera":
            for leaf in base.find_children("Leaves", "Node3D", true, false):
                if leaf is Node3D and leaf.visible:
                    result.append(leaf as Node3D)
    return result


func can_apply(room: Node3D, entry: Dictionary) -> bool:
    return not targets(room, entry).is_empty()


func snapshot(nodes: Array[Node3D], id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for node in nodes:
        var state := {"node": node}
        match id:
            "false_jackpot":
                state["text"] = (node as Label3D).text
                state["modulate"] = (node as Label3D).modulate
            "watchful_camera", "floating_hand":
                state["transform"] = node.transform
            "burgundy_felt", "blue_runner":
                state["material"] = (node as MeshInstance3D).material_override
            _:
                state["visible"] = node.visible
        result.append(state)
    return result


func apply(room: Node3D, entry: Dictionary) -> bool:
    clear()
    var nodes := targets(room, entry)
    if nodes.is_empty():
        return false
    var id := str(entry["id"])
    changed = snapshot(nodes, id)
    for node in nodes:
        match id:
            "false_jackpot":
                var label := node as Label3D
                label.text = "JACKPOT"
                label.modulate = Color("#ffcf68")
            "watchful_camera":
                node.rotate_object_local(Vector3.UP, deg_to_rad(145.0))
            "floating_hand":
                # Convert the room's vertical offset into the table's local
                # coordinates, so scaled/rotated table roots remain valid.
                var parent := node.get_parent() as Node3D
                node.position += parent.global_basis.inverse() * Vector3(0.0, 0.18, 0.0)
            "burgundy_felt", "blue_runner":
                var mesh := node as MeshInstance3D
                var material := mesh.get_active_material(0).duplicate() as StandardMaterial3D
                # Use private material only; no changes to shared mesh data.
                material.albedo_texture = null
                material.albedo_color = Color("#591d32") if id == "burgundy_felt" else Color("#203a65")
                mesh.material_override = material
            _:
                node.visible = false
    return true


func clear() -> void:
    for state in changed:
        var node := state["node"] as Node3D
        if not is_instance_valid(node):
            continue
        if state.has("text"):
            (node as Label3D).text = state["text"]
            (node as Label3D).modulate = state["modulate"]
        elif state.has("transform"):
            node.transform = state["transform"]
        elif state.has("material"):
            (node as MeshInstance3D).material_override = state["material"]
        elif state.has("visible"):
            node.visible = state["visible"]
    changed.clear()
