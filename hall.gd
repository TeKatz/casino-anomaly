@tool
extends Node3D

# First room-design pass. Everything is intentionally modular so assets may replace
# the whitebox furniture later without rebuilding the room or its collision layout.
const SLOT_CABINET = preload("res://models/casino_furniture/heritage_slot_cabinet.tscn")
const GAME_TABLE_STOOL = preload("res://models/casino_furniture/gaming_stool.tscn")
const GAME_TABLE_SURFACE = preload("res://models/casino_furniture/detailed_table_surface.tscn")
const OAK: StandardMaterial3D = preload("res://floor_material.tres")
const VoxelRig = preload("res://lighting/voxel_gi_rig.gd")
const RoomSoundscape = preload("res://gameplay/room_soundscape.gd")
const NeonLevelSign = preload("res://gameplay/neon_level_sign.gd")
const JACQUARD: StandardMaterial3D = preload("res://carpet_material.tres")
const LOWER_WALL: StandardMaterial3D = preload("res://lower_wall_material.tres")
const UPPER_WALL: StandardMaterial3D = preload("res://upper_wall_material.tres")
const ROOF_PLANKS: StandardMaterial3D = preload("res://ceiling_material.tres")
const BAR_COUNTER_WOOD: StandardMaterial3D = preload("res://bar_top_material.tres")
const BAR_PANEL_WOOD: StandardMaterial3D = preload("res://bar_side_material.tres")
const PILLAR_VENEER: StandardMaterial3D = preload("res://pillar_material.tres")
const BEAM_TIMBER: StandardMaterial3D = preload("res://brown_planks_05_material.tres")
const PARQUET_EDGE: StandardMaterial3D = preload("res://herringbone_parquet_material.tres")
const GOLD_FABRIC: StandardMaterial3D = preload("res://bi_stretch_material.tres")
const FLOOR_Y := 0.035
const WALL_HEIGHT := 6.0

var wood: StandardMaterial3D
var fabric: StandardMaterial3D
var wall_paint: StandardMaterial3D
var wall_panel: StandardMaterial3D
var dark_wood: StandardMaterial3D
var gold: StandardMaterial3D
var brass: StandardMaterial3D
var velvet: StandardMaterial3D
var green_felt: StandardMaterial3D
var screen_black: StandardMaterial3D
var stone: StandardMaterial3D
var pillar_wood: StandardMaterial3D
var dark_ceiling: StandardMaterial3D
var beam_wood: StandardMaterial3D
var parquet_border: StandardMaterial3D
var fabric_piping: StandardMaterial3D
var warm_white: StandardMaterial3D
var red_light: StandardMaterial3D

var architecture: Node3D
var carpeting: Node3D
var machines: Node3D
var gaming: Node3D
var bar_area: Node3D
var lounge: Node3D
var decor: Node3D
var lights: Node3D

func _ready() -> void:
    var showcase := has_meta("_menu_showcase")
    # The headless editor does not expose all GPU-only anti-aliasing settings.
    # Ensure the actual Forward+ game viewport uses TAA during play.
    if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless" and not has_meta("_streaming_standby") and not showcase:
        var viewport := get_viewport()
        # Do not reconfigure the shared render target on each streamed hall.
        # Respect the current graphics option, including when TAA is disabled.
        var settings := get_node_or_null("/root/GameSettings")
        if settings != null:
            viewport.use_taa = bool(settings.get_option("taa"))
        viewport.anisotropic_filtering_level = Viewport.ANISOTROPY_8X
        viewport.texture_mipmap_bias = 0.25
    wood = OAK.duplicate() as StandardMaterial3D
    wood.uv1_scale = Vector3.ONE
    wood.cull_mode = BaseMaterial3D.CULL_DISABLED
    fabric = JACQUARD.duplicate() as StandardMaterial3D
    fabric.uv1_scale = Vector3.ONE
    fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
    # Poly Haven PBR surfaces: dark recessed wood below, olive woven
    # book-cover fabric above. Keep original structural walls/colliders.
    wall_paint = UPPER_WALL.duplicate() as StandardMaterial3D
    wall_panel = LOWER_WALL.duplicate() as StandardMaterial3D
    dark_wood = _material(Color("#37221b"), 0.65)
    gold = _material(Color("#b88d4d"), 0.34, 0.7)
    brass = _material(Color("#86643d"), 0.32, 0.65)
    velvet = _material(Color("#50252d"), 0.88)
    green_felt = _material(Color("#194c3e"), 0.98)
    screen_black = _material(Color("#101720"), 0.25)
    stone = _material(Color("#3b3b43"), 0.72)
    pillar_wood = PILLAR_VENEER.duplicate() as StandardMaterial3D
    dark_ceiling = ROOF_PLANKS.duplicate() as StandardMaterial3D
    beam_wood = BEAM_TIMBER.duplicate() as StandardMaterial3D
    parquet_border = PARQUET_EDGE.duplicate() as StandardMaterial3D
    fabric_piping = GOLD_FABRIC.duplicate() as StandardMaterial3D
    warm_white = _glow(Color("#ffd5a1"), 1.55)
    red_light = _glow(Color("#f2545d"), 1.3)

    architecture = _section("Architecture")
    carpeting = _section("RedCarpet")
    machines = _section("SlotMachines")
    gaming = _section("GamingTables")
    bar_area = _section("CornerBar")
    lounge = _section("Lounge")
    decor = _section("Decor")
    lights = _section("Lighting")
    # Existing section nodes in main.tscn are stable editor objects.
    # Generated detail nodes stay unowned: they are a visible editor preview,
    # never accidentally saved as duplicates over their runtime versions.
    if architecture.get_child_count() == 0:
        _make_architecture()
    if carpeting.get_child_count() == 0:
        _make_carpet()
    _make_slots()
    if bar_area.get_child_count() == 0:
        _make_bar()
    # The authored bar shelves may have been moved or deleted in Godot.
    # Rebuild only their cheap physics boxes from the visible saved meshes
    # so removed shelves never leave invisible obstacles in the room.
    if not Engine.is_editor_hint() and not showcase:
        _align_bar_shelf_collisions()
    _make_tables()
    _make_lounge()
    if decor.get_child_count() == 0:
        _make_details()
    if lights.get_child_count() == 0:
        _make_lights()

    # The number belongs to the casino itself, not to the run controller.
    # Also show it when artists preview/play main.tscn directly in Godot.
    # It remains a generated, ownerless node; the authored scene and the
    # carefully tuned baked lighting stay untouched.
    if not has_node("NeonLevelSign") and not has_meta("_baking_room") and not showcase:
        var neon := NeonLevelSign.new() as Node3D
        neon.name = "NeonLevelSign"
        if Engine.is_editor_hint():
            add_child(neon, false, Node.INTERNAL_MODE_BACK)
        else:
            add_child(neon)

    # Keep contrast controllable live, including in newly streamed rooms.
    if not Engine.is_editor_hint():
        var game_settings = get_node_or_null("/root/GameSettings")
        if game_settings != null:
            game_settings.options_changed.connect(_on_contrast_option_changed)
            apply_image_contrast()

    # Share the exact same pre-baked VoxelGI rig between the game and Godot's
    # scene viewport. Editor previews are transient, internal, and ownerless:
    # no duplicate probe nodes are serialized into main.tscn. Gameplay still
    # receives one room-local rig per active/streamed room.
    if not has_node("VoxelGIRig") and not showcase:
        var gi_rig := VoxelRig.new() as Node3D
        gi_rig.name = "VoxelGIRig"
        if Engine.is_editor_hint():
            add_child(gi_rig, false, Node.INTERNAL_MODE_BACK)
        else:
            add_child(gi_rig)

    # Runtime-only positional sound, with no extra editor scene objects.
    if not Engine.is_editor_hint() and not has_meta("_baking_room") and not showcase:
        var soundscape := RoomSoundscape.new() as Node3D
        soundscape.name = "RoomSoundscape"
        add_child(soundscape)

    # Keep the designer-authored scene untouched. The game controller and
    # choice doors exist only in a started/continued run, not in editor mode.
    # The offline VoxelGI bake must never generate a live run controller.
    if not Engine.is_editor_hint() and not has_meta("_baking_room") and not showcase:
        var state = get_node_or_null("/root/LoopState")
        if state != null and state.active and state.tutorial_done and not state.finished \
                and not has_meta("_streaming_standby"):
            # Staged instances have no Player or HUD until the live character
            # and controller are transferred into them at the portal seam.
            var controller := Node3D.new()
            controller.name = "LoopController"
            controller.set_script(load("res://gameplay/loop_controller.gd"))
            add_child(controller)


func _on_contrast_option_changed(key: String) -> void:
    if key == "image_contrast":
        apply_image_contrast()


func apply_image_contrast() -> void:
    var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
    var game_settings = get_node_or_null("/root/GameSettings")
    # During streaming the WorldEnvironment is intentionally detached;
    # the handoff reapplies the current setting once it is restored.
    if world != null and world.environment != null and game_settings != null:
        world.environment.adjustment_enabled = true
        world.environment.adjustment_contrast = float(
            game_settings.get_option("image_contrast"))


func _section(label: String) -> Node3D:
    var saved := get_node_or_null(label) as Node3D
    if saved != null:
        return saved
    # Backwards compatible when hall.gd is used outside main.tscn.
    var node := Node3D.new()
    node.name = label
    add_child(node)
    return node

func _material(color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = rough
    mat.metallic = metal
    return mat

func _glow(color: Color, energy: float) -> StandardMaterial3D:
    var mat := _material(color, 0.35)
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = energy
    return mat

func _box(parent: Node3D, label: String, position_3d: Vector3,
        dimensions: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = label
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    mesh_node.mesh = mesh
    if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
        # Every PBR-clad surface gets its own sensible UV repetition: no
        # stretched 52 m walls or 12 m bar textures. Fabric has a finer repeat.
        var pbr: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
        var length: float = maxf(dimensions.x, dimensions.z)
        if label == "MainCeiling" or label == "WestCeiling":
            pbr.uv1_scale = Vector3(
                maxf(1.0, dimensions.x / 1.75),
                maxf(1.0, dimensions.z / 1.75), 1.0)
        elif label.ends_with("Wall"):
            pbr.uv1_scale = Vector3(
                maxf(1.0, length / 1.15),
                maxf(1.0, dimensions.y / 1.15), 1.0)
        elif label == "WoodWainscoting":
            pbr.uv1_scale = Vector3(
                maxf(1.0, length / 2.0),
                maxf(1.0, dimensions.y / 1.4), 1.0)
        elif label == "FlutedPillar":
            pbr.uv1_scale = Vector3(1.0, 3.0, 1.0)
        elif label.begins_with("Pillar") or label.ends_with("_Crown")                 or label.contains("Ceiling"):
            pbr.uv1_scale = Vector3(
                maxf(1.0, dimensions.x / 1.0),
                maxf(1.0, dimensions.y / 1.0),
                maxf(1.0, dimensions.z / 1.0))
        else:
            pbr.uv1_scale = Vector3(
                maxf(1.0, dimensions.x / 1.45),
                maxf(1.0, dimensions.z / 1.45), 1.0)
        pbr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        mesh_node.material_override = pbr
    else:
        mesh_node.material_override = mat
    mesh_node.position = position_3d
    parent.add_child(mesh_node)
    if solid:
        var body := StaticBody3D.new()
        body.name = label + "_Collision"
        body.set_meta("collision_for", label)
        body.position = position_3d
        var shape := CollisionShape3D.new()
        var box_shape := BoxShape3D.new()
        box_shape.size = dimensions
        shape.shape = box_shape
        body.add_child(shape)
        parent.add_child(body)
    return mesh_node

func _cylinder(parent: Node3D, label: String, pos: Vector3,
        radius: float, height: float, mat: Material, solid: bool = false, segments: int = 20) -> MeshInstance3D:
    var obj := MeshInstance3D.new()
    obj.name = label
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = segments
    obj.mesh = mesh
    obj.material_override = mat
    obj.position = pos
    parent.add_child(obj)
    if solid:
        var body := StaticBody3D.new()
        body.name = label + "_Collision"
        body.position = pos
        var shape := CollisionShape3D.new()
        var cylinder := CylinderShape3D.new()
        cylinder.radius = radius
        cylinder.height = height
        shape.shape = cylinder
        body.add_child(shape)
        parent.add_child(body)
    return obj

func _sphere(parent: Node3D, label: String, pos: Vector3, radius: float, mat: Material) -> void:
    var node := MeshInstance3D.new()
    node.name = label
    var ball := SphereMesh.new()
    ball.radius = radius
    ball.height = radius * 2.0
    ball.radial_segments = 12
    ball.rings = 6
    node.mesh = ball
    node.material_override = mat
    node.position = pos
    parent.add_child(node)

func _text(parent: Node3D, value: String, pos: Vector3,
        yaw: float, size: int = 66, tint: Color = Color("#e1c28e")) -> void:
    var sign := Label3D.new()
    sign.name = "Sign_" + value.replace(" ", "_")
    sign.text = value
    sign.font_size = size
    sign.pixel_size = 0.005
    sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    sign.modulate = tint
    sign.position = pos
    sign.rotation.y = yaw
    sign.double_sided = true
    parent.add_child(sign)

func _floor_quad(name: String, left: float, right: float, back: float, front: float,
        elevation: float, material: Material, texture_meters: float, section: Node3D) -> void:
    # Planar, world-space UVs keep the planks and fabric at a stable scale
    # across both legs of the L-shaped hall.
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_material(material)
    var a := Vector3(left, elevation, back)
    var b := Vector3(right, elevation, back)
    var c := Vector3(right, elevation, front)
    var d := Vector3(left, elevation, front)
    for corner in [a, c, b, a, d, c]:
        surface.set_normal(Vector3.UP)
        surface.set_uv(Vector2(corner.x / texture_meters, corner.z / texture_meters))
        surface.add_vertex(corner)
    # Normalmapped materials require tangents. Omitting these can make
    # textured floors render almost black or distort PBR lighting.
    surface.generate_tangents()
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = surface.commit()
    section.add_child(node)

func _make_architecture() -> void:
    # Two non-overlapping floor sections form the L (a concave corner at -6,0).
    # The west wing was extended from 20 to 40 m after the first visual playtest.
    _floor_quad("OakMainWing", -6.0, 6.0, -13.0, 14.0, 0.005, wood, 1.20, architecture)
    _floor_quad("OakWestWing", -46.0, -6.0, -13.0, 0.0, 0.005, wood, 1.20, architecture)
    _box(architecture, "MainWingFloorCollider", Vector3(0, -0.12, 0.5), Vector3(12, 0.24, 27), dark_wood, true).visible = false
    _box(architecture, "WestWingFloorCollider", Vector3(-26, -0.12, -6.5), Vector3(40, 0.24, 13), dark_wood, true).visible = false
    # Outer perimeter walls, broken only at the deliberate concave corner.
    _wall("EntryBackWall", Vector3(0, 3.0, 14.18), Vector3(12.4, WALL_HEIGHT, 0.36))
    _wall("RightMainWall", Vector3(6.18, 3.0, 0.5), Vector3(0.36, WALL_HEIGHT, 27.4))
    _wall("NorthWestWall", Vector3(-20, 3.0, -13.18), Vector3(52.4, WALL_HEIGHT, 0.36))
    _wall("FarExitWall", Vector3(-46.18, 3.0, -6.5), Vector3(0.36, WALL_HEIGHT, 13.4))
    _wall("SouthWestWall", Vector3(-26, 3.0, 0.18), Vector3(40.4, WALL_HEIGHT, 0.36))
    _wall("LeftMainWall", Vector3(-6.18, 3.0, 7), Vector3(0.36, WALL_HEIGHT, 14.4))

    _box(architecture, "MainCeiling", Vector3(0, 6.10, 0.5), Vector3(12.2, 0.23, 27.2), dark_ceiling)
    _box(architecture, "WestCeiling", Vector3(-26, 6.10, -6.5), Vector3(40.2, 0.23, 13.2), dark_ceiling)

    # Wainscoting, trims and pillars make the wall segments read as one casino.
    for item in [
        [Vector3(0, 1.02, 14.0), Vector3(12, 2.0, 0.12)],
        [Vector3(5.99, 1.02, 0.5), Vector3(0.12, 2.0, 27)],
        [Vector3(-20, 1.02, -12.99), Vector3(52, 2.0, 0.12)],
        [Vector3(-45.99, 1.02, -6.5), Vector3(0.12, 2.0, 13)],
        [Vector3(-26, 1.02, -0.01), Vector3(40, 2.0, 0.12)],
        [Vector3(-5.99, 1.02, 7), Vector3(0.12, 2.0, 14)]
    ]:
        _box(architecture, "WoodWainscoting", item[0], item[1], wall_panel)
    for z in [12.0, 6.0, 0.0, -6.0, -12.0]:
        _column(Vector3(5.65, 0, z))
    for x in [-44.0, -38.0, -32.0, -26.0, -20.0, -14.0, -8.0]:
        _column(Vector3(x, 0, -12.7))
    _column(Vector3(-5.8, 0, 0.1))
    for x in [-43.0, -37.0, -31.0, -25.0, -19.0, -13.0, -8.0]:
        _column(Vector3(x, 0, 0.2))
    for z in [4.0, 11.0]:
        _column(Vector3(-5.7, 0, z))
    # Brown Planks 05 structural beams. Their tops run INTO the ceiling
    # (underside y=5.985) instead of ending below it with a visible gap.
    # Crossings have different widths, and coplanar placeholder overlays
    # were removed rather than stacked on top of the new timber.
    # The three former longitudinal "CeilingGoldBeam" members coincided
    # with the existing *_Crown wall beams, producing depth-buffer fighting
    # at the far exit and bar. Wall crowns now provide those members alone.
    # Cross beams meet (rather than penetrate) the exposed crown inner face.
    for z in [0.0, 7.0, 13.0]:
        _box(architecture, "CeilingTrim_%04d" % architecture.get_child_count(),
            Vector3(0, 5.865, z), Vector3(11.56, 0.27, 0.20), beam_wood)
    for x in [-42.0, -35.0, -28.0, -21.0, -14.0, -10.0]:
        _box(architecture, "WestCeilingTrim_%04d" % architecture.get_child_count(),
            Vector3(x, 5.865, -6.5), Vector3(0.20, 0.27, 12.55), beam_wood)
    # Entry framing and end wall doors (decorative until anomaly logic is added).
    _box(architecture, "EntryDoor", Vector3(0, 1.5, 13.97), Vector3(3.2, 3, 0.1), dark_wood)
    for x in [-1.64, 1.64]:
        _box(architecture, "EntryDoorRail", Vector3(x, 1.7, 13.8), Vector3(0.075, 3.3, 0.11), gold)
    # The label originally showed its back face to the incoming player.
    # Rotate 180 degrees and keep it vertically inside the illuminated frame.
    _text(architecture, "CASINO ANOMALY",
        Vector3(0, 4.14, 13.70), PI, 64)
    for z in [-9.65, -3.7]:
        _box(architecture, "ExitDoor", Vector3(-45.94, 1.62, z), Vector3(0.1, 3.25, 2.05), dark_wood)
        _box(architecture, "ExitFrameTop", Vector3(-45.84, 3.35, z), Vector3(0.22, 0.11, 2.26), gold)
        for dz in [-1.09, 1.09]:
            _box(architecture, "ExitFrame", Vector3(-45.84, 1.7, z + dz), Vector3(0.2, 3.3, 0.08), gold)
        _text(architecture, "EXIT", Vector3(-45.72, 4.02, z), PI / 2.0, 58)

func _wall(label: String, pos: Vector3, size: Vector3) -> void:
    _box(architecture, label, pos, size, wall_paint, true)
    # Each timber crown stops at the INNER face of the next crown.
    # Previous full-length boxes intersected at equal heights: their
    # coplanar tops were responsible for angular z-fighting, especially
    # at the far exit and behind the bar.
    var crown_pos := Vector3(pos.x, 5.885, pos.z)
    if size.x > size.z:
        var run_width: float
        match label:
            "NorthWestWall":
                crown_pos.z = -12.90
                run_width = 51.56  # x=-45.78 .. +5.78
            "SouthWestWall":
                crown_pos.x = -25.90
                crown_pos.z = -0.10
                run_width = 39.76  # x=-45.78 .. -6.02
            _:
                crown_pos.z = 13.90
                run_width = 11.56  # x=-5.78 .. +5.78
        _box(architecture, label + "_Crown", crown_pos,
            Vector3(run_width, 0.25, 0.24), beam_wood)
    else:
        var run_depth: float
        match label:
            "FarExitWall":
                crown_pos.x = -45.90
                run_depth = 12.56  # z=-12.78 .. -0.22
            "LeftMainWall":
                crown_pos.x = -5.90
                crown_pos.z = 6.78
                run_depth = 14.0   # z=-0.22 .. +13.78
            _:
                crown_pos.x = 5.90
                run_depth = 26.56  # z=-12.78 .. +13.78
        _box(architecture, label + "_Crown", crown_pos,
            Vector3(0.24, 0.25, run_depth), beam_wood)

func _column(pos: Vector3) -> void:
    # Decorative names must be unique: Godot silently substitutes generated
    # node names for duplicates, which breaks cap lookup and QA by prefix.
    var column_suffix := "_%04d" % architecture.get_child_count()
    # Core spans the full room height. Existing colliders and metadata stay
    # attached to FlutedPillar; all caps are decorative and non-colliding.
    var pillar := _box(architecture, "FlutedPillar",
        pos + Vector3(0, 2.955, 0), Vector3(0.52, 5.87, 0.52),
        pillar_wood, true)
    pillar.set_meta("decor_type", "pillar")
    # A stepped wooden shoe and capital hide both open ends. All caps have
    # larger footprints than the core: no equal-size coplanar ring faces.
    _box(architecture, "PillarBase" + column_suffix, pos + Vector3(0, 0.145, 0),
        Vector3(0.82, 0.28, 0.82), beam_wood)
    _box(architecture, "PillarBaseCollar" + column_suffix, pos + Vector3(0, 0.315, 0),
        Vector3(0.70, 0.075, 0.70), beam_wood)
    _box(architecture, "PillarCapitalCollar" + column_suffix, pos + Vector3(0, 5.67, 0),
        Vector3(0.74, 0.12, 0.74), beam_wood)
    _box(architecture, "PillarCapital" + column_suffix, pos + Vector3(0, 5.855, 0),
        Vector3(0.89, 0.31, 0.89), beam_wood)

func _carpet_mitered_point(vertices: Array[Vector2],
        outward_normals: Array[Vector2], corner: int,
        lateral_offset: float, elevation: float) -> Vector3:
    # Each 90-degree joint shares the SAME mitered vertex for both runs.
    # An outward CCW normal is (direction.y, -direction.x) in X/Z space.
    var previous: Vector2 = outward_normals[(corner - 1 + vertices.size()) % vertices.size()]
    var current: Vector2 = outward_normals[corner]
    var bisector: Vector2 = (previous + current).normalized()
    var projected_length := maxf(0.25, bisector.dot(current))
    var p: Vector2 = vertices[corner] + bisector * (lateral_offset / projected_length)
    return Vector3(p.x, elevation, p.y)


func _carpet_surface_quad(surface: SurfaceTool,
        a: Vector3, b: Vector3, c: Vector3, d: Vector3,
        start_u: float, end_u: float, start_v: float, end_v: float) -> void:
    # This order is consistent along every counter-clockwise perimeter edge:
    # a -> b -> c -> d. In particular, top faces point UP rather than
    # flipping between X and Z runs as in the previous six-piece border.
    var corners: Array[Vector3] = [a, b, c, d]
    var uv: Array[Vector2] = [
        Vector2(start_u, start_v), Vector2(end_u, start_v),
        Vector2(end_u, end_v), Vector2(start_u, end_v)
    ]
    for i in [0, 1, 2, 0, 2, 3]:
        surface.set_uv(uv[i])
        surface.add_vertex(corners[i])


func _make_carpet_perimeter() -> void:
    # A single COUNTER-CLOCKWISE outline in the horizontal X/Z plane.
    # Six shared joints include the concave corner at (-1.57, -3.48).
    # The runner itself is intentionally unchanged and retains three
    # non-overlapping floor patches. Decorative edging never has collision.
    var outline: Array[Vector2] = [
        Vector2(1.57, 12.7), Vector2(-1.57, 12.7),
        Vector2(-1.57, -3.48), Vector2(-44.9, -3.48),
        Vector2(-44.9, -6.62), Vector2(1.57, -6.62)
    ]
    var outward_normals: Array[Vector2] = []
    var cumulative_lengths: Array[float] = [0.0]
    for i in range(outline.size()):
        var edge: Vector2 = outline[(i + 1) % outline.size()] - outline[i]
        outward_normals.append(Vector2(edge.y, -edge.x).normalized())
        cumulative_lengths.append(cumulative_lengths[i] + edge.length())

    # Closed, slightly rounded cross-section, from the INSIDE carpet
    # edge across the flat top to the OUTSIDE floor edge and underneath.
    # Closing the underside removes open profile faces at shallow angles.
    var profile: Array[Vector2] = [
        Vector2(-0.088, 0.007), Vector2(-0.088, 0.041),
        Vector2(-0.080, 0.056), Vector2(-0.060, 0.069),
        Vector2(-0.038, 0.077), Vector2(0.040, 0.077),
        Vector2(0.062, 0.070), Vector2(0.080, 0.056),
        Vector2(0.088, 0.042), Vector2(0.088, 0.007),
        Vector2(-0.088, 0.007)
    ]
    var timber_surface := SurfaceTool.new()
    timber_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    timber_surface.set_material(parquet_border)
    for edge_i in range(outline.size()):
        var following := (edge_i + 1) % outline.size()
        var start_u := cumulative_lengths[edge_i] / 0.72
        var end_u := cumulative_lengths[edge_i + 1] / 0.72
        for side_i in range(profile.size() - 1):
            var first: Vector2 = profile[side_i]
            var second: Vector2 = profile[side_i + 1]
            var a := _carpet_mitered_point(outline, outward_normals,
                edge_i, first.x, first.y)
            var b := _carpet_mitered_point(outline, outward_normals,
                following, first.x, first.y)
            var c := _carpet_mitered_point(outline, outward_normals,
                following, second.x, second.y)
            var d := _carpet_mitered_point(outline, outward_normals,
                edge_i, second.x, second.y)
            _carpet_surface_quad(timber_surface, a, b, c, d,
                start_u, end_u,
                (first.x + 0.10 + first.y * 0.5) / 0.72,
                (second.x + 0.10 + second.y * 0.5) / 0.72)
    timber_surface.generate_normals()
    timber_surface.generate_tangents()
    var timber := MeshInstance3D.new()
    timber.name = "CarpetPerimeterWood"
    timber.mesh = timber_surface.commit()
    timber.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    carpeting.add_child(timber)

    # One continuous, thin fabric inlay. Its top is just 1.5 mm above
    # the wood's horizontal top (y=0.077): visually flush, no Z-fighting.
    # The band has identical miter joints, including the entry end.
    var gold_surface := SurfaceTool.new()
    gold_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    gold_surface.set_material(fabric_piping)
    for edge_i in range(outline.size()):
        var following := (edge_i + 1) % outline.size()
        var a := _carpet_mitered_point(outline, outward_normals,
            edge_i, -0.032, 0.0785)
        var b := _carpet_mitered_point(outline, outward_normals,
            following, -0.032, 0.0785)
        var c := _carpet_mitered_point(outline, outward_normals,
            following, -0.012, 0.0785)
        var d := _carpet_mitered_point(outline, outward_normals,
            edge_i, -0.012, 0.0785)
        _carpet_surface_quad(gold_surface, a, b, c, d,
            cumulative_lengths[edge_i] / 0.40,
            cumulative_lengths[edge_i + 1] / 0.40, 0.0, 0.05)
    gold_surface.generate_normals()
    gold_surface.generate_tangents()
    var gold_inlay := MeshInstance3D.new()
    gold_inlay.name = "CarpetPerimeterGold"
    gold_inlay.mesh = gold_surface.commit()
    gold_inlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    carpeting.add_child(gold_inlay)


func _make_carpet() -> void:
    # Existing 3-patch L-shape is retained. All six perimeter edges
    # now join at their actual corners, with no separate end caps.
    var strip_half := 1.57
    _carpet_patch("ApproachRunner", -strip_half, strip_half, -3.48, 12.7)
    _carpet_patch("TurnRunner", -strip_half, strip_half, -6.62, -3.48)
    _carpet_patch("WestRunner", -44.9, -strip_half, -6.62, -3.48)
    _make_carpet_perimeter()


func _carpet_patch(label: String, x0: float, x1: float, z0: float, z1: float) -> void:
    # Show the jacquard motif at readable floor scale instead of tiny noise.
    _floor_quad(label, x0, x1, z0, z1, FLOOR_Y, fabric, 0.95, carpeting)

func _slot_machine(pos: Vector3, yaw: float, accent: Color, number: int) -> void:
    # The casino's authored cabinets share one complete modular scene.
    # Never generate a pile of boxes again for a newly created legacy room.
    var stable_name := "Slot_%02d" % number
    var unit := machines.get_node_or_null(stable_name) as Node3D
    if unit != null:
        # Respect the level designer's saved scale, rotation and locations.
        if not Engine.is_editor_hint() and not unit.has_node("Body"):
            unit.queue_free()
        return

    unit = SLOT_CABINET.instantiate() as Node3D
    unit.name = stable_name
    unit.position = pos
    unit.rotation.y = yaw
    unit.set("accent_variant", number % 4)
    unit.set("cabinet_title", ["MIDNIGHT", "GOLD RUSH", "LUCKY 7", "NOVA", "ROYAL"][number % 5])
    unit.set("reel_seed", number % 5)
    machines.add_child(unit)

func _make_slots() -> void:
    var colors := [
        Color("#ff9e55"), Color("#61cfe8"), Color("#e1a2ff"), Color("#ff5e70")
    ]
    var n := 0
    for z in [10.4, 8.2, 5.8, 3.0, 0.2]:
        n += 1
        _slot_machine(Vector3(4.85, 0, z), -PI / 2.0, colors[n % colors.size()], n)
    for z in [10.1, 7.6, 4.6, 1.9]:
        n += 1
        _slot_machine(Vector3(-4.82, 0, z), PI / 2.0, colors[n % colors.size()], n)
    # Keep the corner view clear: no standalone machine hides the bar.
    # The visual rhythm stays asymmetrical in the entry wing.
    n += 1
    _slot_machine(Vector3(4.65, 0, 11.85), -PI / 2.0, colors[2], n)

func _align_bar_shelf_collisions() -> void:
    var shelves: Array[MeshInstance3D] = []
    var obsolete_bodies: Array[StaticBody3D] = []
    for child in bar_area.get_children():
        if child is MeshInstance3D and child.name.begins_with("BottleShelf"):
            shelves.append(child as MeshInstance3D)
        elif child is StaticBody3D and str(child.get_meta("collision_for", "")) == "BottleShelf":
            obsolete_bodies.append(child as StaticBody3D)
    # A designer might remove one or every shelf; never preserve colliders
    # from the old procedural three-row arrangement.
    for body in obsolete_bodies:
        bar_area.remove_child(body)
        body.queue_free()
    for shelf in shelves:
        var box_mesh := shelf.mesh as BoxMesh
        if box_mesh == null:
            push_warning("Bar shelf needs a BoxMesh for automatic collision: " + shelf.name)
            continue
        var body := StaticBody3D.new()
        body.name = str(shelf.name) + "_Collision"
        body.position = shelf.position
        body.rotation = shelf.rotation
        body.set_meta("collision_for", "BottleShelf")
        var shape := BoxShape3D.new()
        # Do not carry the visual scale onto the physics node. The scaled
        # authored mesh extent becomes the collision shape's real extent.
        shape.size = box_mesh.size * shelf.scale.abs()
        shape.margin = 0.005
        var collider := CollisionShape3D.new()
        collider.name = "ShelfShape"
        collider.shape = shape
        body.add_child(collider)
        bar_area.add_child(body)


func _make_bar() -> void:
    # The bar remains on the outside/right of the left turn as shown in the
    # playtest screenshot, but is now ONE continuous corner counter.
    # It reaches back into the second wing so it can be seen after turning.
    # Patron-facing sides stay north (+Z) and west (-X) of the counter.
    var top_wood := BAR_COUNTER_WOOD.duplicate() as StandardMaterial3D
    var bar_front := BAR_PANEL_WOOD.duplicate() as StandardMaterial3D
    var metal_detail := _material(Color("#d6b879"), 0.34, 0.68)

    # Long counter: across the visible bend and along the start of the west wing.
    _box(bar_area, "BarRunFacingApproach", Vector3(-2.0, 0.61, -9.46),
        Vector3(12.6, 1.18, 0.85), bar_front, true)
    _box(bar_area, "BarCounterFront", Vector3(-2.0, 1.22, -9.46),
        Vector3(12.7, 0.13, 1.01), gold)
    _box(bar_area, "BarCounterFrontInset", Vector3(-2.0, 1.305, -9.46),
        Vector3(12.48, 0.06, 0.81), top_wood)
    _box(bar_area, "BarFrontGoldFoot", Vector3(-2.0, 0.11, -8.99),
        Vector3(12.64, 0.10, 0.075), metal_detail)
    _box(bar_area, "BarFrontRail", Vector3(-2.0, 0.84, -8.99),
        Vector3(12.64, 0.055, 0.045), brass)

    # Perpendicular counter: its outer end follows the approach-side wall.
    # The shared rounded corner makes this an unmistakable L, rather than
    # two disconnected rectangular islands.
    _box(bar_area, "BarRunAlongTurn", Vector3(4.69, 0.61, -7.05),
        Vector3(0.85, 1.18, 4.50), bar_front, true)
    _box(bar_area, "BarCounterSide", Vector3(4.69, 1.22, -7.05),
        Vector3(1.03, 0.13, 4.61), gold)
    _box(bar_area, "BarCounterSideInset", Vector3(4.69, 1.305, -7.05),
        Vector3(0.83, 0.06, 4.46), top_wood)
    _box(bar_area, "BarSideRail", Vector3(4.23, 0.84, -7.05),
        Vector3(0.055, 0.055, 4.50), brass)
    _cylinder(bar_area, "BarRoundedCorner", Vector3(4.31, 0.61, -9.12),
        0.55, 1.18, bar_front, true, 24)
    _cylinder(bar_area, "BarRoundedGoldCap", Vector3(4.31, 1.22, -9.12),
        0.61, 0.13, gold, false, 24)
    _cylinder(bar_area, "BarRoundedWoodInset", Vector3(4.31, 1.305, -9.12),
        0.52, 0.06, top_wood, false, 24)

    # Bottle wall stays behind the bar; extend its shelving toward the bend.
    # The wooden rear wall and all three long shelves were decorative-only.
    # Their new StaticBody3D volumes keep the player behind the bar from
    # walking straight through the timber.
    _box(bar_area, "BarBackboard", Vector3(-1.40, 2.75, -12.76),
        Vector3(11.4, 3.30, 0.16), bar_front, true)
    for y in [1.9, 2.75, 3.60]:
        _box(bar_area, "BottleShelf", Vector3(-1.38, y, -12.52),
            Vector3(10.85, 0.09, 0.36), gold, true)
    var bottles := [
        Color("#80b69d"), Color("#a66d4f"), Color("#8a659e"), Color("#e5b66f")
    ]
    for row in range(3):
        for i in range(21):
            # Leave a distinct area for the detailed wine-bottle model on the
            # lower shelf; overlapping bottles used to flicker at close range.
            if row == 0 and i in [0, 1, 2, 3]:
                continue
            var x := -6.44 + float(i) * 0.50
            var y := 2.13 + float(row) * 0.85
            var color := _material(bottles[(i + row) % bottles.size()], 0.24)
            _cylinder(bar_area, "Bottle", Vector3(x, y, -12.48), 0.105, 0.39, color, false, 10)
            _cylinder(bar_area, "BottleNeck", Vector3(x, y + 0.25, -12.48), 0.052, 0.13, color, false, 10)
    _box(bar_area, "BarSignPanel", Vector3(-1.38, 4.72, -12.51),
        Vector3(4.2, 0.9, 0.14), screen_black)
    # Center against the ACTUAL shelf panel, not the old offset baseline.
    var bar_title := Label3D.new()
    bar_title.name = "Sign_MIDNIGHT_BAR"
    bar_title.text = "MIDNIGHT BAR"
    bar_title.font_size = 62
    bar_title.pixel_size = 0.0045
    bar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bar_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    bar_title.position = Vector3(-1.38, 4.72, -12.408)
    bar_title.modulate = Color("#e1c28e")
    bar_area.add_child(bar_title)

    # All barstools are now supplied solely by model_interior.gd.
    # Do not spawn cylinder placeholders behind the imported stools.

    # The five primitive white bar pendant globes and rods are removed.
    # The imported main chandelier supplies the decorative lighting.


func _game_table(pos: Vector3, label: String, index: int) -> void:
    var stable_name := label + str(index)
    var group := gaming.get_node_or_null(stable_name) as Node3D
    if group == null:
        group = Node3D.new()
        group.name = stable_name
        group.position = pos
        # Fallback for legacy scenes without authorable placement nodes.
        if index == 7:
            group.scale = Vector3(0.68, 1.0, 0.68)
        gaming.add_child(group)
    elif group.get_child_count() > 0:
        return
    var base := _cylinder(group, "TableSupport", Vector3(0, 0.49, 0),
        0.18, 0.94, dark_wood)
    base.rotation.y = float(index) * 0.2
    # Keep the original tabletop collider, and preserve the old surface
    # nodes for tools that resolve their dimensions, but do not render the
    # placeholder cylinders underneath the detailed PBR construction.
    var old_rim := _cylinder(group, "GoldTableRim", Vector3(0, 0.96, 0), 1.25, 0.14, gold, true, 24)
    var old_felt := _cylinder(group, "FeltSurface", Vector3(0, 1.045, 0), 1.14, 0.035, green_felt, false, 24)
    old_rim.visible = false
    old_felt.visible = false
    var top := GAME_TABLE_SURFACE.instantiate() as Node3D
    top.name = "DetailedTableSurface"
    group.add_child(top)
    # Existing horizontal coordinates and scene-relative floor anchor remain
    # unchanged, so authored layouts and anomaly targets are unaffected.
    for n in range(5):
        var angle := float(n) * TAU / 5.0 + 0.18
        var cx := sin(angle) * 1.78
        var cz := cos(angle) * 1.78
        var stool := GAME_TABLE_STOOL.instantiate() as Node3D
        stool.name = "GamingStool_%02d" % (n + 1)
        stool.position = Vector3(cx, 0.0, cz)
        group.add_child(stool)
    if index % 2 == 0:
        _cylinder(group, "RouletteCenter", Vector3(0, 1.105, 0), 0.49, 0.085, brass, false, 24)
        _cylinder(group, "RouletteInner", Vector3(0, 1.17, 0), 0.35, 0.045, screen_black, false, 24)
        _sphere(group, "IvoryBall", Vector3(0.24, 1.24, 0.14), 0.045, warm_white)
    else:
        for n in range(5):
            _box(group, "CardBack", Vector3(-0.44 + float(n) * 0.22, 1.082, 0.12),
                Vector3(0.16, 0.012, 0.23), warm_white)

func _make_tables() -> void:
    # Establish a longer second act after the corner without clogging the runner.
    # The first table sits beyond the end of the bar, with distinct small groups
    # along the southern side; the lounge occupies the northern side.
    _game_table(Vector3(-13.6, 0, -10.05), "Roulette", 2)
    _game_table(Vector3(-20.3, 0, -10.15), "Blackjack", 3)
    _game_table(Vector3(-27.2, 0, -10.10), "Roulette", 4)
    _game_table(Vector3(-34.2, 0, -10.15), "Cards", 5)
    _game_table(Vector3(-41.1, 0, -10.05), "Roulette", 6)
    _game_table(Vector3(-11.5, 0, -1.95), "Cards", 7)

func _make_lounge() -> void:
    # This section is reserved for imported Poly Haven furniture in
    # model_interior.gd. Do not instantiate old cube sofas or coffee tables.
    lounge.set_meta("replaced_by_polyhaven", true)

func _botanical_leaf_mesh() -> ArrayMesh:
    # A simple curved, ridged leaf, not an elongated sphere. This one mesh
    # is shared by all foliage instances, so geometry stays inexpensive.
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(7):
        var t0 := float(i) / 7.0
        var t1 := float(i + 1) / 7.0
        var w0 := 0.006 + 0.145 * sin(PI * t0)
        var w1 := 0.006 + 0.145 * sin(PI * t1)
        var y0 := 0.78 * t0
        var y1 := 0.78 * t1
        var curve0 := 0.13 * sin(PI * t0)
        var curve1 := 0.13 * sin(PI * t1)
        var left0 := Vector3(-w0, y0, curve0)
        var mid0 := Vector3(0, y0, curve0 - 0.040 * sin(PI * t0))
        var right0 := Vector3(w0, y0, curve0)
        var left1 := Vector3(-w1, y1, curve1)
        var mid1 := Vector3(0, y1, curve1 - 0.040 * sin(PI * t1))
        var right1 := Vector3(w1, y1, curve1)
        # Two shallow wings create a central vein ridge and highlights.
        for vertex in [
            left0, mid1, mid0, left0, left1, mid1,
            mid0, mid1, right1, mid0, right1, right0
        ]:
            tool.set_uv(Vector2(vertex.x * 2.0 + 0.5, vertex.y / 0.78))
            tool.add_vertex(vertex)
    tool.generate_normals()
    tool.generate_tangents()
    return tool.commit()


func _plant_visual(pos: Vector3, index: int, leaf_mesh: Mesh) -> void:
    # Six distinct potted plants preserve the old footprints and collisions.
    # Only the pot is solid; leaves can be walked past at the corridor edge.
    var terracotta := _material(
        [Color("#493338"), Color("#2d4544"), Color("#574b3b")][index % 3],
        0.57, 0.04)
    var leaf_dark := _material(
        [Color("#285143"), Color("#386343"), Color("#294d3d")][index % 3],
        0.77, 0.0)
    var leaf_light := _material(
        [Color("#497454"), Color("#587c58"), Color("#49705e")][index % 3],
        0.70, 0.0)
    var soil := _material(Color("#261e18"), 0.98)
    leaf_dark.cull_mode = BaseMaterial3D.CULL_DISABLED
    leaf_light.cull_mode = BaseMaterial3D.CULL_DISABLED

    # The plant root moves the pot, foliage AND pot collider together.
    var plant := Node3D.new()
    plant.name = "Plant_%02d" % index
    plant.position = pos
    decor.add_child(plant)
    var pot := _cylinder(plant, "PlantPot_%02d" % index,
        Vector3(0, 0.32, 0), 0.29, 0.63,
        terracotta, true, 20)
    pot.set_meta("decor_type", "plant")
    # Taper pot visually, while retaining its original physics cylinder.
    var pot_mesh := CylinderMesh.new()
    pot_mesh.top_radius = 0.300
    pot_mesh.bottom_radius = 0.225
    pot_mesh.height = 0.63
    pot_mesh.radial_segments = 20
    pot.mesh = pot_mesh

    var crown := Node3D.new()
    crown.name = "PlantFoliage_%02d" % index
    crown.position = Vector3.ZERO
    plant.add_child(crown)
    _cylinder(crown, "CeramicLip", Vector3(0, 0.614, 0),
        0.311, 0.065, terracotta, false, 20)
    _cylinder(crown, "PotSoil", Vector3(0, 0.652, 0),
        0.265, 0.024, soil, false, 20)
    _cylinder(crown, "LowStem", Vector3(0, 0.970, 0),
        0.036, 0.64, soil, false, 10)
    var tips := 18 + (index % 3) * 3
    for i in range(tips):
        var level := float(i % 3)
        var theta := float(i) * 2.39996323 + float(index) * 0.27
        var leaf := MeshInstance3D.new()
        leaf.name = "Leaf_%02d" % i
        leaf.mesh = leaf_mesh
        leaf.material_override = leaf_dark if i % 3 == 0 else leaf_light
        leaf.position = Vector3(
            cos(theta) * (0.035 + level * 0.028),
            0.795 + level * 0.148,
            sin(theta) * (0.035 + level * 0.028))
        leaf.rotation = Vector3(0, theta, 0.54 + 0.16 * sin(float(i) * 1.83))
        var length_scale := 0.91 + 0.12 * cos(float(i) * 2.51 + float(index))
        leaf.scale = Vector3(
            0.80 + 0.19 * sin(float(i) * 0.83 + 1.0),
            length_scale * (1.10 if i % 4 == 0 else 0.89),
            1.0)
        leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        crown.add_child(leaf)


func _make_details() -> void:
    # Removed the redundant "SLOTS" heading which intersected the neon
    # frame above the entrance and showed its mirrored back face.
    _text(decor, "TABLE GAMES", Vector3(-15, 3.55, -12.89), 0, 57)
    # Replace the six identically sized green spheres with individually
    # constructed taper-pot foliage, no overlap with lounge furniture.
    var leaf_mesh := _botanical_leaf_mesh()
    var positions: Array[Vector3] = [
        Vector3(2.9, 0, 12.2), Vector3(-3.65, 0, 12.0),
        Vector3(-20.95, 0, -0.78), Vector3(-7.2, 0, -1.25),
        Vector3(-31.15, 0, -0.78), Vector3(-41.4, 0, -0.78)
    ]
    for i in range(positions.size()):
        _plant_visual(positions[i], i, leaf_mesh)

    # Do not add the old white globe-and-chain chandelier placeholders:
    # the Poly Haven chandelier in ModelInteriors is the only fixture.


func _omni(pos: Vector3, tint: Color, energy: float, reach: float,
        cast_shadows: bool = false) -> void:
    var light := OmniLight3D.new()
    light.name = "WarmCasinoLamp"
    light.position = pos
    light.light_color = tint
    light.light_energy = energy
    light.omni_range = reach
    light.shadow_enabled = cast_shadows
    # Warm chandelier light can scatter through the volume, but keep
    # low-energy fill lamps out of the fog to prevent overbright haze.
    light.light_volumetric_fog_energy = 0.38 if cast_shadows else 0.12
    light.light_specular = 0.85
    if cast_shadows:
        light.shadow_bias = 0.05
        light.shadow_blur = 1.10
    lights.add_child(light)

func _make_lights() -> void:
    # Keep this fallback in sync with the authored cinematic rig. Distinct,
    # smaller pools of amber light leave believable shadows between bays.
    _omni(Vector3(0, 4.8, 9.2), Color("#ffdaa7"), 1.20, 6.1)
    _omni(Vector3(0, 4.8, 2.3), Color("#ffdaa7"), 1.18, 6.25)
    _omni(Vector3(1.3, 4.8, -7.0), Color("#ffdaa7"), 1.46, 6.85, true)
    _omni(Vector3(-8, 4.8, -6.0), Color("#ffdaa7"), 1.29, 6.9, true)
    _omni(Vector3(-17, 4.8, -6.0), Color("#ffdaa7"), 1.41, 7.15, true)
    _omni(Vector3(-26, 4.8, -6.0), Color("#ffdaa7"), 1.17, 6.35)
    _omni(Vector3(-35, 4.8, -6.0), Color("#ffdaa7"), 1.17, 6.35)
    _omni(Vector3(-43, 4.8, -6.0), Color("#ffdaa7"), 0.95, 6.2, true)
    # The bar is a small warm accent, not another room-wide fill.
    _omni(Vector3(1.2, 3.35, -9.8), Color("#ffba71"), 0.49, 4.0)
