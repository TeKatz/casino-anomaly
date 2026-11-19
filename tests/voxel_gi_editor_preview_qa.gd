extends SceneTree
## Real editor (@tool) smoke test: the preview must load the exact baked
## resources the live game uses, but never serialize extra nodes into main.tscn.
const ROOM = preload("res://main.tscn")

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
    if not rig.has_method("has_complete_bake") or not bool(rig.call("has_complete_bake")):
        _fail("Editor failed to load both validated binary baked GI assets")
        return
    for probe_name in ["MainWingGI", "WestWingGI"]:
        var probe := rig.get_node_or_null(probe_name) as VoxelGI
        if probe == null or not probe.visible or probe.data == null:
            _fail("Editor GI volume is not lit: " + probe_name)
            return
        if probe.data.get_octree_cells().is_empty() or probe.data.get_data_cells().is_empty():
            _fail("Editor GI volume loaded empty data: " + probe_name)
            return
    hall.queue_free()
    print("Casino VoxelGI editor preview QA PASS")
    quit(0)
