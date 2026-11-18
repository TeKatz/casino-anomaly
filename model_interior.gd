extends Node3D

# Placement layer for the CC0 Poly Haven assets in models/catalog.json.
# Each original glTF remains reusable; the existing walkable whitebox hall
# and its colliders are independent of this visual-detail pass.
# Geometry is normalized by its imported AABB to protect against differences
# in asset pivots and original Blender measurement units.

const RESOLUTION := "1k"

var placed_model_count: int = 0
var successful_model_ids: Dictionary = {}
var _scene_cache: Dictionary = {}

func _ready() -> void:
    call_deferred("_populate")

func _populate() -> void:
    var hall: Node3D = get_parent() as Node3D
    if hall == null:
        push_error("Poly Haven placement layer must be inside the casino hall")
        return
    var bar: Node3D = hall.get_node_or_null("CornerBar") as Node3D
    var decor: Node3D = hall.get_node_or_null("Decor") as Node3D
    if bar == null or decor == null:
        push_error("The room must exist before the Poly Haven models are positioned")
        return

    # Replace the primitive sphere-chain chandelier with the donated real model.
    var hero = _place("Chandelier_02", "MainChandelier", Vector3(-1.4, 4.18, -6.8), 1.55)
    if hero != null:
        for child in decor.get_children():
            if child.name.begins_with("Chandelier"):
                child.queue_free()
        _soft_light(Vector3(-1.4, 4.5, -6.8), 1.7, 8.5)

    for entry in [
        [Vector3(0.3, 4.48, 5.8), 1.28],
        [Vector3(-17.5, 4.47, -6.5), 1.25],
        [Vector3(-31.0, 4.47, -6.5), 1.25],
        [Vector3(-41.0, 4.47, -6.5), 1.25]
    ]:
        _place("Chandelier_01", "CeilingChandelier", entry[0], entry[1])
    # Low-cost real lighting is separate from the decorative geometry.
    for lamp in [
        Vector3(0.3, 4.4, 5.8),
        Vector3(-17.5, 4.4, -6.5),
        Vector3(-31.0, 4.4, -6.5),
        Vector3(-41.0, 4.4, -6.5)
    ]:
        _soft_light(lamp, 0.62, 7.5)

    # Import the vintage round stools in place of the former cylinders,
    # preserving the bar's collision, shape and comfortable approach paths.
    if _asset_available("bar_chair_round_01"):
        for child in bar.get_children():
            if child.name.begins_with("BarStoolSeat") or child.name.begins_with("BarStoolStem") \
                or child.name.begins_with("SideBarStool") or child.name.begins_with("SideStoolStem"):
                child.queue_free()
        for x in [-7.1, -5.45, -3.75, -2.05, -0.3, 1.48, 3.05]:
            _place("bar_chair_round_01", "CounterStool", Vector3(x, 0.005, -8.30), 0.75, 0.0, true)
        for z in [-5.02, -6.65, -8.10]:
            _place("bar_chair_round_01", "SideStool", Vector3(3.50, 0.005, z), 0.75, PI / 2.0, true)

    # Real grouped wine bottles, placed sparingly rather than repeated across
    # every shelf; the original placeholder bottles retain shelf density.
    for entry in [
        [Vector3(-6.0, 1.35, -9.42), 0.42],
        [Vector3(-3.0, 1.35, -9.42), 0.39],
        [Vector3(1.1, 1.35, -9.42), 0.40]
    ]:
        _place("wine_bottles_01", "BarWine", entry[0], entry[1])

    for entry in [
        [Vector3(-18.4, 0.49, -2.75), 0.48],
        [Vector3(-28.6, 0.49, -2.75), 0.46],
        [Vector3(-38.8, 0.49, -2.75), 0.48],
        [Vector3(-0.45, 1.35, -9.42), 0.46]
    ]:
        _place("brass_candleholders", "BrassCandles", entry[0], entry[1])

    # Statues get actual pedestals so their bases are not floating or sunken.
    for pos in [Vector3(-2.75, 0.005, 12.15), Vector3(-40.5, 0.005, -1.2)]:
        _pedestal(pos)
        _place("marble_bust_01", "MarbleBust", pos + Vector3(0, 1.02, 0), 0.87, 0.0, false)

    # South wall paintings, oriented toward the walking route.
    for x in [-17.4, -29.4, -40.7]:
        _place("fancy_picture_frame_01", "FramedPainting",
            Vector3(x, 2.65, -0.16), 1.22, PI, false, true)

    # A couple of unobtrusive security cameras. Retain a visible distinction
    # between architecture and movable anomaly targets for later gameplay.
    _place("security_camera_01", "EntranceSecurityCamera",
        Vector3(5.80, 4.75, 10.8), 0.42, -PI / 2.0)
    _place("security_camera_01", "WestSecurityCamera",
        Vector3(-44.7, 4.7, -12.64), 0.42, PI / 2.0)

    # Smaller service furnishings belong at the bar edge and never obstruct
    # the 3.14-meter-wide main carpet corridor.
    _place("CoffeeCart_01", "CoffeeServiceCart",
        Vector3(-8.5, 0.005, -1.05), 1.33, -PI / 2.0, true)
    _place("modern_wooden_cabinet", "BarServiceCabinet",
        Vector3(-5.95, 0.005, -11.72), 1.40, 0.0, true)

    print("Poly Haven 3D interior: ", placed_model_count, " model instances from ",
        successful_model_ids.size(), " source assets")

func _pedestal(pos: Vector3) -> void:
    var holder := StaticBody3D.new()
    holder.name = "BustPedestal"
    holder.position = pos + Vector3(0, 0.50, 0)
    var body := MeshInstance3D.new()
    body.name = "PolishedStonePedestal"
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.74, 1.0, 0.74)
    body.mesh = mesh
    var stone := StandardMaterial3D.new()
    stone.albedo_color = Color("#c9c7c1")
    stone.roughness = 0.40
    body.material_override = stone
    holder.add_child(body)
    var collision := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = mesh.size
    collision.shape = box_shape
    holder.add_child(collision)
    add_child(holder)

func _soft_light(pos: Vector3, power: float, reach: float) -> void:
    var lamp := OmniLight3D.new()
    lamp.name = "ChandelierWarmLight"
    lamp.position = pos
    lamp.light_color = Color("#f3c692")
    lamp.light_energy = power
    lamp.omni_range = reach
    lamp.shadow_enabled = false
    add_child(lamp)

func _asset_path(identifier: String) -> String:
    return "res://models/" + identifier + "/" + identifier + "_" + RESOLUTION + ".gltf"

func _asset_available(identifier: String) -> bool:
    return ResourceLoader.exists(_asset_path(identifier))

func _resource(identifier: String) -> PackedScene:
    if _scene_cache.has(identifier):
        return _scene_cache[identifier]
    var imported: PackedScene = load(_asset_path(identifier)) as PackedScene
    if imported == null:
        push_error("Missing or invalid Poly Haven model: " + identifier)
        return null
    _scene_cache[identifier] = imported
    return imported

func _bounds_for(model: Node3D) -> AABB:
    var found := false
    var result := AABB()
    for candidate in model.find_children("*", "MeshInstance3D", true, false):
        var mesh_node: MeshInstance3D = candidate as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue
        var relative: Transform3D = model.global_transform.affine_inverse() * mesh_node.global_transform
        var transformed: AABB = relative * mesh_node.get_aabb()
        if not found:
            result = transformed
            found = true
        else:
            result = result.merge(transformed)
    if not found:
        push_error("Poly Haven model has no mesh geometry: " + model.name)
    return result

func _place(identifier: String, label: String, anchor: Vector3,
        target_height: float, yaw: float = 0.0, add_collision: bool = false,
        wall_mount: bool = false) -> Node3D:
    var packed := _resource(identifier)
    if packed == null:
        return null

    var wrapper := Node3D.new()
    wrapper.name = label
    wrapper.position = anchor
    wrapper.rotation.y = yaw
    add_child(wrapper)

    var imported: Node3D = packed.instantiate() as Node3D
    if imported == null:
        wrapper.queue_free()
        push_error("Poly Haven glTF does not instantiate as Node3D: " + identifier)
        return null
    wrapper.add_child(imported)

    var bounds := _bounds_for(imported)
    if bounds.size.y <= 0.0001:
        wrapper.queue_free()
        push_error("Poly Haven model has invalid vertical bounds: " + identifier)
        return null

    # Most donor scenes use Blender-origin pivots. Normalize once, then
    # align the bottom to the requested supporting surface or wall center.
    var height_scale := target_height / bounds.size.y
    imported.scale = Vector3.ONE * height_scale
    imported.position = Vector3(
        -(bounds.position.x + bounds.size.x * 0.5) * height_scale,
        -bounds.position.y * height_scale,
        -(bounds.position.z + bounds.size.z * 0.5) * height_scale
    )
    if wall_mount:
        # Wall art should be centered around its mounting point, not its foot.
        imported.position.y -= target_height * 0.5

    if add_collision:
        var body := StaticBody3D.new()
        body.name = "ApproximateSolidBody"
        body.position = Vector3(0, target_height * 0.5, 0)
        var shape := CollisionShape3D.new()
        var cylinder := CylinderShape3D.new()
        cylinder.height = target_height
        cylinder.radius = 0.28 if target_height < 1.0 else 0.48
        shape.shape = cylinder
        body.add_child(shape)
        wrapper.add_child(body)

    placed_model_count += 1
    successful_model_ids[identifier] = true
    return wrapper
