extends RefCounted
## Pack 03: room-local animated anomalies. Original resources and gameplay
## collisions remain untouched; temporary anomaly colliders are local. All generated nodes and tweens are owned
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
render_mode cull_disabled;
uniform float growth = 0.5;
varying float strand_progress;
varying float strand_length;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise2(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float tissue(vec2 p) {
    return noise2(p)*0.55 + noise2(p*3.1)*0.28 + noise2(p*9.2)*0.17;
}
void vertex() {
    // UV2 stores radius and the delayed start of each individual strand.
    strand_progress = clamp((growth - UV2.y) / (1.0 - UV2.y), 0.0, 1.0);
    strand_length = COLOR.r * 32.0;
    float taper = 1.0 - smoothstep(max(0.0,strand_progress-0.075), max(0.001,strand_progress), UV.x);
    VERTEX -= NORMAL * UV2.x * (1.0-taper);
}
void fragment() {
    if (strand_progress <= 0.001 || UV.x > strand_progress) { discard; }
    vec2 p = UV * vec2(max(95.0, strand_length*48.0), 12.0);
    float grain = tissue(p);
    float ridge = 0.5 + 0.5*sin(UV.y*37.699 + noise2(vec2(UV.x*32.0,UV.y*5.0))*5.0);
    float fibers = ridge * (0.25 + 0.75*noise2(p*0.45));
    ALBEDO = mix(vec3(0.017,0.010,0.012),vec3(0.094,0.049,0.052),grain*0.68 + fibers*0.18);
    ROUGHNESS = mix(0.40,0.81,grain);
    SPECULAR = 0.38;
    vec2 relief = vec2(tissue(p+vec2(0.15,0.0))-tissue(p-vec2(0.15,0.0)),tissue(p+vec2(0.0,0.15))-tissue(p-vec2(0.0,0.15)));
    NORMAL_MAP = vec3(vec2(0.5) - relief*0.42,1.0);
    NORMAL_MAP_DEPTH = 0.65;
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
    const BALL_RADIUS := 0.022
    # The spindle is much taller than the wooden ball track. Sample the
    # imported wheel's triangles at the accepted orbit, not its top AABB.
    var track := _roulette_track_height(wheel, bounds, radius)
    var level := track + BALL_RADIUS
    var ball := _sphere(_root(wheel), "OrbitingIvoryBall", BALL_RADIUS, _material(Color("#e9e0c9"), 0.0, 0.26), Vector3(center.x + radius, level, center.z))
    _animate(room, 4.5, func(phase: float) -> void:
        var angle := TAU * (0.15 if _reduced(room) else phase)
        ball.position = Vector3(center.x + cos(angle) * radius, level, center.z + sin(angle) * radius)
    )


func _roulette_track_height(wheel: Node3D, bounds: AABB, radius: float) -> float:
    const SAMPLES := 16
    var center := bounds.get_center()
    var sample_points: Array[Vector2] = []
    var heights: Array[float] = []
    for index in range(SAMPLES):
        var angle := TAU * float(index) / float(SAMPLES)
        sample_points.append(Vector2(center.x + cos(angle)*radius, center.z + sin(angle)*radius))
        heights.append(-INF)
    var inverse := wheel.global_transform.affine_inverse()
    for part in _meshes(wheel):
        # The anomaly's own ball is not part of the source wheel geometry.
        var effect := wheel.get_node_or_null("AnomalyPack03")
        if effect != null and effect.is_ancestor_of(part):
            continue
        var transform_to_wheel := inverse * part.global_transform
        var part_bounds: AABB = transform_to_wheel * part.get_aabb()
        var candidates: Array[int] = []
        for index in range(SAMPLES):
            var point := sample_points[index]
            if point.x >= part_bounds.position.x and point.x <= part_bounds.end.x and point.y >= part_bounds.position.z and point.y <= part_bounds.end.z:
                candidates.append(index)
        if candidates.is_empty():
            continue
        var faces := part.mesh.get_faces()
        for i in range(0, faces.size()-2, 3):
            var a: Vector3 = transform_to_wheel * faces[i]
            var b: Vector3 = transform_to_wheel * faces[i+1]
            var c: Vector3 = transform_to_wheel * faces[i+2]
            var low_x := minf(a.x,minf(b.x,c.x))
            var high_x := maxf(a.x,maxf(b.x,c.x))
            var low_z := minf(a.z,minf(b.z,c.z))
            var high_z := maxf(a.z,maxf(b.z,c.z))
            var ab := Vector2(b.x-a.x,b.z-a.z)
            var ac := Vector2(c.x-a.x,c.z-a.z)
            var denominator := ab.cross(ac)
            if absf(denominator) < 0.00000001:
                continue
            for index in candidates:
                var point := sample_points[index]
                if point.x < low_x or point.x > high_x or point.y < low_z or point.y > high_z:
                    continue
                var ap := point - Vector2(a.x,a.z)
                var u := ap.cross(ac)/denominator
                var v := ab.cross(ap)/denominator
                if u >= -0.0001 and v >= -0.0001 and u+v <= 1.0001:
                    var y := a.y + u*(b.y-a.y) + v*(c.y-a.y)
                    heights[index] = maxf(heights[index], y)
    var valid: Array[float] = []
    for height in heights:
        if is_finite(height):
            valid.append(height)
    if valid.size() >= SAMPLES / 2:
        # Median removes isolated decorative ridges and keeps a smooth
        # horizontal orbit across the rotationally symmetric track.
        valid.sort()
        return valid[int(valid.size()/2.0)]
    # Conservative lower-bowl fallback for imported meshes without CPU faces.
    return bounds.position.y + bounds.size.y * 0.25


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
    # The wainscoting projects 7 cm beyond the inner wall face.
    # The frame rear projects 4 cm behind this origin; seat it on the trim.
    root.position = Vector3(bounds.end.x - 7.9, bounds.position.y + 1.25, bounds.position.z - 0.112)
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
    # Fill the small depth difference between the wood trim and upper wall.
    _box(root, "DoorBacking", Vector3(1.17, 2.50, 0.12), Vector3(0, 0, 0.052), frame)
    _box(root, "WeatheredDoor", Vector3(0.96, 2.35, 0.075), Vector3.ZERO, wood)
    for side in [-1.0, 1.0]:
        _box(root, "Jamb", Vector3(0.095, 2.50, 0.13), Vector3(side * 0.53, 0, -0.025), frame)
    _box(root, "Lintel", Vector3(1.17, 0.11, 0.13), Vector3(0, 1.25, -0.025), frame)
    for index in range(2):
        _box(root, "RecessedPanel", Vector3(0.70, 0.86, 0.026), Vector3(0, -0.54 + float(index)*1.08, -0.047), inset)
    _box(root, "LockPlate", Vector3(0.095, 0.21, 0.018), Vector3(0.34, -0.05, -0.054), metal)
    _sphere(root, "DoorKnob", 0.047, metal, Vector3(0.34, -0.02, -0.098))
    var body := StaticBody3D.new()
    body.name = "DoorCollision"
    root.add_child(body)
    var collider := CollisionShape3D.new()
    collider.name = "Shape"
    var collision_box := BoxShape3D.new()
    collision_box.size = Vector3(1.17, 2.55, 0.25)
    collider.shape = collision_box
    body.add_child(collider)
    collider.position = Vector3(0, 0.025, -0.025)


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
    # Occupy nearly the whole 40 m wall, above the wooden wainscoting.
    # +Z of the marker points into the casino, +X towards the lounge.
    marker.position = Vector3(bounds.get_center().x, bounds.get_center().y + 0.65, bounds.position.z - 0.004)
    marker.rotation.y = PI
    var span := bounds.size.x * 0.5
    var pillars: Array[AABB] = []
    for item in wall.get_parent().get_children():
        if item is MeshInstance3D and item.mesh != null and item.get_meta("decor_type", "") == "pillar":
            var box: AABB = (marker.global_transform.affine_inverse() * item.global_transform) * item.get_aabb()
            if box.position.z < 0.07 and box.end.z > 0.025 and absf(box.get_center().x) < span:
                pillars.append(box)
    var shader := Shader.new()
    shader.code = BLOOM_SHADER
    var mat := ShaderMaterial.new()
    mat.shader = shader
    mat.set_shader_parameter("growth", 0.34)
    # Primary tendrils snake outwards from the center. Independent paths
    # reach the last wall bays, leaving open wall between the thin ridges.
    # Each entry: start, end, radius, onset (X in fractions of half-width).
    var trunks: Array[Array] = [
        [Vector2(-0.025,0.04),Vector2(-0.94,0.62),0.050,0.00],
        [Vector2(-0.035,-0.18),Vector2(-0.88,-0.89),0.042,0.06],
        [Vector2(-0.065,0.35),Vector2(-0.76,1.03),0.032,0.10],
        [Vector2(0.025,0.09),Vector2(0.94,-0.42),0.053,0.02],
        [Vector2(0.04,0.24),Vector2(0.87,1.05),0.040,0.07],
        [Vector2(0.07,-0.22),Vector2(0.73,-0.97),0.032,0.12]
    ]
    for i in range(trunks.size()):
        var data: Array = trunks[i]
        var start := Vector2(data[0].x*span,data[0].y)
        var finish := Vector2(data[1].x*span,data[1].y)
        var direction := finish-start
        var seed := float(i)*1.73
        var onset := float(data[3])
        var strand := _bloom_strand(start,direction,float(data[2]),onset,seed,pillars)
        _mesh(marker,"OrganicStrand_%02d" % i,strand,mat,Vector3.ZERO)
        # Branches grow from actual points on the winding main path only
        # once the primary growth front has reached their junction.
        for j in range(2):
            var junction := 0.27 + 0.32*float(j)
            var branch_start := _bloom_point(start,direction,seed,junction)
            var branch_end := Vector2(
                clampf(branch_start.x+signf(direction.x)*span*(0.20 if j == 0 else 0.24),-span*0.95,span*0.95),
                clampf(branch_start.y+(0.78 if (i+j)%2 == 0 else -0.76),-1.05,1.18))
            var branch_delay := onset + (1.0-onset)*junction
            var branch := _bloom_strand(branch_start,branch_end-branch_start,float(data[2])*0.52,branch_delay,seed+4.4+float(j)*2.3,pillars)
            _mesh(marker,"OrganicBranch_%02d_%02d" % [i,j],branch,mat,Vector3.ZERO)
    # A slow wall-length spread, then retreat, without widening into a mass.
    _animate(room, 32.0, func(phase: float) -> void:
        var growth := 0.34 + 0.66 * (0.5 - 0.5*cos(phase*TAU))
        mat.set_shader_parameter("growth", 1.0 if _reduced(room) else growth)
    )


func _bloom_point(origin: Vector2, direction: Vector2, seed: float, t: float) -> Vector2:
    var sideways := Vector2(-direction.y,direction.x).normalized()
    var length := direction.length()
    var frequency := maxf(9.4,length*2.3)
    var wiggle := (sin(t*frequency+seed)-sin(seed))*minf(0.28,0.095+length*0.012)
    wiggle += (sin(t*frequency*2.31+seed*0.6)-sin(seed*0.6))*minf(0.105,0.041+length*0.004)
    var point := origin+direction*t+sideways*wiggle
    point.y = clampf(point.y,-1.40,1.48)
    return point


func _bloom_depth(point: Vector2, pillars: Array[AABB]) -> float:
    var depth := 0.0
    for box in pillars:
        if point.y < box.position.y or point.y > box.end.y:
            continue
        var distance := absf(point.x-box.get_center().x)-box.size.x*0.5
        # Rise over each timber column and settle back onto the plaster.
        var weight := 1.0-smoothstep(0.0,0.10,distance)
        depth = maxf(depth,weight*(box.end.z+0.003))
    return depth


func _bloom_strand(origin: Vector2, direction: Vector2, thickness: float, delay: float, seed: float, pillars: Array[AABB]) -> ArrayMesh:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var length := direction.length()
    var segments := clampi(int(ceil(length*18.0)),56,360)
    const SIDES := 12
    # Indexed rings: evaluate each center only once, keep fine geometry on
    # long paths without the old duplicated triangle vertices.
    for segment in range(segments+1):
        var t := float(segment)/float(segments)
        var point := _bloom_point(origin,direction,seed,t)
        var before := _bloom_point(origin,direction,seed,t-0.001)
        var after := _bloom_point(origin,direction,seed,t+0.001)
        var depth := _bloom_depth(point,pillars)
        var tangent := Vector3(after.x-before.x,after.y-before.y,_bloom_depth(after,pillars)-_bloom_depth(before,pillars)).normalized()
        if tangent.length_squared() < 0.00001:
            tangent = Vector3(direction.x,direction.y,0.0).normalized()
        var across := Vector3(-tangent.y,tangent.x,0.0).normalized()
        var outward := tangent.cross(across).normalized()
        var radius := thickness*(0.78+0.15*sin(t*23.0+seed)+0.12*sin(t*53.0+seed))*lerpf(1.0,0.15,pow(t,1.8))
        radius = maxf(0.0015,radius)
        for side in range(SIDES+1):
            var u := float(side)/float(SIDES)
            var angle := u*TAU
            var n := across*cos(angle)+outward*sin(angle)
            tool.set_normal(n)
            tool.set_color(Color(clampf(length/32.0,0.0,1.0),0.0,0.0,1.0))
            tool.set_uv(Vector2(t,u))
            tool.set_uv2(Vector2(radius,delay))
            tool.add_vertex(Vector3(point.x,point.y,depth)+n*radius)
    for segment in range(segments):
        for side in range(SIDES):
            var a := segment*(SIDES+1)+side
            var b := a+SIDES+1
            for index in [a,b,b+1,a,b+1,a+1]:
                tool.add_index(index)
    tool.generate_tangents()
    return tool.commit()


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
