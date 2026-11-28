extends SceneTree
## GPU-assisted offline bake of saved gameplay/casino/main.tscn. Run from a checked-out project using
## Godot 4.5.1 with a Vulkan/D3D12-capable display (NOT --headless):
## Godot_v4.5.1-stable_win64_console.exe --path . --script res://tools/bake_voxel_gi.gd
##
## Creates two external binary .res resources. Commit those files before
## releasing VoxelGI-enabled builds. Never run inside the gameplay loop.
const ROOM = preload("res://gameplay/casino/main.tscn")
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


# The editor-authored cove strips and neon sign frame segments are the
# authoritative source for baked emission. Mesh movement, rotation, scaling,
# size and emission color/intensity all follow the saved gameplay/casino/main.tscn.
const MIN_VOXEL_EMITTER_THICKNESS := 0.28
const EMITTER_SUFFIX := "BakeGI"


static func is_neon_bake_source(source: MeshInstance3D) -> bool:
    var name := str(source.name)
    return name.ends_with("Cove") or name.begins_with("EntrySign") \
            or name.begins_with("BarSign")


static func proxy_from_source(source: MeshInstance3D,
        parent: Node3D) -> MeshInstance3D:
    if source == null or not source.visible or not (source.mesh is BoxMesh):
        return null
    var original := source.material_override as StandardMaterial3D
    if original == null or not original.emission_enabled:
        return null
    var box := source.mesh as BoxMesh
    var thickness := MIN_VOXEL_EMITTER_THICKNESS
    var proxy := MeshInstance3D.new()
    proxy.name = str(source.name) + EMITTER_SUFFIX
    # Convert via global transforms so rotated/scaled/reparented authored
    # meshes still give the correct bake positions in the room's local space.
    proxy.transform = parent.global_transform.affine_inverse() * source.global_transform
    var mesh := BoxMesh.new()
    mesh.size = Vector3(
        maxf(box.size.x, thickness),
        maxf(box.size.y, thickness),
        maxf(box.size.z, thickness)
    )
    proxy.mesh = mesh
    var color := original.emission
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    # Match the original thick-proxy brightness without locking the baker
    # to hardcoded gold/cyan values; the artist's emission multiplier wins.
    var gain := 2.8 if str(source.name).ends_with("Cove") else 1.6
    material.emission_energy_multiplier = original.emission_energy_multiplier * gain
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    proxy.material_override = material
    proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    proxy.gi_mode = GeometryInstance3D.GI_MODE_STATIC
    parent.add_child(proxy)
    return proxy


static func add_editor_neon_proxies(hall: Node3D,
        proxy_parent: Node3D) -> int:
    var atmosphere := hall.get_node_or_null("CasinoAtmosphere") as Node3D
    if atmosphere == null:
        return 0
    var count := 0
    for child in atmosphere.get_children():
        var source := child as MeshInstance3D
        if source == null or not is_neon_bake_source(source):
            continue
        if proxy_from_source(source, proxy_parent) == null:
            continue
        # The actual strips are thinner than a voxel and would otherwise
        # be captured twice. This changes only the temporary bake copy.
        source.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        count += 1
    return count


func _bake() -> void:
    if DisplayServer.get_name() == "headless":
        _fail("VoxelGI requires a rendering device. Run WITHOUT --headless on a GPU-equipped computer")
        return
    var hall := ROOM.instantiate() as Node3D
    if hall == null:
        _fail("Cannot instantiate gameplay/casino/main.tscn")
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
    var proxy_count := add_editor_neon_proxies(hall, emitters)
    if proxy_count < 4:
        _fail("No usable editor neon source meshes (CasinoAtmosphere); cannot bake stale positions")
        return
    print("VoxelGI: ", proxy_count, " bake-only emitters from saved editor meshes")
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
