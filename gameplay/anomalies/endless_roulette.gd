extends Node3D
## Room-local rotor partition, with source vertex attributes/materials intact.
## The source nodes are never reparented and their collision is not changed.
const BALL_RADIUS := 0.022
const PROFILE_STEPS := 12
static var _mesh_cache: Dictionary = {}
var hall: Node3D
var wheel: Node3D
var rotor: Node3D
var ball: MeshInstance3D
var originals: Array[Dictionary] = []
var center := Vector3.ZERO
var outer_radius := 0.5
var inner_radius := 0.25
var profile: Array[float] = []
var elapsed := 0.0
var duration := 20.0
var cycle := 0
var angle := 0.0
var radius := 0.0
var speed := 0.0


func configure(room: Node3D, source: Node3D, bounds: AABB, probe: RefCounted) -> bool:
    hall = room
    wheel = source
    center = bounds.get_center()
    var diameter := minf(bounds.size.x, bounds.size.z)
    outer_radius = diameter * 0.40
    inner_radius = diameter * 0.235
    radius = outer_radius
    speed = 3.8
    # Sample actual top surfaces from outer track to pocket region; a
    # conservative envelope of adjacent samples avoids falling through lips.
    # Cache only immutable numeric data and derived meshes, never live nodes.
    var parts: Array[MeshInstance3D] = []
    var key := ""
    for item in wheel.find_children("*", "MeshInstance3D", true, false):
        var mesh := item as MeshInstance3D
        if mesh.mesh is ArrayMesh and mesh.visible:
            parts.append(mesh)
            key += str(mesh.mesh.get_rid()) + str(wheel.global_transform.affine_inverse() * mesh.global_transform)
    if parts.is_empty():
        return false
    var cached: Dictionary = _mesh_cache.get(key, {})
    if cached.is_empty():
        var heights: Array[float] = []
        for i in range(PROFILE_STEPS + 1):
            var r := lerpf(inner_radius, outer_radius, float(i) / float(PROFILE_STEPS))
            heights.append(float(probe.call("_roulette_track_height", wheel, bounds, r)))
        var partition: Array[Dictionary] = []
        for mesh in parts:
            var local := wheel.global_transform.affine_inverse() * mesh.global_transform
            partition.append(_partition(mesh.mesh as ArrayMesh, local, diameter * 0.315, bounds.position.y + bounds.size.y * 0.09))
        cached = {"heights": heights, "partition": partition}
        if _mesh_cache.size() >= 4:
            _mesh_cache.clear()
        _mesh_cache[key] = cached
    profile.assign(cached["heights"])
    var partitions: Array = cached["partition"]
    rotor = Node3D.new()
    rotor.name = "InnerRotor"
    add_child(rotor)
    rotor.position = Vector3(center.x, 0.0, center.z)
    var moving := 0
    for i in range(parts.size()):
        var source_mesh := parts[i]
        var split: Dictionary = partitions[i]
        if split["rotating"] == null:
            continue
        var transform_to_wheel := wheel.global_transform.affine_inverse() * source_mesh.global_transform
        originals.append({"node": source_mesh, "visible": source_mesh.visible})
        source_mesh.hide()
        if split["stationary"] != null:
            _copy_part(source_mesh, split["stationary"], split["static_surfaces"], self, transform_to_wheel)
        _copy_part(source_mesh, split["rotating"], split["moving_surfaces"], rotor, rotor.transform.affine_inverse() * transform_to_wheel)
        moving += 1
    if moving == 0:
        return false
    var sphere := SphereMesh.new()
    sphere.radius = BALL_RADIUS
    sphere.height = BALL_RADIUS * 2.0
    sphere.radial_segments = 24
    sphere.rings = 12
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#e9e0c9")
    material.roughness = 0.24
    ball = MeshInstance3D.new()
    ball.name = "OrbitingIvoryBall"
    ball.mesh = sphere
    ball.material_override = material
    add_child(ball)
    ball.position = Vector3(center.x + radius, profile[-1] + BALL_RADIUS, center.z)
    return true


func _partition(mesh: ArrayMesh, local: Transform3D, limit: float, bottom: float) -> Dictionary:
    # Preserve the source surface arrays (including normals, UVs and tangents).
    # Partition only complete indexed triangles inside the inner radial zone.
    # Outer bowl triangles are retained, never rotated as a single whole mesh.
    var static_mesh := ArrayMesh.new()
    var moving_mesh := ArrayMesh.new()
    var static_surfaces: Array[int] = []
    var moving_surfaces: Array[int] = []
    for surface in range(mesh.get_surface_count()):
        if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
            continue
        var arrays := mesh.surface_get_arrays(surface)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
        if indices.is_empty():
            indices.resize(vertices.size())
            for index in range(vertices.size()):
                indices[index] = index
        var inside := PackedByteArray()
        inside.resize(vertices.size())
        for i in range(vertices.size()):
            var p := local * vertices[i]
            var r := Vector2(p.x-center.x, p.z-center.z).length()
            inside[i] = 1 if r <= limit and p.y >= bottom else 0
        var still := PackedInt32Array()
        var spin := PackedInt32Array()
        for i in range(0, indices.size()-2, 3):
            var a := indices[i]
            var b := indices[i+1]
            var c := indices[i+2]
            if inside[a] != 0 and inside[b] != 0 and inside[c] != 0:
                spin.append(a)
                spin.append(b)
                spin.append(c)
            else:
                still.append(a)
                still.append(b)
                still.append(c)
        if not still.is_empty():
            var data := arrays.duplicate()
            data[Mesh.ARRAY_INDEX] = still
            static_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
            static_mesh.surface_set_material(static_mesh.get_surface_count()-1, mesh.surface_get_material(surface))
            static_surfaces.append(surface)
        if not spin.is_empty():
            var data := arrays.duplicate()
            data[Mesh.ARRAY_INDEX] = spin
            moving_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
            moving_mesh.surface_set_material(moving_mesh.get_surface_count()-1, mesh.surface_get_material(surface))
            moving_surfaces.append(surface)
    return {"stationary": static_mesh if static_mesh.get_surface_count() > 0 else null,
        "rotating": moving_mesh if moving_mesh.get_surface_count() > 0 else null,
        "static_surfaces": static_surfaces, "moving_surfaces": moving_surfaces}


func _copy_part(original: MeshInstance3D, geometry: ArrayMesh, surfaces: Array, parent: Node3D, local: Transform3D) -> void:
    var part := MeshInstance3D.new()
    part.mesh = geometry
    part.material_override = original.material_override
    part.material_overlay = original.material_overlay
    part.cast_shadow = original.cast_shadow
    part.layers = original.layers
    part.gi_mode = original.gi_mode
    for i in range(surfaces.size()):
        part.set_surface_override_material(i, original.get_surface_override_material(int(surfaces[i])))
    parent.add_child(part)
    part.transform = local


func track_height(r: float) -> float:
    var index := clampf((r-inner_radius)/(outer_radius-inner_radius),0.0,1.0)*float(PROFILE_STEPS)
    var a := floori(index)
    var b := mini(a+1,PROFILE_STEPS)
    return lerpf(profile[a],profile[b],index-float(a))


# The phases meet with continuous positions and speeds. The apparent result
# is never reached; the ball climbs back up the bowl before settling.
func cycle_targets(phase: float, serial: int) -> Vector2:
    var minimum := inner_radius + (outer_radius-inner_radius)*lerpf(0.02,0.12,0.5+0.5*sin(float(serial)*2.17))
    if phase < 0.46:
        return Vector2(outer_radius,lerpf(3.8,1.45,smoothstep(0.0,0.46,phase)))
    if phase < 0.78:
        return Vector2(lerpf(outer_radius,minimum,smoothstep(0.46,0.78,phase)),lerpf(1.45,0.25,smoothstep(0.46,0.78,phase)))
    return Vector2(lerpf(minimum,outer_radius,smoothstep(0.78,1.0,phase)),lerpf(0.25,3.8,smoothstep(0.78,1.0,phase)))


func advance(delta: float) -> void:
    elapsed += delta
    while elapsed >= duration:
        elapsed -= duration
        cycle += 1
        duration = 19.0 + 2.4*sin(float(cycle)*1.71)
    var phase := elapsed/duration
    var targets := cycle_targets(phase,cycle)
    radius = targets.x
    speed = targets.y
    angle = fposmod(angle+speed*delta,TAU)
    rotor.rotation.y = fposmod(rotor.rotation.y+delta*0.52,TAU)
    var old := ball.position
    # Small continuous deflector hops only inside the bowl; the ball rests
    # on the accepted outer track at the beginning/end of every cycle.
    var hop_window := smoothstep(0.48,0.60,phase)*(1.0-smoothstep(0.70,0.79,phase))
    var hop := hop_window*pow(absf(sin(angle*12.0)),3.0)*0.018
    ball.position = Vector3(center.x+cos(angle)*radius, track_height(radius)+BALL_RADIUS+hop, center.z+sin(angle)*radius)
    var travel := ball.position-old
    var horizontal := Vector3(travel.x,0.0,travel.z)
    if horizontal.length_squared() > 0.00000001:
        ball.rotate(Vector3.UP.cross(horizontal).normalized(),horizontal.length()/BALL_RADIUS)


func _process(delta: float) -> void:
    if ball == null or not is_instance_valid(hall) or hall.has_meta("_streaming_standby"):
        return
    var settings := hall.get_node_or_null("/root/GameSettings")
    if settings != null and bool(settings.call("get_option","reduced_motion")):
        return
    advance(delta)


func _exit_tree() -> void:
    for state in originals:
        var mesh := state["node"] as MeshInstance3D
        if is_instance_valid(mesh):
            mesh.visible = bool(state["visible"])
    originals.clear()
