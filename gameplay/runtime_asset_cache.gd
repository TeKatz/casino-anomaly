@tool
extends RefCounted
## Runtime-only bounded cache. Never store Nodes, mutable anomaly materials,
## authored instance transforms or editor previews. Eviction releases our
## reference, not resources still owned by a live scene.
const SCENE_LIMIT := 32
const GEOMETRY_LIMIT := 128
const VALIDATION_LIMIT := 16

static var _scenes: Dictionary = {}
static var _bounds: Dictionary = {}
static var _boxes: Dictionary = {}
static var _shapes: Dictionary = {}
static var _validated_gi: Dictionary = {}
static var _dust: SphereMesh
static var bounds_computations := 0
static var gi_validations := 0

static func _remember(cache: Dictionary, key: Variant, value: Variant, limit: int) -> void:
    if not cache.has(key) and cache.size() >= limit:
        cache.erase(cache.keys()[0])
    cache[key] = value

static func packed_scene(path: String) -> PackedScene:
    if not Engine.is_editor_hint() and _scenes.has(path):
        return _scenes[path] as PackedScene
    var packed := ResourceLoader.load(path) as PackedScene
    if packed != null and not Engine.is_editor_hint():
        _remember(_scenes, path, packed, SCENE_LIMIT)
    return packed

static func imported_bounds(key: String, model: Node3D, calculate: Callable) -> AABB:
    # Only callers with newly instantiated, unmodified source assets may use
    # this API. Authored model overrides must always measure their own meshes.
    if not Engine.is_editor_hint() and _bounds.has(key):
        return _bounds[key]
    var bounds: AABB = calculate.call(model)
    if not Engine.is_editor_hint():
        bounds_computations += 1
        if bounds.size.y > 0.0001 and maxf(bounds.size.x, bounds.size.z) > 0.0001:
            _remember(_bounds, key, bounds, GEOMETRY_LIMIT)
    return bounds

static func portal_mesh(dimensions: Vector3) -> BoxMesh:
    if not Engine.is_editor_hint() and _boxes.has(dimensions):
        return _boxes[dimensions] as BoxMesh
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    # Portal materials are node-local overrides, never assigned to this mesh.
    if not Engine.is_editor_hint():
        _remember(_boxes, dimensions, mesh, GEOMETRY_LIMIT)
    return mesh

static func portal_shape(dimensions: Vector3) -> BoxShape3D:
    if not Engine.is_editor_hint() and _shapes.has(dimensions):
        return _shapes[dimensions] as BoxShape3D
    var shape := BoxShape3D.new()
    shape.size = dimensions
    # Only immutable geometry is shared. CollisionShape3D.disabled and
    # StaticBody3D collision layers remain per-node.
    if not Engine.is_editor_hint():
        _remember(_shapes, dimensions, shape, GEOMETRY_LIMIT)
    return shape

static func valid_gi(data: VoxelGIData) -> bool:
    if data == null:
        return false
    var id := data.get_instance_id()
    if not Engine.is_editor_hint() and _validated_gi.has(id):
        var previous: WeakRef = _validated_gi[id]
        if previous.get_ref() == data:
            return true
        _validated_gi.erase(id)
    var valid := not data.get_octree_cells().is_empty() and not data.get_data_cells().is_empty()
    if not Engine.is_editor_hint():
        gi_validations += 1
        if valid:
            _remember(_validated_gi, id, weakref(data), VALIDATION_LIMIT)
    return valid

static func dust_mesh() -> SphereMesh:
    if not Engine.is_editor_hint() and _dust != null:
        return _dust
    var mesh := SphereMesh.new()
    mesh.radius = 0.007
    mesh.height = 0.014
    mesh.radial_segments = 6
    mesh.rings = 4
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.96, 0.86, 0.74, 0.22)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.material = mat
    # Fixed, non-anomaly dust material. Per-emitter settings stay independent.
    if not Engine.is_editor_hint():
        _dust = mesh
    return mesh

static func counts() -> Dictionary:
    return {"scenes": _scenes.size(), "bounds": _bounds.size(), "meshes": _boxes.size(),
        "shapes": _shapes.size(), "gi": _validated_gi.size(),
        "bounds_computations": bounds_computations, "gi_validations": gi_validations}

static func clear() -> void:
    _scenes.clear()
    _bounds.clear()
    _boxes.clear()
    _shapes.clear()
    _validated_gi.clear()
    _dust = null
    bounds_computations = 0
    gi_validations = 0
