extends RefCounted
## Pack 03: room-local animated anomalies. Original resources and gameplay
## collisions remain untouched. All generated nodes and tweens are owned
## by this effect and are removed on clear/streaming handoff.
const Guest = preload("res://gameplay/anomalies/seated_guest.gd")
const Mirror = preload("res://gameplay/anomalies/wrong_reflection.gd")
const RisingDrops = preload("res://gameplay/anomalies/rising_drops.gd")
const ListeningView = preload("res://gameplay/anomalies/listening_view.gd")
var saved: Array[Dictionary] = []
var roots: Array[Node3D] = []
var motion: Tween
var audio_original: Dictionary = {}
var glow_original: Array[Dictionary] = []

const BREATH_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D fabric : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bumps : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_bumps = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 uv_scale = vec3(1.0);
uniform float amplitude = 0.45;
uniform float rough = 0.9;
void vertex() {
    // Only the inner (-X) wall face. Local patch tapers smoothly into
    // the untouched wall and stops before the ceiling/collision boundary.
    float weight = exp(-pow(VERTEX.z / 6.2, 2.0) - pow((VERTEX.y - 0.85) / 1.6, 2.0));
    if (NORMAL.x < -0.5) {
        VERTEX.x -= amplitude * weight;
        NORMAL = normalize(vec3(-1.0, -2.0 * amplitude * weight * (VERTEX.y - 0.85) / 2.56, -2.0 * amplitude * weight * VERTEX.z / 38.44));
    }
}
void fragment() {
    vec2 uv = UV * uv_scale.xy;
    ALBEDO = texture(fabric, uv).rgb * tint.rgb;
    ROUGHNESS = rough;
    if (has_bumps) { NORMAL_MAP = texture(bumps, uv).rgb; }
}
"""
const BLOOM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float growth = 0.5;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise2(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float r = length(p);
    float a = atan(p.y,p.x);
    float n = noise2(p*9.0)*0.26 + noise2(p*22.0)*0.09;
    float tendrils = pow(max(0.0, sin(a*19.0 + noise2(p*7.0)*9.0)), 4.0);
    float edge = growth*(0.70 + n + tendrils*0.42);
    float body = 1.0-smoothstep(edge-0.13,edge+0.025,r);
    float vein = tendrils*(1.0-smoothstep(edge,edge+0.22,r))*smoothstep(0.10,0.35,r);
    ALBEDO = vec3(0.014,0.009,0.013) + noise2(p*45.0)*0.017;
    ALPHA = clamp((body*1.12 + vein*0.62)*(0.80+noise2(p*38.0)*0.20),0.0,0.97) * (1.0-smoothstep(0.91,1.0,r));
}
"""


func _meshes(node: Node3D) -> Array[MeshInstance3D]:
    var result: Array[MeshInstance3D] = []
    if node is MeshInstance3D and node.mesh != null:
        result.append(node as MeshInstance3D)
    for item in node.find_children("*", "MeshInstance3D", true, false):
        if item.mesh != null and item.visible:
            result.append(item as MeshInstance3D)
    return result


func _bounds(node: Node3D) -> AABB:
    var box := AABB()
    var first := true
    for mesh in _meshes(node):
        var local: AABB = (node.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
        box = local if first else box.merge(local)
        first = false
    return box


func targets(room: Node3D, entry: Dictionary) -> Array[Node3D]:
    var result: Array[Node3D] = []
    if not is_instance_valid(room):
        return result
    var base := room.get_node_or_null(str(entry["target_path"])) as Node3D
    if base == null or not base.visible:
        return result
    match str(entry["id"]):
        "unfinished_game":
            if not _meshes(base).is_empty():
                result.append(base)
        "invisible_dealer":
            for table_name in ["Cards5", "Cards7"]:
                var table := base.get_node_or_null(table_name) as Node3D
                if table == null or not table.visible:
                    result.clear()
                    return result
                for child in table.get_children():
                    if child is Node3D and child.visible and child.has_meta("source_card_index"):
                        result.append(child as Node3D)
            if result.size() != 16:
                result.clear()
        "breathing_wall":
            if base is MeshInstance3D and base.mesh is BoxMesh and base.get_active_material(0) is StandardMaterial3D:
                result.append(base)
        "forgotten_door", "black_bloom":
            if base is MeshInstance3D and base.mesh != null:
                result.append(base)
        "against_gravity":
            for bottle in base.find_children("Signature_3_*", "Node3D", true, false):
                if bottle.scene_file_path.is_empty():
                    continue
                var shell := bottle.get_node_or_null("HandCutGlassShell") as MeshInstance3D
                if shell == null or not shell.visible:
                    result.clear()
                    return result
                result.append(shell)
            if result.size() < 6:
                result.clear()
        "pendulum":
            var lamp := room.get_node_or_null("ModelInteriors/ChandelierWarmLight_02") as Light3D
            if lamp != null:
                result.append(base)
                result.append(lamp)
        "extra_guest":
            if Guest.available() and not _meshes(base).is_empty():
                result.append(base)
        "wrong_reflection":
            if ResourceLoader.exists(Mirror.MODEL, "PackedScene") and base is MeshInstance3D:
                result.append(base)
        "they_are_listening":
            for cabinet in base.get_children():
                if cabinet is Node3D and cabinet.visible and cabinet.has_meta("slot_cabinet_revision"):
                    var strip := cabinet.get_node_or_null("TopGlow") as MeshInstance3D
                    if strip != null and strip.visible and strip.get_active_material(0) is StandardMaterial3D:
                        result.append(strip)
            if result.size() < 4:
                result.clear()
    return result


func can_apply(room: Node3D, entry: Dictionary) -> bool:
    return not targets(room, entry).is_empty()


func snapshot(nodes: Array[Node3D], id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for node in nodes:
        var state := {"node": node, "transform": node.transform, "mark": node.has_node("AnomalyPack03")}
        if node is MeshInstance3D:
            state["mesh"] = node.mesh
            state["material"] = node.material_override
            state["layers"] = node.layers
        if node is Light3D:
            state["energy"] = node.light_energy
        result.append(state)
    return result


func _root(node: Node3D) -> Node3D:
    var marker := Node3D.new()
    marker.name = "AnomalyPack03"
    node.add_child(marker)
    roots.append(marker)
    return marker


func _material(color: Color, metallic: float = 0.0, roughness: float = 0.7) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = roughness
    return mat


func _mesh(parent: Node3D, name: String, shape: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
    var piece := MeshInstance3D.new()
    piece.name = name
    piece.mesh = shape
    piece.material_override = mat
    parent.add_child(piece)
    piece.position = at
    return piece


func _box(parent: Node3D, name: String, dimensions: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = dimensions
    return _mesh(parent, name, shape, mat, at)


func _sphere(parent: Node3D, name: String, radius: float, mat: Material, at: Vector3) -> MeshInstance3D:
    var shape := SphereMesh.new()
    shape.radius = radius
    shape.height = radius * 2.0
    shape.radial_segments = 16
    shape.rings = 8
    return _mesh(parent, name, shape, mat, at)


func _reduced(room: Node3D, lights: bool = false) -> bool:
    var settings := room.get_node_or_null("/root/GameSettings")
    return settings != null and (bool(settings.call("get_option", "reduced_motion")) or (lights and bool(settings.call("get_option", "reduce_light_motion"))))


func _animate(room: Node3D, duration: float, update: Callable) -> void:
    motion = room.create_tween().set_loops()
    motion.tween_method(func(phase: float) -> void:
        if not room.has_meta("_streaming_standby"):
            update.call(phase)
    , 0.0, 1.0, duration)


func apply(room: Node3D, entry: Dictionary) -> bool:
    clear()
    var nodes := targets(room, entry)
    if nodes.is_empty():
        return false
    var id := str(entry["id"])
    saved = snapshot(nodes, id)
    match id:
        "unfinished_game": _roulette(room, nodes[0])
        "invisible_dealer": _dealer(room, nodes)
        "breathing_wall": _breath(room, nodes[0] as MeshInstance3D)
        "forgotten_door": _door(nodes[0] as MeshInstance3D)
        "against_gravity": _liquid(room, nodes)
        "pendulum": _pendulum(room, nodes[0], nodes[1] as Light3D)
        "black_bloom": _bloom(room, nodes[0] as MeshInstance3D)
        "extra_guest":
            if Guest.install(nodes[0], _root(nodes[0])) == null:
                clear()
                return false
        "wrong_reflection":
            var mirror := Mirror.new()
            mirror.name = "AnomalyPack03"
            nodes[0].add_child(mirror)
            roots.append(mirror)
            if not mirror.configure(room, nodes[0] as MeshInstance3D):
                clear()
                return false
        "they_are_listening": _listening(room, nodes)
        _:
            clear()
            return false
    return true


func _roulette(room: Node3D, wheel: Node3D) -> void:
    var bounds := _bounds(wheel)
    var center := bounds.get_center()
    var radius := minf(bounds.size.x, bounds.size.z) * 0.40
    var level := bounds.end.y - 0.105
    # The visible outer lip is higher than the ball track. Keep the
    # accepted radius and lower the centre 8cm into the bowl.
    var ball := _sphere(_root(wheel), "OrbitingIvoryBall", 0.022, _material(Color("#e9e0c9"), 0.0, 0.26), Vector3(center.x + radius, level, center.z))
    _animate(room, 4.5, func(phase: float) -> void:
        var angle := TAU * (0.15 if _reduced(room) else phase)
        ball.position = Vector3(center.x + cos(angle) * radius, level, center.z + sin(angle) * radius)
    )


func _dealer(room: Node3D, nodes: Array[Node3D]) -> void:
    var original: Array[Vector3] = []
    var piles: Array[Vector3] = []
    for i in range(nodes.size()):
        original.append(nodes[i].position)
        var deck := Vector3(-0.44, nodes[i].position.y, -0.30)
        var pile := deck + Vector3(0.0, 0.004 * float(i % 8), 0.0)
        piles.append(pile)
        nodes[i].position = pile
    _animate(room, 14.0, func(phase: float) -> void:
        for i in range(nodes.size()):
            var card := i % 8
            var local := fposmod(phase + (0.22 if i >= 8 else 0.0), 1.0)
            var start := float(card) * 0.055
            var spread := smoothstep(start, start + 0.12, local)
            var gather := smoothstep(0.73 + float(7-card)*0.025, 0.88 + float(7-card)*0.017, local)
            var weight := spread * (1.0 - gather)
            if _reduced(room):
                weight = 0.0
            nodes[i].position = piles[i].lerp(original[i], weight)
            nodes[i].position.y += sin(weight * PI) * 0.025
    )


func _breath(room: Node3D, wall: MeshInstance3D) -> void:
    var original := wall.get_active_material(0) as StandardMaterial3D
    var subdivided := wall.mesh.duplicate() as BoxMesh
    subdivided.subdivide_width = 8
    subdivided.subdivide_height = 36
    subdivided.subdivide_depth = 96
    wall.mesh = subdivided
    var shader := Shader.new()
    shader.code = BREATH_SHADER
    var mat := ShaderMaterial.new()
    mat.shader = shader
    mat.set_shader_parameter("fabric", original.albedo_texture)
    mat.set_shader_parameter("bumps", original.normal_texture)
    mat.set_shader_parameter("has_bumps", original.normal_enabled and original.normal_texture != null)
    mat.set_shader_parameter("tint", original.albedo_color)
    mat.set_shader_parameter("uv_scale", original.uv1_scale)
    mat.set_shader_parameter("rough", original.roughness)
    wall.material_override = mat
    _animate(room, 6.0, func(phase: float) -> void:
        mat.set_shader_parameter("amplitude", 0.55 if _reduced(room) else 0.16 + 0.68 * pow(0.5 - 0.5 * cos(phase * TAU), 1.35))
    )


func _door(wall: MeshInstance3D) -> void:
    var root := _root(wall)
    # The entrance wall is intentionally hidden by streaming portals.
    # Use the intact south-west wall, in the open stretch before the lounge.
    var bounds := wall.get_aabb()
    root.position = Vector3(bounds.end.x - 6.3, bounds.position.y + 1.24, bounds.position.z - 0.31)
    var wood := _material(Color("#a39b90"), 0.0, 0.92)
    wood.albedo_texture = load("res://assets/wood_table_worn/wood_table_worn_diff_2k.jpg") as Texture2D
    wood.normal_enabled = true
    wood.normal_texture = load("res://assets/wood_table_worn/wood_table_worn_nor_gl_2k.jpg") as Texture2D
    wood.normal_scale = 0.6
    wood.roughness_texture = load("res://assets/wood_table_worn/wood_table_worn_rough_2k.jpg") as Texture2D
    var frame := wood.duplicate() as StandardMaterial3D
    frame.albedo_color = Color("#69615a")
    var inset := wood.duplicate() as StandardMaterial3D
    inset.albedo_color = Color("#c0b7ad")
    var metal := _material(Color("#716c5d"), 0.72, 0.64)
    _box(root, "WeatheredDoor", Vector3(0.96, 2.35, 0.075), Vector3.ZERO, wood)
    for side in [-1.0, 1.0]:
        _box(root, "Jamb", Vector3(0.095, 2.50, 0.13), Vector3(side * 0.53, 0, -0.025), frame)
    _box(root, "Lintel", Vector3(1.17, 0.11, 0.13), Vector3(0, 1.25, -0.025), frame)
    for index in range(2):
        _box(root, "RecessedPanel", Vector3(0.70, 0.86, 0.026), Vector3(0, -0.54 + float(index)*1.08, -0.047), inset)
    _box(root, "LockPlate", Vector3(0.095, 0.21, 0.018), Vector3(0.34, -0.05, -0.054), metal)
    _sphere(root, "DoorKnob", 0.047, metal, Vector3(0.34, -0.02, -0.098))


func _liquid(room: Node3D, nodes: Array[Node3D]) -> void:
    var emitter := RisingDrops.new()
    emitter.name = "AnomalyPack03"
    nodes[0].add_child(emitter)
    roots.append(emitter)
    emitter.configure(room, nodes)


func _pendulum(room: Node3D, chandelier: Node3D, lamp: Light3D) -> void:
    var original := chandelier.transform
    var light_origin := lamp.transform
    var bounds := _bounds(chandelier)
    var anchor := Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z)
    var world_anchor := original * anchor
    var update := func(phase: float) -> void:
        var angle := deg_to_rad(9.0) * (1.0 if _reduced(room, true) else cos(phase*TAU))
        var rotation := Basis(Vector3.FORWARD, angle)
        var new_basis := rotation * original.basis
        chandelier.transform = Transform3D(new_basis, world_anchor - new_basis * anchor)
        lamp.position = world_anchor + rotation * (light_origin.origin - world_anchor)
    update.call(0.0)
    _animate(room, 5.8, update)


func _bloom(room: Node3D, wall: MeshInstance3D) -> void:
    var marker := _root(wall)
    var bounds := wall.get_aabb()
    marker.position = Vector3(bounds.get_center().x, bounds.get_center().y + 0.3, bounds.position.z - 0.19)
    marker.rotation.y = PI
    var shape := QuadMesh.new()
    shape.size = Vector2(11.5, 4.5)
    var shader := Shader.new()
    shader.code = BLOOM_SHADER
    var mat := ShaderMaterial.new()
    mat.shader = shader
    mat.set_shader_parameter("growth", 0.55)
    _mesh(marker, "OrganicStain", shape, mat, Vector3.ZERO).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _animate(room, 11.0, func(phase: float) -> void:
        mat.set_shader_parameter("growth", 0.88 if _reduced(room) else 0.30 + 0.95 * (0.5 - 0.5*cos(phase*TAU)))
    )


func _listening(room: Node3D, nodes: Array[Node3D]) -> void:
    # The room may be torn down directly by Quit/Restart, without the
    # usual adapter clear. Restore the persistent audio in either case.
    var cleanup_marker := _root(nodes[0])
    cleanup_marker.tree_exiting.connect(_restore_audio)
    var view := ListeningView.new()
    view.name = "ListeningView"
    cleanup_marker.add_child(view)
    var materials: Array[StandardMaterial3D] = []
    var baseline: Array[float] = []
    var base_colors: Array[Color] = []
    for strip_node in nodes:
        var strip := strip_node as MeshInstance3D
        var mat := strip.get_active_material(0).duplicate() as StandardMaterial3D
        baseline.append(mat.emission_energy_multiplier)
        base_colors.append(mat.albedo_color)
        strip.material_override = mat
        materials.append(mat)
    for lamp in room.get_node("Lighting").get_children():
        if lamp is Light3D and str(lamp.name) in ["WarmCasinoLamp_01", "WarmCasinoLamp_02"]:
            glow_original.append({"node": lamp, "energy": lamp.light_energy})
    var clock := [0.0, 0.0]
    var origin := room.to_global(Vector3(0, 0, 5.0))
    _animate(room, 1.0, func(phase: float) -> void:
        var dt := phase - float(clock[0])
        if dt < 0.0:
            dt += 1.0
        clock[0] = phase
        var player := room.get_node_or_null("Player") as Node3D
        if player == null:
            return
        var distance := Vector2(player.global_position.x-origin.x, player.global_position.z-origin.z).length()
        var target := 1.0-smoothstep(4.5,11.0,distance)
        clock[1] = lerpf(float(clock[1]),target,1.0-exp(-dt*2.0))
        var weight := float(clock[1])
        for i in range(materials.size()):
            materials[i].emission_energy_multiplier = lerpf(baseline[i],0.0,weight)
            materials[i].albedo_color = base_colors[i].lerp(Color("#111014"), weight * 0.94)
        for state in glow_original:
            var lamp := state["node"] as Light3D
            if is_instance_valid(lamp):
                lamp.light_energy = lerpf(float(state["energy"]), float(state["energy"]) * 0.22, weight)
        view.set_intensity(weight, _reduced(room))
        var director := room.get_node_or_null("/root/AudioDirector")
        if director != null:
            var tone := director.get("room_player") as AudioStreamPlayer
            if tone != null and tone.playing:
                if not audio_original.has(tone):
                    audio_original[tone] = tone.volume_db
                tone.volume_db = lerpf(float(audio_original[tone]),-48.0,weight)
        var soundscape := room.get_node_or_null("RoomSoundscape")
        if soundscape != null:
            var sources: Array = soundscape.get("_sources")
            var levels: Array = soundscape.get("_target_db")
            for i in range(sources.size()):
                var emitter := sources[i] as AudioStreamPlayer3D
                if is_instance_valid(emitter) and emitter.playing:
                    if not audio_original.has(emitter):
                        audio_original[emitter] = levels[i]
                    emitter.volume_db = lerpf(float(audio_original[emitter]),-55.0,weight)
    )


func clear() -> void:
    if motion != null and motion.is_valid():
        motion.kill()
    motion = null
    for root_node in roots:
        if is_instance_valid(root_node):
            root_node.free()
    roots.clear()
    _restore_audio()
    for state in saved:
        var node := state["node"] as Node3D
        if not is_instance_valid(node):
            continue
        node.transform = state["transform"]
        if node is MeshInstance3D:
            node.mesh = state["mesh"]
            node.material_override = state["material"]
            node.layers = state["layers"]
        if node is Light3D:
            node.light_energy = state["energy"]
    saved.clear()


func _restore_audio() -> void:
    for emitter in audio_original:
        if is_instance_valid(emitter):
            emitter.volume_db = audio_original[emitter]
    audio_original.clear()
    for state in glow_original:
        var lamp := state["node"] as Light3D
        if is_instance_valid(lamp):
            lamp.light_energy = state["energy"]
    glow_original.clear()
