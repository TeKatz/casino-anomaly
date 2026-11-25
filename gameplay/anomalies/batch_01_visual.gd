extends RefCounted
## Batch 01 visual review. Every mutation is room-local and reversible.
var changed: Array[Dictionary] = []
var markers: Array[Node3D] = []
var motion: Tween


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
            var indices: Array[int] = []
            var parts: Array[String] = []
            match str(entry["id"]):
                "blank_reels":
                    indices = [0]
                    parts = ["ReelGlyph_0", "ReelGlyph_1", "ReelGlyph_2"]
                "false_jackpot":
                    indices = [1]
                    parts = ["MachineTitle", "TopGlow"]
                "dark_marquee":
                    indices = [2, 3, 4]
                    parts = ["TopGlow", "MachineTitle"]
            for index in indices:
                if slots.size() <= index:
                    result.clear()
                    return result
                for part in parts:
                    var piece := slots[index].get_node_or_null(part) as Node3D
                    if piece == null or not piece.visible:
                        result.clear()
                        return result
                    if entry["id"] == "false_jackpot":
                        if part == "MachineTitle" and not piece is Label3D:
                            result.clear()
                            return result
                        if part == "TopGlow" and not _is_surface(piece):
                            result.clear()
                            return result
                    result.append(piece)
        "watchful_camera":
            for child in base.get_children():
                if child is Node3D and child.get_meta("placement_group", "") in ["WestSecurityCamera", "EntranceSecurityCamera"]:
                    var model := child.get_node_or_null("EditableImportedModel") as Node3D
                    if model == null:
                        model = child as Node3D
                    for candidate in model.find_children("*", "MeshInstance3D", true, false):
                        if candidate.name.begins_with("security_camera_01"):
                            result.append(candidate as Node3D)
                            break
            if result.size() != 2:
                result.clear()
        "floating_hand", "missing_hand":
            for child in base.get_children():
                if child is Node3D and child.visible and child.has_meta("source_card_index"):
                    result.append(child as Node3D)
                    if entry["id"] == "floating_hand" and result.size() == 4:
                        break
            var expected := 4 if entry["id"] == "floating_hand" else 8
            if result.size() != expected:
                result.clear()
        "burgundy_felt":
            if _is_surface(base):
                result.append(base)
        "blue_runner":
            for name in ["ApproachRunner", "TurnRunner", "WestRunner"]:
                var patch := base.get_node_or_null(name) as Node3D
                if not _is_surface(patch):
                    result.clear()
                    return result
                result.append(patch)
        "empty_reserve":
            for bottle in base.find_children("Signature_*", "Node3D", true, false):
                var liquid := bottle.get_node_or_null("InnerLiquidVolume") as MeshInstance3D
                if liquid != null and liquid.visible:
                    result.append(liquid)
        "bare_monstera":
            for name in ["Plant_03", "Plant_04", "Plant_05"]:
                var model := base.get_node_or_null(name + "/GioraMonsteraOriginal") as Node3D
                if model == null:
                    result.clear()
                    return result
                var leaves := model.find_children("Leaves", "Node3D", true, false)
                if leaves.is_empty():
                    result.clear()
                    return result
                for leaf in leaves:
                    if leaf is Node3D and leaf.visible:
                        result.append(leaf as Node3D)
    return result


func _is_surface(node: Node3D) -> bool:
    return node is MeshInstance3D and node.visible and node.mesh != null and node.mesh.get_surface_count() > 0 and node.get_active_material(0) is StandardMaterial3D


func can_apply(room: Node3D, entry: Dictionary) -> bool:
    return not targets(room, entry).is_empty()


func snapshot(nodes: Array[Node3D], id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for node in nodes:
        var state := {"node": node}
        match id:
            "false_jackpot":
                if node is Label3D:
                    state["text"] = node.text
                    state["modulate"] = node.modulate
                else:
                    state["material"] = (node as MeshInstance3D).material_override
            "watchful_camera":
                state["marker"] = node.has_node("AnomalyRecordingLED")
            "floating_hand":
                state["transform"] = node.transform
            "burgundy_felt", "blue_runner":
                state["material"] = (node as MeshInstance3D).material_override
            _:
                state["visible"] = node.visible
        result.append(state)
    return result


func _reduced(room: Node3D, key: String) -> bool:
    var settings := room.get_node_or_null("/root/GameSettings")
    return settings != null and bool(settings.call("get_option", key))


func _recording_led(camera_mesh: Node3D) -> void:
    # The source glTF lens faces +Z; the lens plane is at z=0.19876,
    # and its hood ends at z=0.25019. Fit the red indicator to that face.
    var marker := MeshInstance3D.new()
    marker.name = "AnomalyRecordingLED"
    var sphere := SphereMesh.new()
    sphere.radius = 0.014
    sphere.height = 0.028
    sphere.radial_segments = 12
    sphere.rings = 6
    marker.mesh = sphere
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color("#ff3030")
    material.emission_enabled = true
    material.emission = Color("#ff2020")
    material.emission_energy_multiplier = 3.0
    marker.material_override = material
    marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    camera_mesh.add_child(marker)
    marker.position = Vector3(0.032, 0.205, 0.251)
    var glow := OmniLight3D.new()
    glow.light_color = Color("#ff2020")
    glow.light_energy = 0.22
    glow.omni_range = 0.24
    glow.shadow_enabled = false
    glow.light_volumetric_fog_energy = 0.0
    marker.add_child(glow)
    markers.append(marker)


func _recolor(mesh: MeshInstance3D, color: Color, emission_strength: float) -> void:
    var material := mesh.get_active_material(0).duplicate() as StandardMaterial3D
    # Remove the old colored fabric texture AND inherited red emission.
    # A restrained matching emission keeps the new color readable under
    # warm baked GI, while the normal map and roughness preserve texture.
    material.albedo_texture = null
    material.albedo_color = color
    material.emission_enabled = true
    material.emission_texture = null
    material.emission = color
    material.emission_energy_multiplier = emission_strength
    mesh.material_override = material


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
                if node is Label3D:
                    node.text = "JACKPOT"
                    node.modulate = Color("#ffdf70")
                else:
                    _recolor(node as MeshInstance3D, Color("#ffad28"), 4.0)
            "watchful_camera":
                _recording_led(node)
            "floating_hand":
                var parent := node.get_parent() as Node3D
                node.position += parent.global_basis.inverse() * Vector3(0.0, 0.10, 0.0)
            "burgundy_felt":
                _recolor(node as MeshInstance3D, Color("#b13c56"), 0.35)
            "blue_runner":
                _recolor(node as MeshInstance3D, Color("#2868ce"), 0.45)
            _:
                node.visible = false
    if id == "false_jackpot":
        _animate_jackpot(room, nodes)
    elif id == "floating_hand":
        _animate_cards(room, nodes)
    return true


func _animate_jackpot(room: Node3D, nodes: Array[Node3D]) -> void:
    var label := nodes[0] as Label3D
    var glow := (nodes[1] as MeshInstance3D).material_override as StandardMaterial3D
    # Slow, smooth pulsing (<1 Hz), not a high-frequency strobe.
    motion = room.create_tween().set_loops()
    motion.tween_method(func(phase: float) -> void:
        if not is_instance_valid(label):
            return
        var steady := _reduced(room, "reduce_light_motion") or _reduced(room, "soft_light_transitions") or _reduced(room, "reduced_motion")
        var pulse := 1.0 if steady else (0.5 - 0.5 * cos(phase * TAU))
        glow.emission_energy_multiplier = lerpf(0.8, 5.5, pulse)
        label.modulate = Color("#e88c32").lerp(Color("#fff1aa"), pulse)
    , 0.0, 1.0, 1.6)


func _animate_cards(room: Node3D, nodes: Array[Node3D]) -> void:
    var rest: Array[Vector3] = []
    for node in nodes:
        rest.append(node.position)
    motion = room.create_tween().set_loops()
    motion.tween_method(func(phase: float) -> void:
        var steady := _reduced(room, "reduced_motion")
        for i in range(nodes.size()):
            var card := nodes[i]
            if not is_instance_valid(card):
                continue
            var parent := card.get_parent() as Node3D
            var bob := 0.0 if steady else sin(phase * TAU + float(i) * 1.15) * 0.025
            card.position = rest[i] + parent.global_basis.inverse() * Vector3(0.0, bob, 0.0)
    , 0.0, 1.0, 3.2)


func clear() -> void:
    if motion != null and motion.is_valid():
        motion.kill()
    motion = null
    for marker in markers:
        if is_instance_valid(marker):
            marker.free()
    markers.clear()
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
