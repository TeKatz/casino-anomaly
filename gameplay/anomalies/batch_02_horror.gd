extends RefCounted
## Pack 02: quiet, reversible environmental horror. No camera overrides,
## sudden reveals. Vanished guardians also removes the hidden pedestal collision.
## Countdown has one quiet local tick.
var saved: Array[Dictionary] = []
var spawned: Array[Node3D] = []
var motion: Tween
const FOOT_COUNT := 28
const FOOT_SPACING := 0.55
const ShadowProjection = preload("res://gameplay/anomalies/shadow_projection.gd")
# SVG toes point along local -Z. With -90 degrees around Y they point +X,
# matching the increasing-X order of the footprints.
const FOOT_YAW := -PI * 0.5

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
            result.append_array(_group(base, "HorseStatueDisplay"))
            # The placement layer authors the cat pedestal first and the
            # horse pedestal second. Do not hide the cat's pedestal.
            var horse_plinth := base.get_node_or_null("DecorativeStatuePlinth_02") as Node3D
            if result.size() != 2 or horse_plinth == null or not horse_plinth.visible:
                result.clear()
            else:
                result.append(horse_plinth)
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
                if entry["id"] != "ownerless_shadow" or ShadowProjection.available():
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


func _collision_state(node: Node3D) -> Array[Dictionary]:
    var bodies: Array[CollisionObject3D] = []
    if node is CollisionObject3D:
        bodies.append(node as CollisionObject3D)
    for child in node.find_children("*", "CollisionObject3D", true, false):
        bodies.append(child as CollisionObject3D)
    var result: Array[Dictionary] = []
    for body in bodies:
        result.append({"body": body, "layer": body.collision_layer, "mask": body.collision_mask})
    return result


func snapshot(nodes: Array[Node3D], id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for node in nodes:
        var state := {"node": node}
        match id:
            "synchronized_busts":
                state["transform"] = node.transform
            "inverted_cat":
                state["visible"] = node.visible
                state["collisions"] = _collision_state(node)
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


func _floor_mark(parent: Node3D, at: Vector3, dimensions: Vector2, mat: StandardMaterial3D, yaw: float, flip: bool = false) -> MeshInstance3D:
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
    return mark


func _marks(floor_mesh: MeshInstance3D, tex: Texture2D) -> void:
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
    # Each impression gets an independent alpha; the trail stays in
    # place as the invisible walker advances down the hall.
    var spacing := minf(FOOT_SPACING, (bounds.size.x - 1.0) / float(FOOT_COUNT - 1))
    for i in range(FOOT_COUNT):
        var side := -0.14 if i % 2 == 0 else 0.14
        var foot_mat := mat.duplicate() as StandardMaterial3D
        var foot := _floor_mark(mark_root, Vector3(middle.x + (float(i) - float(FOOT_COUNT - 1) * 0.5) * spacing, height, middle.z + side), Vector2(0.16, 0.31), foot_mat, FOOT_YAW, i % 2 == 1)
        foot.name = "Foot_%02d" % i
        foot_mat.albedo_color.a = 0.85 if i < 4 else 0.0
    _animate_footprints(floor_mesh, mark_root, spacing)


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
        "empty_footsteps": tex = _svg_texture(FOOT_SVG)
    if id in ["watching_canvases", "empty_footsteps"] and tex == null:
        return false
    saved = snapshot(nodes, id)
    for node in nodes:
        match id:
            "synchronized_busts":
                _rotate_bust(node, node.transform, _bust_pivot(node), 65.0)
            "inverted_cat":
                node.visible = false
                for collision in _collision_state(node):
                    var body := collision["body"] as CollisionObject3D
                    body.collision_layer = 0
                    body.collision_mask = 0
            "lightless_horse":
                (node as MeshInstance3D).material_override = _surface_material(Color("#09090b"))
            "watching_canvases":
                (node as MeshInstance3D).material_override = _surface_material(Color.WHITE, tex)
            "stay_here":
                (node as Label3D).text = "STAY HERE"
                (node as Label3D).modulate = Color("#ff6262")
            "last_kings":
                node.visible = false
            "ownerless_shadow":
                var shadow_root := ShadowProjection.install(node as MeshInstance3D)
                if shadow_root == null:
                    clear()
                    return false
                spawned.append(shadow_root)
            "empty_footsteps":
                _marks(node as MeshInstance3D, tex)
            "crimson_hall":
                (node as Light3D).light_color = Color("#ff263e")
                (node as Light3D).light_energy *= 3.0
            "silent_countdown":
                (node as Label3D).text = "01:00"
                (node as Label3D).modulate = Color("#edc6a1")
    if id == "synchronized_busts":
        _turn_busts(room, nodes)
    elif id == "watching_canvases":
        _blink_eyes(room, nodes)
    elif id == "stay_here":
        _pulse_signs(room, nodes)
    elif id == "silent_countdown":
        _countdown(room, nodes)
    return true


func _bust_pivot(bust: Node3D) -> Vector3:
    var inverse := bust.global_transform.affine_inverse()
    var bounds := AABB()
    var first := true
    for mesh in _meshes(bust):
        var local_bounds: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
        bounds = local_bounds if first else bounds.merge(local_bounds)
        first = false
    if first:
        return Vector3.ZERO
    return Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)


func _rotate_bust(bust: Node3D, original: Transform3D, pivot: Vector3, degrees: float) -> void:
    # Rotate around the visual base in parent space, not the imported
    # offset origin. This also preserves the author's scale and height.
    var new_basis := original.basis * Basis(Vector3.UP, deg_to_rad(degrees))
    bust.transform = Transform3D(new_basis, original * pivot - new_basis * pivot)


func _turn_busts(room: Node3D, nodes: Array[Node3D]) -> void:
    var origins: Array[Transform3D] = []
    var pivots: Array[Vector3] = []
    for state in saved:
        origins.append(state["transform"])
        pivots.append(_bust_pivot(state["node"] as Node3D))
    motion = room.create_tween().set_loops()
    motion.tween_method(func(phase: float) -> void:
        if room.has_meta("_streaming_standby"):
            return
        var offset := 65.0 if _reduced(room) else 65.0 + 45.0 * (0.5 - 0.5 * cos(phase * TAU))
        for index in range(nodes.size()):
            if is_instance_valid(nodes[index]):
                _rotate_bust(nodes[index], origins[index], pivots[index], offset)
    , 0.0, 1.0, 12.0)


func _blink_eyes(room: Node3D, nodes: Array[Node3D]) -> void:
    # Keep the approved open-eye artwork; pre-render six closing stages.
    var frames: Array[Texture2D] = []
    for frame in range(7):
        var openness := 1.0 - float(frame) / 6.0
        var replacement := "<g transform=\"translate(0,184) scale(1,%f) translate(0,-184)\">" % maxf(openness, 0.025)
        var picture := EYES_SVG.replace('<g fill="#d5d0be">', replacement + '<g fill="#d5d0be">').replace("</svg>", "</g></svg>")
        frames.append(_svg_texture(picture))
    var materials: Array[StandardMaterial3D] = []
    for canvas in nodes:
        materials.append((canvas as MeshInstance3D).material_override as StandardMaterial3D)
    motion = room.create_tween().set_loops()
    motion.tween_method(func(phase: float) -> void:
        if room.has_meta("_streaming_standby"):
            return
        for i in range(materials.size()):
            var local := fposmod(phase + float(i) * 1.27, 5.5)
            var closure := 0.0
            if local > 4.95:
                closure = sin((local - 4.95) / 0.55 * PI)
            var index := 0 if _reduced(room) else clampi(roundi(closure * 6.0), 0, 6)
            if frames[index] != null:
                materials[i].albedo_texture = frames[index]
    , 0.0, 5.5, 5.5)


func _pulse_signs(room: Node3D, nodes: Array[Node3D]) -> void:
    motion = room.create_tween().set_loops()
    motion.tween_method(func(phase: float) -> void:
        if room.has_meta("_streaming_standby"):
            return
        var settings := room.get_node_or_null("/root/GameSettings")
        var steady := _reduced(room) or (settings != null and (bool(settings.call("get_option", "reduce_light_motion")) or bool(settings.call("get_option", "soft_light_transitions"))))
        var pulse := 1.0 if steady else 0.5 - 0.5 * cos(phase * TAU)
        for sign in nodes:
            if is_instance_valid(sign):
                (sign as Label3D).modulate = Color("#b83038").lerp(Color("#ff8585"), pulse)
    , 0.0, 1.0, 3.6)


func _animate_footprints(floor_mesh: Node3D, mark_root: Node3D, spacing: float) -> void:
    # The room root owns the actual player after the streaming handoff.
    var hall := floor_mesh.get_parent().get_parent() as Node3D
    if hall == null:
        return
    var clock := [0.0, spacing * 3.0]
    var marks := mark_root.get_children()
    var cycle := float(FOOT_COUNT) * spacing + 3.0
    motion = hall.create_tween().set_loops()
    motion.tween_method(func(phase: float) -> void:
        var dt := phase - float(clock[0])
        if dt < 0.0:
            dt += 1.0
        clock[0] = phase
        if hall.has_meta("_streaming_standby"):
            return
        var player_body := hall.get_node_or_null("Player") as CharacterBody3D
        # Use measured horizontal velocity, with a slow idle pace so the
        # clue remains observable even when the player stops to watch.
        var pace := 1.0
        if player_body != null:
            pace = clampf(Vector2(player_body.velocity.x, player_body.velocity.z).length(), 0.9, 6.3)
        clock[1] = fposmod(float(clock[1]) + pace * dt, cycle)
        for index in range(marks.size()):
            if not is_instance_valid(marks[index]):
                continue
            var mat := (marks[index] as MeshInstance3D).material_override as StandardMaterial3D
            var age := float(clock[1]) - float(index) * spacing
            var alpha := smoothstep(0.0, 0.25, age) * (1.0 - smoothstep(1.4, 2.8, age))
            mat.albedo_color.a = 0.85 if _reduced(hall) else alpha * 0.85
    , 0.0, 1.0, 1.0)


func _quiet_tick() -> AudioStreamWAV:
    # Short damped mechanical click, band-limited and with a soft envelope.
    # No asset imports, no looping audio, no loud onset.
    var rate := 22050
    var frames := 2205
    var bytes := PackedByteArray()
    bytes.resize(frames * 2)
    for i in range(frames):
        var t := float(i) / float(rate)
        # Slightly longer, clearer mechanical tick: audible body plus
        # a damped click, with no clipping or aggressive high frequencies.
        var envelope := minf(1.0, t / 0.002) * exp(-t * 39.0) * maxf(0.0, 1.0 - t / 0.10)
        var sample := (sin(TAU * 760.0 * t) * 0.46 + sin(TAU * 1420.0 * t) * 0.34 + sin(TAU * 2350.0 * t) * 0.20) * envelope * 0.92
        bytes.encode_s16(i * 2, roundi(sample * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.data = bytes
    return stream


func _countdown(room: Node3D, nodes: Array[Node3D]) -> void:
    # Start counting only once the hall is active. Zero has no consequence.
    # The quiet clock is just a visual clue, not a gameplay time limit.
    var elapsed := [0.0]
    var tick := AudioStreamPlayer3D.new()
    tick.name = "AnomalyCountdownTick"
    tick.stream = _quiet_tick()
    tick.bus = "HORROR"
    tick.volume_db = -9.0
    tick.unit_size = 5.0
    tick.max_distance = 22.0
    tick.set_meta("tick_count", 0)
    tick.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
    nodes[floori(float(nodes.size()) * 0.5)].add_child(tick)
    spawned.append(tick)
    motion = room.create_tween().set_loops()
    motion.tween_callback(func() -> void:
        if room.has_meta("_streaming_standby") or float(elapsed[0]) >= 60.0:
            return
        elapsed[0] = minf(60.0, float(elapsed[0]) + 1.0)
        if is_instance_valid(tick):
            tick.play()
            tick.set_meta("tick_count", int(tick.get_meta("tick_count", 0)) + 1)
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
            for collision in state.get("collisions", []):
                var body := collision["body"] as CollisionObject3D
                if is_instance_valid(body):
                    body.collision_layer = int(collision["layer"])
                    body.collision_mask = int(collision["mask"])
        elif state.has("color"):
            (node as Light3D).light_color = state["color"]
            (node as Light3D).light_energy = state["energy"]
    saved.clear()
