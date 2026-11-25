extends Node3D
## Real rigid-body droplets; only collide against a dedicated ceiling
## collider. No interaction with player, bottles, furniture or other drops.
const CEILING_LAYER := 1 << 27
const LIFETIME := 5.0
const MAX_PER_BOTTLE := 3
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
    top_level = true
    global_transform = room.global_transform
    var ceiling := room.get_node_or_null("Architecture/MainCeiling") as MeshInstance3D
    if ceiling != null:
        var ceiling_box: AABB = (room.global_transform.affine_inverse() * ceiling.global_transform) * ceiling.get_aabb()
        ceiling_height = ceiling_box.position.y
    var min_x := INF
    var max_x := -INF
    var avg_z := 0.0
    for shell_node in shells:
        var shell := shell_node as MeshInstance3D
        var bottle := shell.get_parent() as Node3D
        var top := shell.get_aabb().get_center()
        top.y = shell.get_aabb().end.y + 0.09
        var start := to_local(shell.to_global(top))
        sources.append(start)
        min_x = minf(min_x, start.x)
        max_x = maxf(max_x, start.x)
        avg_z += start.z
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color("#a76224")
        var liquid := bottle.get_node_or_null("InnerLiquidVolume") as MeshInstance3D
        if liquid != null and liquid.get_active_material(0) is StandardMaterial3D:
            mat.albedo_color = (liquid.get_active_material(0) as StandardMaterial3D).albedo_color
            mat.albedo_color.a = 1.0
        mat.roughness = 0.15
        mat.metallic = 0.12
        materials.append(mat)
        next_spawn.append(float(sources.size()-1) * 0.12)
    avg_z /= float(sources.size())
    var roof := StaticBody3D.new()
    roof.name = "DropletCeiling"
    roof.collision_layer = CEILING_LAYER
    roof.collision_mask = 0
    var shape := CollisionShape3D.new()
    var slab := BoxShape3D.new()
    slab.size = Vector3(max_x-min_x+2.0, 0.20, 2.2)
    shape.shape = slab
    roof.add_child(shape)
    add_child(roof)
    roof.position = Vector3((min_x+max_x)*0.5, ceiling_height+0.10, avg_z)
    var settings := room.get_node_or_null("/root/GameSettings")
    reduced = settings != null and bool(settings.call("get_option","reduced_motion"))
    # A visible initial clue even in headless apply / reduced motion.
    for i in range(sources.size()):
        _spawn(i, true)


func _spawn(index: int, initial: bool = false) -> void:
    var body := RigidBody3D.new()
    body.name = "RisingLiquid"
    body.collision_layer = 0
    body.collision_mask = CEILING_LAYER
    body.gravity_scale = -0.36
    body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
    body.linear_damp = 0.12
    body.continuous_cd = true
    body.can_sleep = false
    var physics := PhysicsMaterial.new()
    physics.bounce = 0.67
    physics.friction = 0.08
    body.physics_material_override = physics
    var shape := CollisionShape3D.new()
    var sphere_shape := SphereShape3D.new()
    sphere_shape.radius = 0.031
    shape.shape = sphere_shape
    body.add_child(shape)
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.031
    sphere.height = 0.062
    sphere.radial_segments = 12
    sphere.rings = 6
    mesh.mesh = sphere
    mesh.material_override = materials[index]
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    body.add_child(mesh)
    body.freeze = reduced or hall.has_meta("_streaming_standby")
    add_child(body)
    body.position = sources[index] + Vector3(0, 0.24 if initial else 0.0, 0)
    body.linear_velocity = Vector3(0.02 * sin(float(index)), 0.8, 0.02)
    active.append({"body":body,"age":0.0,"index":index})


func _physics_process(delta: float) -> void:
    if not is_instance_valid(hall) or hall.has_meta("_streaming_standby"):
        return
    var settings := hall.get_node_or_null("/root/GameSettings")
    reduced = settings != null and bool(settings.call("get_option","reduced_motion"))
    for record in active:
        var body := record["body"] as RigidBody3D
        if is_instance_valid(body):
            body.freeze = reduced
    if reduced:
        return
    clock += delta
    for i in range(active.size()-1,-1,-1):
        var record: Dictionary = active[i]
        var body := record["body"] as RigidBody3D
        if not is_instance_valid(body):
            active.remove_at(i)
            continue
        record["age"] = float(record["age"]) + delta
        if float(record["age"]) >= LIFETIME or body.position.y > ceiling_height+0.25:
            body.queue_free()
            active.remove_at(i)
    for i in range(sources.size()):
        if clock < next_spawn[i]:
            continue
        var count := 0
        for record in active:
            if int(record["index"]) == i:
                count += 1
        if count < MAX_PER_BOTTLE:
            _spawn(i)
        next_spawn[i] = clock + 1.65
