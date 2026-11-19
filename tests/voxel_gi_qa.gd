extends SceneTree
## A safe, no-GPU validation of the offline GI contract. The scene must
## stay playable WITHOUT binary data on a headless CI runner, while a
## correctly baked local game can enable both room-local volumes.
const ROOM = preload("res://main.tscn")
# Force compilation of the GPU-only bake script on headless CI, without
# actually invoking bake() on its dummy rendering backend.
const BAKE_SCRIPT = preload("res://tools/bake_voxel_gi.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("Casino VoxelGI QA: " + message)
    quit(1)


func _run() -> void:
    var settings = root.get_node_or_null("GameSettings")
    if settings == null:
        _fail("No settings singleton")
        return
    # Catch invalid Light3D property names even though CI cannot run
    # GPU-backed VoxelGI.bake(). This executes the same helper as the
    # developer-facing offline bake script.
    var test_light := OmniLight3D.new()
    BAKE_SCRIPT.configure_baked_light(test_light)
    if test_light.light_bake_mode != Light3D.BAKE_STATIC:
        test_light.free()
        _fail("VoxelGI baking must set light_bake_mode to BAKE_STATIC")
        return
    test_light.free()
    var previous: bool = bool(settings.get_option("voxel_gi"))
    settings.set_option("voxel_gi", true)
    var room := ROOM.instantiate() as Node3D
    root.add_child(room)
    await process_frame
    await process_frame
    await process_frame
    var rig := room.get_node_or_null("VoxelGIRig") as Node3D
    if rig == null:
        _fail("No authored room-local GI rig")
        return
    var main := rig.get_node_or_null("MainWingGI") as VoxelGI
    var west := rig.get_node_or_null("WestWingGI") as VoxelGI
    if main == null or west == null or main.subdiv != VoxelGI.SUBDIV_128 \
            or west.subdiv != VoxelGI.SUBDIV_128:
        _fail("Two correctly subdivided VoxelGI volumes required")
        return
    if main.size.x < 12.0 or main.size.z < 27.0 \
            or west.size.x < 40.0 or west.size.z < 13.0:
        _fail("VoxelGI regions do not cover the two casino wings")
        return
    var baked: bool = bool(rig.call("has_complete_bake"))
    if baked:
        if main.data == null or west.data == null or not main.visible \
                or not west.visible:
            _fail("Validated GI data must activate on the current room")
            return
    elif main.visible or west.visible:
        _fail("Unbaked GI must be disabled, not masquerade as working GI")
        return

    settings.set_option("voxel_gi", false)
    await process_frame
    if main.visible or west.visible:
        _fail("Switching VoxelGI off failed")
        return
    settings.set_option("voxel_gi", true)
    await process_frame
    if (main.visible or west.visible) != baked:
        _fail("VoxelGI toggle is not reflected in the scene")
        return

    var standby := ROOM.instantiate() as Node3D
    standby.set_meta("_streaming_standby", true)
    for child_name in ["Player", "LoopController"]:
        var child := standby.get_node_or_null(child_name)
        if child != null:
            child.free()
    root.add_child(standby)
    await process_frame
    await process_frame
    await process_frame
    var next_rig := standby.get_node_or_null("VoxelGIRig") as Node3D
    if next_rig == null:
        _fail("Preloaded room is missing its independent rig")
        return
    for child in next_rig.get_children():
        if child is VoxelGI and child.visible:
            _fail("Standby VoxelGI is active during preloading")
            return
    standby.remove_meta("_streaming_standby")
    next_rig.call("set_streaming_active", true)
    await process_frame
    for child in next_rig.get_children():
        if child is VoxelGI and child.visible != baked:
            _fail("Handoff did not restore valid VoxelGI data")
            return

    standby.queue_free()
    room.queue_free()
    await process_frame
    settings.set_option("voxel_gi", previous)
    print("Casino Anomaly VoxelGI bake and streaming contract QA PASS")
    quit(0)
