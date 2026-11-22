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
    # The offline baker must track actual edited neon transforms, scales
    # and materials, not fixed legacy coordinates. This runs without a GPU.
    var baker_fixture := ROOM.instantiate() as Node3D
    baker_fixture.set_meta("_baking_room", true)
    for name in ["Player", "LoopController"]:
        var obsolete := baker_fixture.get_node_or_null(name)
        if obsolete != null:
            obsolete.free()
    root.add_child(baker_fixture)
    await process_frame
    var emitters := Node3D.new()
    emitters.name = "BakeProxyFixture"
    baker_fixture.add_child(emitters)
    var count: int = BAKE_SCRIPT.add_editor_neon_proxies(baker_fixture, emitters)
    if count < 10 or emitters.get_child_count() != count:
        _fail("Offline baker did not build all authored neon cove/sign strips")
        return
    var bar := baker_fixture.get_node_or_null("CasinoAtmosphere/BarSignTop") as MeshInstance3D
    var proxy := emitters.get_node_or_null("BarSignTopBakeGI") as MeshInstance3D
    if bar == null or proxy == null:
        _fail("Baker omitted the authored MIDNIGHT BAR sign")
        return
    if bar.gi_mode != GeometryInstance3D.GI_MODE_DISABLED:
        _fail("Thin sign is still double-contributing alongside its proxy")
        return
    var expected := emitters.global_transform.affine_inverse() * bar.global_transform
    if not proxy.transform.is_equal_approx(expected):
        _fail("Baked sign transform does not match the editor-authored scene")
        return
    var proxy_mesh := proxy.mesh as BoxMesh
    if proxy_mesh == null or proxy_mesh.size.z < BAKE_SCRIPT.MIN_VOXEL_EMITTER_THICKNESS:
        _fail("Baked emitter proxy is too thin for SUBDIV_128")
        return
    # Simulate a real user moving the sign in Godot: a new bake must follow.
    bar.position += Vector3(0.7, 0.14, -0.3)
    bar.rotation.y += 0.19
    var shifted := BAKE_SCRIPT.proxy_from_source(bar, emitters) as MeshInstance3D
    expected = emitters.global_transform.affine_inverse() * bar.global_transform
    if shifted == null or not shifted.transform.is_equal_approx(expected):
        _fail("Edited neon transform was not transferred to the bake proxy")
        return
    var authored := bar.material_override as StandardMaterial3D
    var replica := shifted.material_override as StandardMaterial3D
    if authored == null or replica == null \
            or not replica.emission.is_equal_approx(authored.emission):
        _fail("The bake proxy lost its edited neon emission color")
        return
    baker_fixture.queue_free()
    await process_frame

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
    # Being tagged as standby prevents the second player and costly
    # reflection captures, but must NOT prevent the renderer from
    # prewarming already-loaded baked GI while the next hall is still hidden.
    next_rig.call("set_streaming_active", true)
    await process_frame
    if not standby.has_meta("_streaming_standby") or not bool(next_rig.get("streaming_active")):
        _fail("GI prewarm discarded standby safeguards")
        return
    for child in next_rig.get_children():
        if child is VoxelGI and child.visible != baked:
            _fail("Prewarmed GI failed to illuminate a still-hidden next room")
            return

    # The room handoff must not toggle the probes and create a bright/dark
    # first frame when the casino is finally visible through the entrance.
    standby.remove_meta("_streaming_standby")
    next_rig.call("set_streaming_active", true)
    await process_frame
    for child in next_rig.get_children():
        if child is VoxelGI and child.visible != baked:
            _fail("Handoff interrupted already-prewarmed VoxelGI")
            return

    standby.queue_free()
    room.queue_free()
    await process_frame
    settings.set_option("voxel_gi", previous)
    print("Casino Anomaly VoxelGI bake and streaming contract QA PASS")
    quit(0)
