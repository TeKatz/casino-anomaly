extends Node3D
const StreamingTrace = preload("res://gameplay/streaming_trace.gd")

# Placement layer for the CC0 Poly Haven assets in models/catalog.json.
# Each original glTF remains reusable; the existing walkable whitebox hall
# and its colliders are independent of this visual-detail pass.
# Geometry is normalized by its imported AABB to protect against differences
# in asset pivots and original Blender measurement units.

const RuntimeCache = preload("res://gameplay/runtime_asset_cache.gd")
const RESOLUTION := "1k"
const BAR_SHIFT_X := -0.95

var placed_model_count: int = 0
var successful_model_ids: Dictionary = {}
var _scene_cache: Dictionary = {}
var _placement_indices: Dictionary = {}
var _statue_plinth_index := 0
var _bust_pedestal_index := 0
var _chandelier_light_index := 0

func _has_authored_room_layout() -> bool:
    # The 3D scene baker made the scene, not these scripts, authoritative.
    # A missing fixture in that scene was removed by the level designer.
    # In a legacy procedural room, missing fixtures are still generated.
    var hall := get_parent() as Node3D
    if hall == null:
        return false
    var floor := hall.get_node_or_null("Architecture/OakMainWing")
    return floor != null and floor.owner == hall

func _ready() -> void:
    if get_parent().has_meta("_streaming_assembly"):
        return
    initialize_room_section()

func initialize_room_section(incremental: bool = false) -> void:
    if incremental:
        begin_streaming_population()
    else:
        call_deferred("_populate")

var _population_jobs: Array[Callable] = []
var _population_cursor := 0
var _population_started := false
var _population_done := false

func _populate() -> void:
    begin_streaming_population()
    advance_streaming_population(true)

func begin_streaming_population() -> void:
    if _population_started:
        return
    _population_started = true
    var hall := get_parent() as Node3D
    if hall == null:
        push_error("Poly Haven placement layer must be inside the casino hall")
        _population_done = true
        return
    var decor := hall.get_node_or_null("Decor") as Node3D
    if hall.get_node_or_null("CornerBar") == null or decor == null or hall.get_node_or_null("Lounge") == null:
        push_error("The room must exist before the Poly Haven models are positioned")
        _population_done = true
        return

    _population_jobs.append(_populate_hero.bind(decor))
    for entry in [[Vector3(0.3, 4.48, 5.8), 1.28],
            [Vector3(-17.5, 4.47, -6.5), 1.25],
            [Vector3(-31.0, 4.47, -6.5), 1.25],
            [Vector3(-41.0, 4.47, -6.5), 1.25]]:
        _population_jobs.append(_place.bind("Chandelier_01", "CeilingChandelier", entry[0], entry[1]))
    for lamp in [Vector3(0.3, 4.4, 5.8), Vector3(-17.5, 4.4, -6.5),
            Vector3(-31.0, 4.4, -6.5), Vector3(-41.0, 4.4, -6.5)]:
        _population_jobs.append(_soft_light.bind(lamp, 0.26, 5.8))
    if _asset_available("bar_chair_round_01"):
        for x in [-7.5, -6.05, -4.6, -3.15, -1.7, -0.25, 1.2]:
            _population_jobs.append(_populate_stool.bind("CounterStool", Vector3(x + BAR_SHIFT_X, 0.005, -8.30), 0.0))
        for z in [-4.98, -6.55, -8.05]:
            _population_jobs.append(_populate_stool.bind("SideStool", Vector3(3.45 + BAR_SHIFT_X, 0.005, z), PI / 2.0))
    for entry in [[Vector3(-18.4, 0.56, -2.75), 0.63],
            [Vector3(-38.8, 0.56, -2.75), 0.63],
            [Vector3(-0.45 + BAR_SHIFT_X, 1.35, -9.42), 0.68]]:
        _population_jobs.append(_place.bind("brass_candleholders", "SingleBrassCandleholder",
            entry[0], entry[1], 0.0, false, false, "brass_candleholder_03"))
    for i in range(5):
        var x := -18.4 - float(i) * 5.1
        _population_jobs.append(_place.bind("sofa_02", "LoungeSofa",
            Vector3(x, 0.005, -1.14), 1.08, PI, true, false, "", 2.42))
        _population_jobs.append(_place.bind("round_wooden_table_01", "LoungeCoffeeTable",
            Vector3(x, 0.005, -2.75), 0.56, 0.0, true, false, "", 1.22))
    _population_jobs.append(_place.bind("chess_set", "LoungeChessSet",
        Vector3(-28.6, 0.565, -2.75), 0.19, 0.0, false, false, "", 0.70))
    _population_jobs.append(_display_plinth.bind(Vector3(-8.45, 0.005, -1.04), 0.62, 0.72))
    _population_jobs.append(_place.bind("concrete_cat_statue", "ConcreteCatDisplay",
        Vector3(-8.45, 0.625, -1.04), 0.49, PI, false, false, "", 0.58))
    _population_jobs.append(_display_plinth.bind(Vector3(-44.20, 0.005, -1.35), 0.74, 0.88))
    _population_jobs.append(_place.bind("horse_statue_01", "HorseStatueDisplay",
        Vector3(-44.20, 0.745, -1.35), 1.10, -PI / 2.0, false, false, "", 0.85))
    for pos in [Vector3(-2.75, 0.005, 12.15), Vector3(-40.5, 0.005, -1.2)]:
        _population_jobs.append(_pedestal.bind(pos))
        _population_jobs.append(_place.bind("marble_bust_01", "MarbleBust", pos + Vector3(0, 1.02, 0), 0.87, PI, false))
    for x in [-17.4, -29.4, -40.7]:
        _population_jobs.append(_place.bind("fancy_picture_frame_01", "FramedPainting",
            Vector3(x, 2.65, -0.16), 1.22, PI, false, true))
    _population_jobs.append(_place.bind("security_camera_01", "EntranceSecurityCamera",
        Vector3(5.80, 4.75, 10.8), 0.42, -PI / 2.0))
    _population_jobs.append(_place.bind("security_camera_01", "WestSecurityCamera",
        Vector3(-44.7, 4.7, -12.64), 0.42, 1.25))
    _population_jobs.append(_place.bind("CoffeeCart_01", "CoffeeServiceCart",
        Vector3(-15.85, 0.005, -0.54), 1.33, PI, true))
    _population_jobs.append(_cabinet_plinth.bind(Vector3(-2.5 + BAR_SHIFT_X, 0.0, -12.03)))
    _population_jobs.append(_place.bind("modern_wooden_cabinet", "BarServiceCabinet",
        Vector3(-2.5 + BAR_SHIFT_X, 0.245, -12.03), 1.02, 0.0, true))

func advance_streaming_population(immediate: bool = false) -> bool:
    if _population_done:
        return true
    if not _population_started:
        begin_streaming_population()
    var started := Time.get_ticks_usec()
    var trace_start := StreamingTrace.begin()
    var count := 0
    while _population_cursor < _population_jobs.size():
        _population_jobs[_population_cursor].call()
        _population_cursor += 1
        count += 1
        if not immediate and (count >= 4 or Time.get_ticks_usec() - started >= 2500):
            break
    StreamingTrace.finish("models.populate_batch", trace_start)
    if _population_cursor < _population_jobs.size():
        return false
    _population_jobs.clear()
    _population_done = true
    print("Poly Haven 3D interior: ", placed_model_count, " model instances from ",
        successful_model_ids.size(), " source assets")
    return true

func _populate_hero(decor: Node3D) -> void:
    var hero := _place("Chandelier_02", "MainChandelier", Vector3(-1.4, 4.18, -6.8), 1.55)
    if hero != null:
        for child in decor.get_children():
            if child.name.begins_with("Chandelier"):
                child.queue_free()
        _soft_light(Vector3(-1.4, 4.5, -6.8), 0.48, 6.3)

func _populate_stool(label: String, position_in_room: Vector3, yaw: float) -> void:
    var stool := _place("bar_chair_round_01", label, position_in_room, 1.03, yaw, true)
    if stool != null:
        _stool_cushion(stool)

func _display_plinth(ground: Vector3, height: float, width: float) -> void:
    _statue_plinth_index += 1
    var stable_name := "DecorativeStatuePlinth_%02d" % _statue_plinth_index
    if has_node(stable_name) or _has_authored_room_layout():
        return # Never regenerate artist-deleted plinths in the authored room.
    var body := StaticBody3D.new()
    body.name = stable_name
    body.position = ground + Vector3(0, height * 0.5, 0)
    var surface := MeshInstance3D.new()
    surface.name = "StonePlinthMesh"
    var cube := BoxMesh.new()
    cube.size = Vector3(width, height, width)
    surface.mesh = cube
    var stone_mat := StandardMaterial3D.new()
    stone_mat.albedo_color = Color("#aaa8a2")
    stone_mat.roughness = 0.60
    surface.material_override = stone_mat
    body.add_child(surface)
    var collision := CollisionShape3D.new()
    collision.name = "PlinthCollision"
    var shape := BoxShape3D.new()
    shape.size = cube.size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)


func _stool_cushion(stool: Node3D) -> void:
    # The original mesh has a hard wooden seat. Provide uniform upholstery
    # on EVERY stool, including the two end stools.
    var cushion := MeshInstance3D.new()
    cushion.name = "VelvetSeatCushion"
    # Shared render resources permit Forward+ automatic instancing;
    # individual stools and their anomaly transforms remain independent.
    cushion.mesh = RuntimeCache.stool_cushion_mesh()
    cushion.position = Vector3(0, 1.045, 0)
    cushion.material_override = RuntimeCache.stool_cushion_material()
    stool.add_child(cushion)


func _cabinet_plinth(ground: Vector3) -> void:
    if has_node("BarCabinetPlinth") or _has_authored_room_layout():
        return
    var plinth := StaticBody3D.new()
    plinth.name = "BarCabinetPlinth"
    plinth.position = ground + Vector3(0, 0.12, 0)
    var mesh := MeshInstance3D.new()
    mesh.name = "CabinetPolishedWoodBase"
    var box := BoxMesh.new()
    box.size = Vector3(3.78, 0.24, 0.93)
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#302017")
    mat.roughness = 0.66
    mesh.material_override = mat
    plinth.add_child(mesh)
    var shape := CollisionShape3D.new()
    var collision := BoxShape3D.new()
    collision.size = box.size
    shape.shape = collision
    plinth.add_child(shape)
    add_child(plinth)


func _pedestal(pos: Vector3) -> void:
    _bust_pedestal_index += 1
    var stable_name := "BustPedestal_%02d" % _bust_pedestal_index
    if has_node(stable_name) or _has_authored_room_layout():
        return
    var holder := StaticBody3D.new()
    holder.name = stable_name
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
    collision.name = "BustPedestalCollision"
    var box_shape := BoxShape3D.new()
    box_shape.size = mesh.size
    collision.shape = box_shape
    holder.add_child(collision)
    add_child(holder)

func _soft_light(pos: Vector3, power: float, reach: float) -> void:
    _chandelier_light_index += 1
    var stable_name := "ChandelierWarmLight_%02d" % _chandelier_light_index
    if has_node(stable_name) or _has_authored_room_layout():
        return
    var lamp := OmniLight3D.new()
    lamp.name = stable_name
    lamp.position = pos
    lamp.light_color = Color("#f3c692")
    lamp.light_energy = power * 0.85
    lamp.omni_range = minf(reach, 6.6)
    lamp.light_specular = 0.9
    lamp.light_volumetric_fog_energy = 0.18
    # The eight structural ceiling lights already cast the shadows.
    # Keep these imported chandelier highlights faint and local so their
    # unshadowed contribution doesn't flatten the room's contrast.
    lamp.shadow_enabled = false
    lamp.light_volumetric_fog_energy = 0.12
    add_child(lamp)

func _asset_path(identifier: String) -> String:
    return "res://models/" + identifier + "/" + identifier + "_" + RESOLUTION + ".gltf"

func _asset_available(identifier: String) -> bool:
    return ResourceLoader.exists(_asset_path(identifier))

func _resource(identifier: String) -> PackedScene:
    if _scene_cache.has(identifier):
        return _scene_cache[identifier]
    var imported: PackedScene = RuntimeCache.packed_scene(_asset_path(identifier))
    if imported == null:
        push_error("Missing or invalid Poly Haven model: " + identifier)
        return null
    _scene_cache[identifier] = imported
    return imported

func _bounds_for(model: Node3D) -> AABB:
    var found := false
    var result := AABB()
    var inverse := model.global_transform.affine_inverse()
    for candidate in model.find_children("*", "MeshInstance3D", true, false):
        var mesh_node: MeshInstance3D = candidate as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue
        var relative: Transform3D = inverse * mesh_node.global_transform
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
        wall_mount: bool = false, mesh_variant: String = "",
        max_footprint: float = 0.0) -> Node3D:
    # The numbered nodes in main.tscn are the designer's source of truth.
    # Keep their saved transform (including scale); only the model geometry,
    # collision and decorative details are constructed during play.
    # The visual-only menu does not need runtime model colliders.
    var needs_collision := add_collision and not get_parent().has_meta("_menu_showcase")
    var index: int = int(_placement_indices.get(label, 0)) + 1
    _placement_indices[label] = index
    var saved_name := "%s_%02d" % [label, index]
    var wrapper := get_node_or_null(saved_name) as Node3D
    var generated := wrapper == null
    if generated:
        wrapper = Node3D.new()
        wrapper.name = label
        wrapper.position = anchor
        wrapper.rotation.y = yaw
        add_child(wrapper)
    wrapper.set_meta("asset_id", identifier)
    wrapper.set_meta("placement_group", label)

    # The authored glTF remains in the scene after the editor bake. Reuse it,
    # including the designer's saved scale and rotation; no runtime duplicate.
    var imported := wrapper.get_node_or_null("EditableImportedModel") as Node3D
    var has_authored_model := imported != null
    if not has_authored_model:
        var packed := _resource(identifier)
        if packed == null:
            if generated:
                wrapper.queue_free()
            return null
        imported = packed.instantiate() as Node3D
        if imported == null:
            if generated:
                wrapper.queue_free()
            push_error("Poly Haven glTF does not instantiate as Node3D: " + identifier)
            return null
        wrapper.add_child(imported)

    # A saved, editable glTF instance still contains every source mesh.
    # Apply the same variant filtering to both authored and generated models.
    # This only removes unused meshes from the runtime instance; it does
    # not rewrite main.tscn or the imported source scene.
    if not mesh_variant.is_empty():
        var variant_found := false
        for candidate in imported.find_children("*", "MeshInstance3D", true, false):
            var mesh_node: MeshInstance3D = candidate as MeshInstance3D
            if mesh_node.name.begins_with(mesh_variant):
                variant_found = true
            else:
                var node_parent: Node = mesh_node.get_parent()
                node_parent.remove_child(mesh_node)
                mesh_node.free()
        if not variant_found:
            if generated:
                wrapper.queue_free()
            push_error("Requested candleholder variant is missing: " + mesh_variant)
            return null

    RuntimeCache.stabilize_imported_model(imported)

    # An authored model without runtime collision already has its final
    # transform. Computing its mesh bounds would not change a single node,
    # yet repeated that full hierarchy walk for every streamed casino hall.
    if has_authored_model and not needs_collision:
        # Preserve the exact same accounting as the full placement path:
        # gameplay diagnostics and the headless scene smoke test rely on it.
        placed_model_count += 1
        successful_model_ids[identifier] = true
        return wrapper

    var bounds := _bounds_for(imported) if has_authored_model else RuntimeCache.imported_bounds(_asset_path(identifier) + "|" + mesh_variant, imported, _bounds_for)
    if bounds.size.y <= 0.0001:
        if generated:
            wrapper.queue_free()
        push_error("Poly Haven model has invalid vertical bounds: " + identifier)
        return null

    # Most donor scenes use Blender-origin pivots. Normalize once, then
    # align the bottom to the requested supporting surface or wall center.
    var height_scale := target_height / bounds.size.y
    if max_footprint > 0.0:
        height_scale = minf(height_scale,
            max_footprint / maxf(bounds.size.x, bounds.size.z))
    if not has_authored_model:
        imported.scale = Vector3.ONE * height_scale
        imported.position = Vector3(
            -(bounds.position.x + bounds.size.x * 0.5) * height_scale,
            -bounds.position.y * height_scale,
            -(bounds.position.z + bounds.size.z * 0.5) * height_scale
        )
        if wall_mount:
            # Wall art should be centered around its mounting point, not its foot.
            imported.position.y -= target_height * 0.5

    if needs_collision:
        # Use actual imported geometry extents, rather than a tiny cylinder
        # which allowed the player to walk through most of the sideboard.
        var body := StaticBody3D.new()
        body.name = "ModelSolidBody"
        var solid_bounds := AABB(
            Vector3(-bounds.size.x * height_scale * 0.5, 0.0,
                -bounds.size.z * height_scale * 0.5),
            bounds.size * height_scale)
        if has_authored_model:
            solid_bounds = imported.transform * bounds
        body.position = solid_bounds.get_center()
        var shape := CollisionShape3D.new()
        shape.name = "ModelCollisionShape"
        var collision := BoxShape3D.new()
        collision.size = Vector3(
            maxf(solid_bounds.size.x, 0.23),
            maxf(solid_bounds.size.y, 0.23),
            maxf(solid_bounds.size.z, 0.23)
        )
        shape.shape = collision
        body.add_child(shape)
        wrapper.add_child(body)

    placed_model_count += 1
    successful_model_ids[identifier] = true
    return wrapper
