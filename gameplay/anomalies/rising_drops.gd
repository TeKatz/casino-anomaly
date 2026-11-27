extends Node3D
## Inverted rain: a fixed pool of shaped, translucent drops with analytic
## upward trajectories. No rigid bodies, collision shapes or ceiling bounce.
const MAX_PER_BOTTLE := 3
const ACCELERATION := 2.45
const START_SPEED := 0.38
const SPAWN_INTERVAL := 1.25
var hall: Node3D
var sources: Array[Vector3] = []
var materials: Array[StandardMaterial3D] = []
var active: Array[Dictionary] = []
var next_spawn: Array[float] = []
var clock := 0.0
var reduced := false
var ceiling_height := 5.94


func configure(room: Node3D, shells: Array[Node3D]) -> void:
    hall = room
    # Stay attached to the streamed room even if its parent is repositioned.
    transform = (get_parent() as Node3D).global_transform.affine_inverse() * room.global_transform
    var ceiling := room.get_node_or_null("Architecture/MainCeiling") as MeshInstance3D
    if ceiling != null:
        var ceiling_box: AABB = (room.global_transform.affine_inverse() * ceiling.global_transform) * ceiling.get_aabb()
        ceiling_height = ceiling_box.position.y
    var shape := _drop_mesh()
    for shell_node in shells:
        var shell := shell_node as MeshInstance3D
        var bottle := shell.get_parent() as Node3D
        var top := shell.get_aabb().get_center()
        top.y = shell.get_aabb().end.y + 0.09
        var start := to_local(shell.to_global(top))
        sources.append(start)
        var mat := StandardMaterial3D.new()
        var tint := Color("#a76224")
        var liquid := bottle.get_node_or_null("InnerLiquidVolume") as MeshInstance3D
        if liquid != null and liquid.get_active_material(0) is StandardMaterial3D:
            tint = (liquid.get_active_material(0) as StandardMaterial3D).albedo_color
        tint = tint.lerp(Color(0.92, 0.77, 0.58), 0.20)
        tint.a = 0.74
        mat.albedo_color = tint
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.roughness = 0.065
        mat.metallic = 0.0
        mat.metallic_specular = 0.58
        mat.clearcoat_enabled = true
        mat.clearcoat = 0.75
        mat.clearcoat_roughness = 0.08
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        materials.append(mat)
        next_spawn.append(0.35 + float(sources.size()-1) * 0.11)
    for i in range(sources.size()):
        for slot in range(MAX_PER_BOTTLE):
            var drop := MeshInstance3D.new()
            drop.name = "RisingLiquid_%02d_%d" % [i, slot]
            drop.mesh = shape
            drop.material_override = materials[i]
            drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            drop.visible = false
            add_child(drop)
            active.append({"mesh": drop, "age": -1.0, "index": i, "radius": 0.024, "seed": float(i * 3 + slot), "duration": 1.0})
        _spawn(i, true)


# A rounded leading end and mildly tapered trailing end; the drop is
# oriented upward. The reusable mesh has smooth analytic surface normals.
func _drop_mesh() -> ArrayMesh:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    const SIDES := 16
    const RINGS := 12
    for ring in range(RINGS + 1):
        var t := float(ring) / float(RINGS)
        var y := -cos(t * PI)
        var radial := maxf(0.0005, sin(t * PI) * (0.82 + 0.18 * t))
        for side in range(SIDES + 1):
            var u := float(side) / float(SIDES)
            var angle := TAU * u
            var normal := Vector3(cos(angle) * sin(t * PI), y, sin(angle) * sin(t * PI)).normalized()
            tool.set_normal(normal)
            tool.set_uv(Vector2(u, t))
            tool.add_vertex(Vector3(cos(angle) * radial, y * 1.20, sin(angle) * radial))
    for ring in range(RINGS):
        for side in range(SIDES):
            var a := ring * (SIDES + 1) + side
            var b := a + SIDES + 1
            for index in [a, a+1, b, a+1, b+1, b]:
                tool.add_index(index)
    return tool.commit()


func _duration(index: int, radius: float) -> float:
    var travel := maxf(0.05, ceiling_height - radius * 1.8 - sources[index].y)
    return (-START_SPEED + sqrt(START_SPEED * START_SPEED + 2.0 * ACCELERATION * travel)) / ACCELERATION


func sample_drop(index: int, radius: float, seed: float, age: float) -> Dictionary:
    var duration := _duration(index, radius)
    var t := clampf(age, 0.0, duration)
    var progress := t / duration
    var drift := Vector3(sin(seed * 1.7 + t * 1.6) - sin(seed * 1.7), 0.0, cos(seed * 2.1 + t * 1.3) - cos(seed * 2.1)) * 0.023
    var at := sources[index] + Vector3.UP * (START_SPEED * t + 0.5 * ACCELERATION * t * t) + drift
    var opacity := smoothstep(0.0, 0.06, progress) * (1.0 - smoothstep(0.77, 1.0, progress))
    return {"position": at, "opacity": opacity, "duration": duration}


func _spawn(index: int, initial: bool = false) -> void:
    for record in active:
        if int(record["index"]) != index or float(record["age"]) >= 0.0:
            continue
        var seed := float(record["seed"]) + clock * 0.73
        var radius := lerpf(0.017, 0.035, 0.5 + 0.5 * sin(seed * 9.17 + 0.7))
        var duration := _duration(index, radius)
        record["radius"] = radius
        record["duration"] = duration
        record["seed"] = seed
        record["age"] = duration * (0.12 + 0.14 * fposmod(float(index) * 0.37, 1.0)) if initial else 0.0
        var drop := record["mesh"] as MeshInstance3D
        drop.scale = Vector3(radius, radius, radius)
        _update_drop(record)
        return


func _update_drop(record: Dictionary) -> void:
    var drop := record["mesh"] as MeshInstance3D
    var sample := sample_drop(int(record["index"]), float(record["radius"]), float(record["seed"]), float(record["age"]))
    drop.position = sample["position"]
    drop.transparency = 1.0 - float(sample["opacity"])
    drop.visible = float(sample["opacity"]) > 0.001


func _process(delta: float) -> void:
    if not is_instance_valid(hall) or hall.has_meta("_streaming_standby"):
        return
    var settings := hall.get_node_or_null("/root/GameSettings")
    reduced = settings != null and bool(settings.call("get_option", "reduced_motion"))
    if reduced:
        return
    clock += delta
    for record in active:
        if float(record["age"]) < 0.0:
            continue
        record["age"] = float(record["age"]) + delta
        if float(record["age"]) >= float(record["duration"]):
            (record["mesh"] as MeshInstance3D).hide()
            record["age"] = -1.0
        else:
            _update_drop(record)
    for i in range(sources.size()):
        if clock >= next_spawn[i]:
            _spawn(i)
            next_spawn[i] = clock + SPAWN_INTERVAL + 0.19 * sin(float(i) * 2.3 + clock * 0.7)
