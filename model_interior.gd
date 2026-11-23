extends Node3D

# Placement layer for the CC0 Poly Haven assets in models/catalog.json.
# Each original glTF remains reusable; the existing walkable whitebox hall
# and its colliders are independent of this visual-detail pass.
# Geometry is normalized by its imported AABB to protect against differences
# in asset pivots and original Blender measurement units.

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
    call_deferred("_populate")

func _populate() -> void:
    var populate_start_us := Time.get_ticks_usec()
    var hall: Node3D = get_parent() as Node3D
    if hall == null:
        push_error("Poly Haven placement layer must be inside the casino hall")
        return
    var bar: Node3D = hall.get_node_or_null("CornerBar") as Node3D
    var decor: Node3D = hall.get_node_or_null("Decor") as Node3D
    var lounge: Node3D = hall.get_node_or_null("Lounge") as Node3D
    if bar == null or decor == null or lounge == null:
        push_error("The room must exist before the Poly Haven models are positioned")
        return

    # Replace the primitive sphere-chain chandelier with the donated real model.
    var hero = _place("Chandelier_02", "MainChandelier", Vector3(-1.4, 4.18, -6.8), 1.55)
    if hero != null:
        for child in decor.get_children():
            if child.name.begins_with("Chandelier"):
                child.queue_free()
        _soft_light(Vector3(-1.4, 4.5, -6.8), 0.48, 6.3)

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
        _soft_light(lamp, 0.26, 5.8)

    # All ten bar stools come from the imported Poly Haven model only.
    # Keep front and side rows separated around the curved corner.
    if _asset_available("bar_chair_round_01"):
        for x in [-7.5, -6.05, -4.6, -3.15, -1.7, -0.25, 1.2]:
            var stool := _place("bar_chair_round_01", "CounterStool",
                Vector3(x + BAR_SHIFT_X, 0.005, -8.30), 1.03, 0.0, true)
            if stool != null:
                _stool_cushion(stool)
        for z in [-4.98, -6.55, -8.05]:
            var stool := _place("bar_chair_round_01", "SideStool",
                Vector3(3.45 + BAR_SHIFT_X, 0.005, z), 1.03, PI / 2.0, true)
            if stool != null:
                _stool_cushion(stool)

    # The bar's three shelves now use dedicated editor-selectable, fully
    # volumetric signature bottle scenes (see main.tscn). Do not layer the
    # previous wine cluster on top of these newly authored bottle assets.

    # This Poly Haven glTF contains THREE physically separate candleholders.
    # Select only the tall third variant; never put a complete trio on a
    # single coffee table again.
    for entry in [
        [Vector3(-18.4, 0.56, -2.75), 0.63],
        [Vector3(-38.8, 0.56, -2.75), 0.63],
        [Vector3(-0.45 + BAR_SHIFT_X, 1.35, -9.42), 0.68]
    ]:
        _place("brass_candleholders", "SingleBrassCandleholder",
            entry[0], entry[1], 0.0, false, false, "brass_candleholder_03")

    # A further 90-degree correction: the imported sofa's front axis
    # is different from the assumed one, leaving the previous row crosswise.
    # PI aligns each sofa length with the lounge wall again.
    # Replace all five primitive sofas and tables, never stack duplicates.
    for i in range(5):
        var x := -18.4 - float(i) * 5.1
        _place("sofa_02", "LoungeSofa",
            Vector3(x, 0.005, -1.14), 1.08, PI, true, false, "", 2.42)
        _place("round_wooden_table_01", "LoungeCoffeeTable",
            Vector3(x, 0.005, -2.75), 0.56, 0.0, true, false, "", 1.22)
    # The complete chessboard is deliberately unique; no repeated identical
    # board on every table. It has its own small reserved table.
    _place("chess_set", "LoungeChessSet",
        Vector3(-28.6, 0.565, -2.75), 0.19, 0.0, false, false, "", 0.70)
    # Two small animal sculptures mark distinct landmarks for future
    # anomaly spotting. Their plinths are away from the carpet corridor.
    _display_plinth(Vector3(-8.45, 0.005, -1.04), 0.62, 0.72)
    _place("concrete_cat_statue", "ConcreteCatDisplay",
        Vector3(-8.45, 0.625, -1.04), 0.49, PI, false, false, "", 0.58)
    _display_plinth(Vector3(-44.20, 0.005, -1.35), 0.74, 0.88)
    _place("horse_statue_01", "HorseStatueDisplay",
        Vector3(-44.20, 0.745, -1.35), 1.10, -PI / 2.0, false, false, "", 0.85)

    # Statues get actual pedestals so their bases are not floating or sunken.
    for pos in [Vector3(-2.75, 0.005, 12.15), Vector3(-40.5, 0.005, -1.2)]:
        _pedestal(pos)
        # Imported bust faces the side wall at yaw 0. A half turn faces into
        # the casino route at both locations.
        _place("marble_bust_01", "MarbleBust", pos + Vector3(0, 1.02, 0), 0.87, PI, false)

    # South wall paintings, oriented toward the walking route.
    for x in [-17.4, -29.4, -40.7]:
        _place("fancy_picture_frame_01", "FramedPainting",
            Vector3(x, 2.65, -0.16), 1.22, PI, false, true)

    # A couple of unobtrusive security cameras. Retain a visible distinction
    # between architecture and movable anomaly targets for later gameplay.
    _place("security_camera_01", "EntranceSecurityCamera",
        Vector3(5.80, 4.75, 10.8), 0.42, -PI / 2.0)
    # This particular glTF lens is oriented along its local +Z, not the
    # default -Z Camera3D forward vector. Aim diagonally from the far corner
    # toward the room center (+X, +Z), not toward the far wall.
    _place("security_camera_01", "WestSecurityCamera",
        Vector3(-44.7, 4.7, -12.64), 0.42, 1.25)

    # Smaller service furnishings belong at the bar edge and never obstruct
    # the 3.14-meter-wide main carpet corridor.
    # Park cart halfway between adjacent sofas, with its back close to the
    # panelled wall (inside face near z=0); keep its wheels and physics solid.
    _place("CoffeeCart_01", "CoffeeServiceCart",
        Vector3(-15.85, 0.005, -0.54), 1.33, PI, true)

    # The donor cabinet is a LOW WIDE sideboard (2.44 x 0.68 m originally).
    # Its old 1.4m normalization made it almost 5m wide and put it directly
    # on the floor. Restore credible dimensions and raise on a solid plinth.
    _cabinet_plinth(Vector3(-2.5 + BAR_SHIFT_X, 0.0, -12.03))
    _place("modern_wooden_cabinet", "BarServiceCabinet",
        Vector3(-2.5 + BAR_SHIFT_X, 0.245, -12.03), 1.02, 0.0, true)

    var elapsed_ms := float(Time.get_ticks_usec() - populate_start_us) / 1000.0
    if elapsed_ms >= 20.0 and hall.has_meta("_streaming_standby"):
        print("Casino deferred model placement: %.1f ms" % elapsed_ms)
    print("Poly Haven 3D interior: ", placed_model_count, " model instances from ",
        successful_model_ids.size(), " source assets")

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
    var pad := CylinderMesh.new()
    pad.top_radius = 0.32
    pad.bottom_radius = 0.32
    pad.height = 0.095
    pad.radial_segments = 24
    cushion.mesh = pad
    cushion.position = Vector3(0, 1.045, 0)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#793c49")
    material.roughness = 0.91
    cushion.material_override = material
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
        wall_mount: bool = false, mesh_variant: String = "",
        max_footprint: float = 0.0) -> Node3D:
    # The numbered nodes in main.tscn are the designer's source of truth.
    # Keep their saved transform (including scale); only the model geometry,
    # collision and decorative details are constructed during play.
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

    # An authored model without runtime collision already has its final
    # transform. Computing its mesh bounds would not change a single node,
    # yet repeated that full hierarchy walk for every streamed casino hall.
    if has_authored_model and not add_collision:
        # Preserve the exact same accounting as the full placement path:
        # gameplay diagnostics and the headless scene smoke test rely on it.
        placed_model_count += 1
        successful_model_ids[identifier] = true
        return wrapper

    var bounds := _bounds_for(imported)
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

    if add_collision:
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
