extends SceneTree
## Smoke test of the editor (@tool) GI rig. The CI runner uses --headless,
## so its Dummy renderer cannot expose baked VoxelGI octree cells or light
## a probe. Verify the saved resources independently and assert the actual
## lit-preview state only on GPU renderers.
const ROOM = preload("res://main.tscn")
const BAKES := {
    "MainWingGI": "res://lighting/main_wing.res",
    "WestWingGI": "res://lighting/west_wing.res"
}

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("Casino VoxelGI editor preview QA: " + reason)
    quit(1)

func _run() -> void:
    if not Engine.is_editor_hint():
        _fail("This regression must execute with --editor")
        return
    var hall := ROOM.instantiate() as Node3D
    if hall == null:
        _fail("Unable to instantiate casino hall")
        return
    root.add_child(hall)
    for i in range(8):
        await process_frame

    var rig := hall.get_node_or_null("VoxelGIRig") as Node3D
    if rig == null:
        _fail("@tool hall did not create an editor VoxelGI rig")
        return
    if rig.owner != null:
        _fail("Transient editor GI preview must not be scene-owned")
        return

    var headless := DisplayServer.get_name() == "headless"
    for probe_name in BAKES:
        var probe := rig.get_node_or_null(probe_name) as VoxelGI
        if probe == null or probe.subdiv != VoxelGI.SUBDIV_128:
            _fail("Editor GI volume missing or has wrong subdivisions: " + probe_name)
            return
        var path: String = str(BAKES[probe_name])
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null or file.get_length() < 1024:
            _fail("Missing or empty committed VoxelGI bake: " + path)
            return
        file.close()
        var baked := load(path) as VoxelGIData
        if baked == null or baked.get_bounds().size.length_squared() <= 0.0:
            _fail("Baked resource could not be loaded as VoxelGIData: " + path)
            return
        if not headless:
            if not probe.visible or probe.data == null:
                _fail("GPU editor GI volume is not visible: " + probe_name)
                return
            if probe.data.get_octree_cells().is_empty() or probe.data.get_data_cells().is_empty():
                _fail("GPU editor GI volume contains no baked voxel cells: " + probe_name)
                return

    if not headless and not bool(rig.call("has_complete_bake")):
        _fail("GPU editor did not activate the validated VoxelGI data")
        return
    if headless:
        print("Casino VoxelGI editor preview QA: Dummy renderer, checked resources and transient volume structure; GPU-only lighting validation skipped")
    hall.queue_free()
    print("Casino VoxelGI editor preview QA PASS")
    quit(0)
