extends SceneTree
const Cache = preload("res://gameplay/runtime_asset_cache.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("Runtime cache QA: " + message)
    quit(1)

func _run() -> void:
    Cache.clear()
    var size := Vector3(2.0, 3.0, 4.0)
    var mesh := Cache.portal_mesh(size)
    var shape := Cache.portal_shape(size)
    if mesh != Cache.portal_mesh(size) or shape != Cache.portal_shape(size):
        _fail("Identical immutable portal resources were not reused")
        return
    if mesh == Cache.portal_mesh(Vector3.ONE) or shape == Cache.portal_shape(Vector3.ONE):
        _fail("Distinct dimensions share geometry")
        return
    var a := MeshInstance3D.new()
    var b := MeshInstance3D.new()
    a.mesh = mesh
    b.mesh = mesh
    a.material_override = StandardMaterial3D.new()
    if b.material_override != null or mesh.material != null:
        _fail("Portal material leaked to a different node")
        return
    a.free()
    b.free()
    var first := CollisionShape3D.new()
    var second := CollisionShape3D.new()
    first.shape = shape
    second.shape = shape
    first.disabled = true
    if second.disabled or (second.shape as BoxShape3D).size != size:
        _fail("Collision node state leaked")
        return
    first.free()
    second.free()
    var model := Node3D.new()
    var measure := func(_model: Node3D) -> AABB:
        return AABB(Vector3.ZERO, size)
    var bounds := Cache.imported_bounds("test/source|variant", model, measure)
    if bounds != Cache.imported_bounds("test/source|variant", model, measure) or Cache.counts()["bounds_computations"] != 1:
        _fail("Source bounds were not reused")
        return
    Cache.imported_bounds("test/source|other_variant", model, measure)
    model.free()
    if Cache.counts()["bounds_computations"] != 2:
        _fail("Different asset variants reused the same bounds")
        return
    if Cache.valid_gi(null) or Cache.valid_gi(VoxelGIData.new()):
        _fail("Invalid VoxelGI data accepted")
        return
    var dust := Cache.dust_mesh()
    if dust != Cache.dust_mesh() or not is_equal_approx(dust.radius, 0.007):
        _fail("Fixed dust resources were not reused")
        return
    for i in range(Cache.GEOMETRY_LIMIT * 3):
        var dimensions := Vector3(float(i + 1), 2.0, 3.0)
        Cache.portal_mesh(dimensions)
        Cache.portal_shape(dimensions)
    if Cache.counts()["meshes"] > Cache.GEOMETRY_LIMIT or Cache.counts()["shapes"] > Cache.GEOMETRY_LIMIT:
        _fail("Cache grew beyond its limit")
        return
    Cache.clear()
    if Cache.counts()["meshes"] != 0 or Cache.counts()["shapes"] != 0 or Cache.counts()["bounds"] != 0:
        _fail("Cache did not release retained references")
        return
    if mesh.size != size or shape.size != size:
        _fail("Clearing cache changed resources still in use")
        return
    print("Casino Anomaly runtime asset cache QA PASS")
    quit(0)
