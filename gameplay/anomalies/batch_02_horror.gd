extends RefCounted
## Pack 02: quiet, reversible environmental horror. No audio, camera
## overrides, collision changes, or player-dependent sudden reveals.
var saved: Array[Dictionary] = []
var spawned: Array[Node3D] = []
var motion: Tween

const SHADOW_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="256" height="640" viewBox="0 0 256 640"><path fill="#09080b" fill-opacity=".38" d="M111 622L80 420 43 302 21 184 41 155 65 188 93 289 94 174Q70 142 80 93Q85 53 128 49Q170 54 177 94Q185 142 161 175L163 289 191 188 216 155 235 184 213 302 176 420 145 622Z"/><path fill="#080709" fill-opacity=".78" d="M115 622L91 415 53 297 35 184 44 176 59 199 107 341 108 166Q88 138 91 96Q94 66 128 64Q160 67 166 96Q169 138 148 166L149 341 197 199 212 176 221 184 203 297 165 415 141 622 128 441Z"/></svg>"""
const FOOT_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="256" viewBox="0 0 128 256"><g fill="#110a0a" fill-opacity=".85"><path d="M57 237Q30 225 37 192Q44 168 42 148Q35 128 31 104Q24 71 48 58Q76 45 94 75Q108 102 91 132Q74 154 80 181Q96 222 69 237Z"/><ellipse cx="83" cy="35" rx="16" ry="23"/><ellipse cx="57" cy="29" rx="12" ry="17"/><ellipse cx="38" cy="38" rx="10" ry="14"/><ellipse cx="23" cy="50" rx="8" ry="11"/><ellipse cx="15" cy="66" rx="6" ry="9"/></g></svg>"""
const EYES_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="512" height="384" viewBox="0 0 512 384"><rect width="512" height="384" fill="#08080b"/><g fill="#d5d0be"><path d="M105 188Q150 155 193 185Q150 208 105 188Z"/><path d="M319 185Q362 155 407 188Q362 208 319 185Z"/></g><g fill="#171418"><ellipse cx="150" cy="184" rx="9" ry="12"/><ellipse cx="362" cy="184" rx="9" ry="12"/></g></svg>"""


func _group(root_node: Node3D, tag: String) -> Array[Node3D]:
    var result: Array[Node3D] = []
    for child in root_node.get_children():
        if child is Node3D and child.visible and child.get_meta("placement_group", "") == tag:
            result.append(child as Node3D)
    return result


func _meshes(node: Node3D) -> Array[MeshInstance3D]:
    var result: Array[MeshInstance3D] = []
    if node is MeshInstance3D and node.mesh != null:
        result.append(node as MeshInstance3D)
    for part in node.find_children("*", "MeshInstance3D", true, false):
        if part.mesh != null and part.visible:
            result.append(part as MeshInstance3D)
    return result


func targets(room: Node3D, entry: Dictionary) -> Array[Node3D]:
    var result: Array[Node3D] = []
    if not is_instance_valid(room):
        return result
    var base := room.get_node_or_null(str(entry.get("target_path", ""))) as Node3D
    if base == null:
        return result
    match str(entry["id"]):
        "synchronized_busts":
            result = _group(base, "MarbleBust")
            if result.size() != 2:
                result.clear()
        "inverted_cat":
            result = _group(base, "ConcreteCatDisplay")
        "lightless_horse":
            for statue in _group(base, "HorseStatueDisplay"):
                for piece in _meshes(statue):
                    result.append(piece)
        "watching_canvases":
            for frame in _group(base, "FramedPainting"):
                for piece in _meshes(frame):
                    if piece.name.to_lower().contains("canvas"):
                        result.append(piece)
            if result.size() != 3:
                result.clear()
        "stay_here":
            for path in ["Architecture/Sign_CASINO_ANOMALY", "CornerBar/Sign_MIDNIGHT_BAR", "Decor/Sign_TABLE_GAMES"]:
                var sign := room.get_node_or_null(path) as Label3D
                if sign == null or not sign.visible:
                    result.clear()
                    return result
                result.append(sign)
        "last_kings":
            for board in _group(base, "LoungeChessSet"):
                for piece in _meshes(board):
                    var piece_name := str(piece.name).to_lower()
                    if piece_name.begins_with("piece_") and not piece_name.contains("king"):
                        result.append(piece)
            if result.size() < 24:
                result.clear()
        "ownerless_shadow", "empty_footsteps":
            if base is MeshInstance3D and base.mesh != null and base.visible:
                result.append(base)
        "crimson_hall":
            for fixture in base.get_children():
                if fixture is Light3D and fixture.visible and str(fixture.name).begins_with("WarmCasinoLamp_"):
                    result.append(fixture as Light3D)
            if result.size() < 4:
                result.clear()
        "silent_countdown":
            for cabinet in base.get_children():
                if cabinet is Node3D and cabinet.visible and cabinet.has_meta("slot_cabinet_revision"):
                    var title := cabinet.get_node_or_null("MachineTitle") as Label3D
                    if title != null and title.visible:
                        result.append(title)
            if result.size() < 5:
                result.clear()
    return result


func can_apply(room: Node3D, entry: Dictionary) -> bool:
    return not targets(room, entry).is_empty()


func snapshot(nodes: Array[Node3D], id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for node in nodes:
        var state := {"node": node}
        match id:
            "synchronized_busts", "inverted_cat":
                state["transform"] = node.transform
            "lightless_horse", "watching_canvases":
                state["material"] = (node as MeshInstance3D).material_override
            "stay_here", "silent_countdown":
                state["text"] = (node as Label3D).text
                state["modulate"] = (node as Label3D).modulate
            "last_kings":
                state["visible"] = node.visible
            "ownerless_shadow", "empty_footsteps":
                state["mark"] = node.has_node("AnomalyHorrorMark")
            "crimson_hall":
                state["color"] = (node as Light3D).light_color
                state["energy"] = (node as Light3D).light_energy
        result.append(state)
    return result


func _svg_texture(source: String) -> ImageTexture:
    var image := Image.new()
    if image.load_svg_from_buffer(source.to_utf8_buffer()) != OK:
        return null
    return ImageTexture.create_from_image(image)


func _surface_material(color: Color, texture: Texture2D = null, transparent: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = color
    mat.albedo_texture = texture
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    if transparent:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.render_priority = 1
    return mat


func _floor_mark(parent: Node3D, at: Vector3, dimensions: Vector2, mat: StandardMaterial3D, yaw: float, flip: bool = false) -> void:
    var mark := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = dimensions
    plane.flip_faces = false
    mark.mesh = plane
    mark.material_override = mat
    mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mark)
    mark.position = at
    mark.rotation.y = yaw
    if flip:
        mark.scale.x = -1.0


func _marks(floor_mesh: MeshInstance3D, id: String, tex: Texture2D) -> void:
    # Mesh bounds are in authored local coordinates; use those rather than
    # hard-coded global positions so a reversed streamed hall still works.
    var bounds := floor_mesh.get_aabb()
    var middle := bounds.get_center()
    var height := bounds.end.y + 0.009
    var mark_root := Node3D.new()
    mark_root.name = "AnomalyHorrorMark"
    floor_mesh.add_child(mark_root)
    spawned.append(mark_root)
    var mat := _surface_material(Color.WHITE, tex, true)
    if id == "ownerless_shadow":
        _floor_mark(mark_root, Vector3(middle.x, height, middle.z), Vector2(1.35, 3.25), mat, 0.0)
    else:
        # Six alternating barefoot impressions in a 3m trail on the west
        # carpet; no collisions or actual moving character.
        for i in range(6):
            var side := -0.14 if i % 2 == 0 else 0.14
            _floor_mark(mark_root, Vector3(middle.x + (float(i) - 2.5) * 0.52, height, middle.z + side), Vector2(0.16, 0.34), mat, PI * 0.5, i % 2 == 1)


func _reduced(room: Node3D) -> bool:
    var settings := room.get_node_or_null("/root/GameSettings")
    return settings != null and bool(settings.call("get_option", "reduced_motion"))


func apply(room: Node3D, entry: Dictionary) -> bool:
    clear()
    var nodes := targets(room, entry)
    if nodes.is_empty():
        return false
    var id := str(entry["id"])
    var tex: Texture2D
    match id:
        "watching_canvases": tex = _svg_texture(EYES_SVG)
        "ownerless_shadow": tex = _svg_texture(SHADOW_SVG)
        "empty_footsteps": tex = _svg_texture(FOOT_SVG)
    if id in ["watching_canvases", "ownerless_shadow", "empty_footsteps"] and tex == null:
        return false
    saved = snapshot(nodes, id)
    for node in nodes:
        match id:
            "synchronized_busts":
                node.rotate_object_local(Vector3.UP, deg_to_rad(65.0))
            "inverted_cat":
                # The wrapper is anchored to the bottom of the 0.49m
                # statue. Raise it before inversion to clear its pedestal.
                node.position.y += 0.68
                node.rotate_object_local(Vector3.FORWARD, PI)
            "lightless_horse":
                (node as MeshInstance3D).material_override = _surface_material(Color("#09090b"))
            "watching_canvases":
                (node as MeshInstance3D).material_override = _surface_material(Color.WHITE, tex)
            "stay_here":
                (node as Label3D).text = "STAY HERE"
                (node as Label3D).modulate = Color("#e1c28e")
            "last_kings":
                node.visible = false
            "ownerless_shadow", "empty_footsteps":
                _marks(node as MeshInstance3D, id, tex)
            "crimson_hall":
                (node as Light3D).light_color = Color("#ff263e")
                (node as Light3D).light_energy *= 3.0
            "silent_countdown":
                (node as Label3D).text = "01:00"
                (node as Label3D).modulate = Color("#edc6a1")
    if id == "synchronized_busts":
        _turn_busts(room, nodes)
    elif id == "silent_countdown":
        _countdown(room, nodes)
    return true


func _turn_busts(room: Node3D, nodes: Array[Node3D]) -> void:
    var origins: Array[Transform3D] = []
    for state in saved:
        origins.append(state["transform"])
    motion = room.create_tween().set_loops()
    motion.tween_method(func(phase: float) -> void:
        if room.has_meta("_streaming_standby"):
            return
        var offset := 65.0 if _reduced(room) else 65.0 + 45.0 * (0.5 - 0.5 * cos(phase * TAU))
        for index in range(nodes.size()):
            if is_instance_valid(nodes[index]):
                nodes[index].transform = origins[index]
                nodes[index].rotate_object_local(Vector3.UP, deg_to_rad(offset))
    , 0.0, 1.0, 12.0)


func _countdown(room: Node3D, nodes: Array[Node3D]) -> void:
    # Start counting only once the hall is active. Zero has no consequence.
    # The quiet clock is just a visual clue, not a gameplay time limit.
    var elapsed := [0.0]
    motion = room.create_tween().set_loops()
    motion.tween_callback(func() -> void:
        if room.has_meta("_streaming_standby") or _reduced(room):
            return
        elapsed[0] = minf(60.0, float(elapsed[0]) + 1.0)
        var seconds := 60 - int(elapsed[0])
        var value := "%02d:%02d" % [floori(float(seconds) / 60.0), seconds % 60]
        for title in nodes:
            if is_instance_valid(title):
                (title as Label3D).text = value
    ).set_delay(1.0)


func clear() -> void:
    if motion != null and motion.is_valid():
        motion.kill()
    motion = null
    for mark in spawned:
        if is_instance_valid(mark):
            mark.free()
    spawned.clear()
    for state in saved:
        var node := state["node"] as Node3D
        if not is_instance_valid(node):
            continue
        if state.has("transform"):
            node.transform = state["transform"]
        elif state.has("material"):
            (node as MeshInstance3D).material_override = state["material"]
        elif state.has("text"):
            (node as Label3D).text = state["text"]
            (node as Label3D).modulate = state["modulate"]
        elif state.has("visible"):
            node.visible = state["visible"]
        elif state.has("color"):
            (node as Light3D).light_color = state["color"]
            (node as Light3D).light_energy = state["energy"]
    saved.clear()
