extends SceneTree
## Offline bake of saved, editable Backrooms geometry. Requires Forward+ GPU.
## Never writes the Casino wing resources or the authored scene.
const Targets = preload("res://addons/casino_model_preview/voxel_bake_targets.gd")
const SCENE_PATH := Targets.BACKROOMS_SCENE
const OUTPUT_PATH := Targets.BACKROOMS_OUTPUT
const PROBE_PATH := "Lighting/BackroomsVoxelGI"

func _initialize() -> void:
    call_deferred("_bake")

func _fail(message: String) -> void:
    push_error("Backrooms VoxelGI bake: " + message)
    quit(1)

## Disabled fixtures must remain dark even on renderers that collect hidden
## lights for baking. Other authored GI modes are left as the artist set them.
static func prepare_lights(scene: Node) -> void:
    for child in scene.find_children("*", "Light3D", true, false):
        var light := child as Light3D
        if not light.is_visible_in_tree():
            light.light_bake_mode = Light3D.BAKE_DISABLED

static func configure_data(baked: VoxelGIData, previous: VoxelGIData) -> void:
    if previous != null:
        baked.interior = previous.interior
        baked.energy = previous.energy
        baked.propagation = previous.propagation
        baked.use_two_bounces = previous.use_two_bounces
        baked.bias = previous.bias
        baked.normal_bias = previous.normal_bias
    else:
        baked.interior = true
        baked.energy = 0.18
        baked.propagation = 0.40
        baked.use_two_bounces = true
        baked.bias = 0.70
        baked.normal_bias = 0.25

func _bake() -> void:
    if DisplayServer.get_name() == "headless" or RenderingServer.get_rendering_device() == null:
        _fail("Forward+ GPU required; run WITHOUT --headless.")
        return
    var packed := load(SCENE_PATH) as PackedScene
    if packed == null:
        _fail("Cannot load " + SCENE_PATH)
        return
    var scene := packed.instantiate() as Node3D
    if scene == null:
        _fail("Cannot instantiate Backrooms")
        return
    var probe := scene.get_node_or_null(PROBE_PATH) as VoxelGI
    if probe == null or not probe.has_method("reload_baked_data"):
        scene.free()
        _fail("Missing " + PROBE_PATH + " or its external bake reload script")
        return
    root.add_child(scene)
    await process_frame
    await process_frame
    prepare_lights(scene)
    var previous := probe.data
    probe.data = null
    probe.visible = true
    await process_frame
    print("Backrooms VoxelGI baking: ", probe.size, " subdivisions=", probe.subdiv)
    probe.bake(scene)
    if probe.data == null or probe.data.get_data_cells().is_empty() or probe.data.get_octree_cells().is_empty():
        _fail("Baking produced no voxel cells; previous output was not touched.")
        return
    configure_data(probe.data, previous)
    # Save to a temporary resource first. Never replace a working bake with
    # an incomplete one, and never serialize the temporary scene.
    var temporary := "res://.godot/backrooms_voxel_gi.pending-" + str(OS.get_process_id()) + ".res"
    var result := ResourceSaver.save(probe.data, temporary)
    if result != OK:
        DirAccess.remove_absolute(temporary)
        _fail("Cannot save temporary bake: " + str(result))
        return
    var verified := ResourceLoader.load(temporary, "VoxelGIData", ResourceLoader.CACHE_MODE_IGNORE) as VoxelGIData
    if verified == null or verified.get_data_cells().is_empty() or verified.get_octree_cells().is_empty():
        DirAccess.remove_absolute(temporary)
        _fail("Saved bake failed validation")
        return
    result = DirAccess.rename_absolute(temporary, OUTPUT_PATH)
    if result != OK:
        DirAccess.remove_absolute(temporary)
        _fail("Cannot replace " + OUTPUT_PATH + ": " + str(result))
        return
    print("Saved ", OUTPUT_PATH, " cells=", verified.get_data_cells().size())
    print("Casino Anomaly Backrooms VoxelGI OFFLINE BAKE PASS")
    scene.queue_free()
    quit(0)
