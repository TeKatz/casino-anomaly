extends SceneTree
## One-time GPU-assisted offline bake. Run from a checked-out project using
## Godot 4.5.1 with a Vulkan/D3D12-capable display (NOT --headless):
## Godot_v4.5.1-stable_win64_console.exe --path . --script res://tools/bake_voxel_gi.gd
##
## Creates two external binary .res resources. Commit those files before
## releasing VoxelGI-enabled builds. Never run inside the gameplay loop.
const ROOM = preload("res://main.tscn")
const OUTPUTS := {
    "MainWingGI": "res://lighting/main_wing.res",
    "WestWingGI": "res://lighting/west_wing.res"
}


func _initialize() -> void:
    call_deferred("_bake")


func _fail(message: String) -> void:
    push_error("VoxelGI bake: " + message)
    quit(1)


# Godot 4.5 names this property light_bake_mode, not bake_mode.
# Kept in a helper so headless regression tests exercise the exact code
# executed when baking real lights on a developer's GPU.
static func configure_baked_light(light: Light3D) -> void:
    light.light_bake_mode = Light3D.BAKE_STATIC


func _emissive_proxy(parent: Node3D, label: String, pos: Vector3,
        size: Vector3, color: Color, energy: float) -> void:
    # The actual 3-cm cove is thinner than a voxel. Bake-only, thicker
    # emitter proxies allow its warm light to contribute at SUBDIV_128.
    # They never exist in the normal playable scene.
    var node := MeshInstance3D.new()
    node.name = label
    node.position = pos
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = energy
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    node.material_override = mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
    parent.add_child(node)


func _bake() -> void:
    if DisplayServer.get_name() == "headless":
        _fail("VoxelGI requires a rendering device. Run WITHOUT --headless on a GPU-equipped computer")
        return
    var hall := ROOM.instantiate() as Node3D
    if hall == null:
        _fail("Cannot instantiate main.tscn")
        return
    # Do not cut holes in the exit walls or create streaming connectors.
    # Those are temporary gameplay details, not bake-authoritative geometry.
    var gameplay := hall.get_node_or_null("LoopController")
    if gameplay != null:
        gameplay.free()
    var player := hall.get_node_or_null("Player")
    if player != null:
        player.free()
    hall.set_meta("_baking_room", true)
    root.add_child(hall)
    await process_frame
    await process_frame
    await process_frame

    var emitters := Node3D.new()
    emitters.name = "VoxelGIEmittersBakeOnly"
    hall.add_child(emitters)
    var warm := Color("#e8b76f")
    _emissive_proxy(emitters, "EastCoveGI", Vector3(5.58, 5.45, 4.6),
        Vector3(0.30, 0.30, 18.1), warm, 3.2)
    _emissive_proxy(emitters, "EntryCoveGI", Vector3(-5.58, 5.45, 7.0),
        Vector3(0.30, 0.30, 13.1), warm, 3.2)
    _emissive_proxy(emitters, "NorthCoveGI", Vector3(-26, 5.45, -12.58),
        Vector3(39.0, 0.35, 0.34), warm, 3.2)
    _emissive_proxy(emitters, "SouthCoveGI", Vector3(-26, 5.45, -0.50),
        Vector3(39.0, 0.35, 0.34), warm, 3.2)
    _emissive_proxy(emitters, "BarSignGI", Vector3(-2.33, 4.72, -12.15),
        Vector3(4.2, 0.38, 0.28), Color("#75d5dd"), 2.7)
    _emissive_proxy(emitters, "EntrySignGI", Vector3(0, 4.15, 13.50),
        Vector3(5.4, 0.38, 0.28), warm, 2.7)
    for mesh in hall.find_children("*", "MeshInstance3D", true, false):
        var instance := mesh as MeshInstance3D
        if instance.visible and instance.mesh != null \
                and instance.gi_mode != GeometryInstance3D.GI_MODE_DISABLED:
            instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
    for light in hall.find_children("*", "Light3D", true, false):
        configure_baked_light(light as Light3D)
    await process_frame

    var rig := hall.get_node_or_null("VoxelGIRig") as Node3D
    if rig == null:
        _fail("VoxelGIRig missing")
        return
    for name in OUTPUTS:
        var probe := rig.get_node_or_null(name) as VoxelGI
        if probe == null:
            _fail("VoxelGI volume missing: " + name)
            return
        probe.data = null
        probe.visible = true
        print("VoxelGI baking ", name, " size=", probe.size, " subdiv=", probe.subdiv)
        probe.bake(hall)
        if probe.data == null or probe.data.get_data_cells().is_empty() \
                or probe.data.get_octree_cells().is_empty():
            _fail("Baking produced no voxel data: " + name)
            return
        probe.data.interior = true
        probe.data.energy = 0.95
        probe.data.propagation = 0.45
        probe.data.use_two_bounces = true
        probe.data.bias = 0.70
        probe.data.normal_bias = 0.25
        var save_result := ResourceSaver.save(probe.data, str(OUTPUTS[name]))
        if save_result != OK:
            _fail("Could not write " + str(OUTPUTS[name]) + ": " + str(save_result))
            return
        print("Saved ", OUTPUTS[name], " cells=", probe.data.get_data_cells().size())
        probe.visible = false
        await process_frame
    print("Casino Anomaly VoxelGI OFFLINE BAKE PASS")
    hall.queue_free()
    quit(0)
