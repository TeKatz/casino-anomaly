extends Node3D

# First room-design pass. Everything is intentionally modular so assets may replace
# the whitebox furniture later without rebuilding the room or its collision layout.
const OAK: StandardMaterial3D = preload("res://floor_material.tres")
const JACQUARD: StandardMaterial3D = preload("res://carpet_material.tres")
const LOWER_WALL: StandardMaterial3D = preload("res://lower_wall_material.tres")
const UPPER_WALL: StandardMaterial3D = preload("res://upper_wall_material.tres")
const ROOF_PLANKS: StandardMaterial3D = preload("res://ceiling_material.tres")
const BAR_COUNTER_WOOD: StandardMaterial3D = preload("res://bar_top_material.tres")
const BAR_PANEL_WOOD: StandardMaterial3D = preload("res://bar_side_material.tres")
const PILLAR_VENEER: StandardMaterial3D = preload("res://pillar_material.tres")
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
    _make_architecture()
    _make_carpet()
    _make_slots()
    _make_bar()
    # Move the entire bar and its solid collision away from the wall pillars.
    bar_area.position.x = -0.95
    _make_tables()
    _make_lounge()
    _make_details()
    _make_lights()

func _section(label: String) -> Node3D:
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
        else:
            pbr.uv1_scale = Vector3(
                maxf(1.0, dimensions.x / 1.45),
                maxf(1.0, dimensions.z / 1.45), 1.0)
        pbr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
    for x in [-45.9, -6.0, 6.0]:
        _box(architecture, "CeilingGoldBeam", Vector3(x, 5.82, -6.5), Vector3(0.09, 0.14, 12.8), gold)
    for z in [0.0, 7.0, 13.0]:
        _box(architecture, "CeilingTrim", Vector3(0, 5.85, z), Vector3(11.8, 0.13, 0.12), gold)
    for x in [-42.0, -35.0, -28.0, -21.0, -14.0, -10.0]:
        _box(architecture, "WestCeilingTrim", Vector3(x, 5.85, -6.5), Vector3(0.12, 0.13, 12.8), gold)
    # Entry framing and end wall doors (decorative until anomaly logic is added).
    _box(architecture, "EntryDoor", Vector3(0, 1.5, 13.97), Vector3(3.2, 3, 0.1), dark_wood)
    for x in [-1.64, 1.64]:
        _box(architecture, "EntryDoorRail", Vector3(x, 1.7, 13.8), Vector3(0.075, 3.3, 0.11), gold)
    _text(architecture, "CASINO ANOMALY", Vector3(0, 4.15, 13.88), 0, 76)
    for z in [-9.65, -3.7]:
        _box(architecture, "ExitDoor", Vector3(-45.94, 1.62, z), Vector3(0.1, 3.25, 2.05), dark_wood)
        _box(architecture, "ExitFrameTop", Vector3(-45.84, 3.35, z), Vector3(0.22, 0.11, 2.26), gold)
        for dz in [-1.09, 1.09]:
            _box(architecture, "ExitFrame", Vector3(-45.84, 1.7, z + dz), Vector3(0.2, 3.3, 0.08), gold)
        _text(architecture, "EXIT", Vector3(-45.72, 4.02, z), PI / 2.0, 58)

func _wall(label: String, pos: Vector3, size: Vector3) -> void:
    _box(architecture, label, pos, size, wall_paint, true)
    if size.x > size.z:
        _box(architecture, label + "_Crown", Vector3(pos.x, 5.63, pos.z), Vector3(size.x, 0.13, 0.42), gold)
    else:
        _box(architecture, label + "_Crown", Vector3(pos.x, 5.63, pos.z), Vector3(0.42, 0.13, size.z), gold)

func _column(pos: Vector3) -> void:
    var pillar := _box(architecture, "FlutedPillar", pos + Vector3(0, 2.78, 0), Vector3(0.52, 5.3, 0.52), pillar_wood, true)
    pillar.set_meta("decor_type", "pillar")
    for y in [0.19, 5.36, 5.55]:
        _box(architecture, "PillarGoldRing", pos + Vector3(0, y, 0), Vector3(0.52, 0.13, 0.52), gold)

func _make_carpet() -> void:
    # The runner turns LEFT as approached from the entrance (+Z heading -Z).
    # Three coplanar patches meet edge-to-edge and do not z-fight.
    var strip_half := 1.57
    _carpet_patch("ApproachRunner", -strip_half, strip_half, -3.48, 12.7)
    _carpet_patch("TurnRunner", -strip_half, strip_half, -6.62, -3.48)
    _carpet_patch("WestRunner", -44.9, -strip_half, -6.62, -3.48)

    var trim := _material(Color("#331a20"), 0.92)
    for x in [-strip_half, strip_half]:
        _box(carpeting, "ApproachBorderDark", Vector3(x, 0.038, 4.61), Vector3(0.16, 0.047, 16.18), trim)
        _box(carpeting, "ApproachGoldPiping", Vector3(x + (0.115 if x < 0 else -0.115), 0.067, 4.61),
            Vector3(0.025, 0.012, 16.18), gold)
    for z in [-6.62, -3.48]:
        _box(carpeting, "WestBorderDark", Vector3(-23.24, 0.038, z), Vector3(43.33, 0.047, 0.16), trim)
        _box(carpeting, "WestGoldPiping", Vector3(-23.24, 0.067, z + (0.115 if z < -5 else -0.115)),
            Vector3(43.33, 0.012, 0.025), gold)
    _box(carpeting, "EndTrim", Vector3(-44.9, 0.045, -5.05), Vector3(0.13, 0.035, 3.14), gold)

func _carpet_patch(label: String, x0: float, x1: float, z0: float, z1: float) -> void:
    # Show the jacquard motif at readable floor scale instead of tiny noise.
    _floor_quad(label, x0, x1, z0, z1, FLOOR_Y, fabric, 0.95, carpeting)

func _slot_machine(pos: Vector3, yaw: float, accent: Color, number: int) -> void:
    var unit := Node3D.new()
    unit.name = "Slot_%02d" % number
    unit.position = pos
    unit.rotation.y = yaw
    machines.add_child(unit)
    var glow_mat := _glow(accent, 2.0)
    _box(unit, "Body", Vector3(0, 0.98, 0), Vector3(0.86, 1.88, 0.75), dark_wood, true)
    _box(unit, "SideTrimL", Vector3(-0.38, 1.16, 0.39), Vector3(0.08, 1.25, 0.06), gold)
    _box(unit, "SideTrimR", Vector3(0.38, 1.16, 0.39), Vector3(0.08, 1.25, 0.06), gold)
    _box(unit, "ScreenRim", Vector3(0, 1.23, 0.396), Vector3(0.68, 0.81, 0.042), brass)
    _box(unit, "Display", Vector3(0, 1.25, 0.426), Vector3(0.58, 0.67, 0.02), screen_black)
    _text(unit, "7 7 7" if number % 3 == 0 else ("BAR" if number % 3 == 1 else "★ 7 ★"),
        Vector3(0, 1.22, 0.453), 0, 43, accent)
    _box(unit, "TopGlow", Vector3(0, 1.89, 0.39), Vector3(0.71, 0.11, 0.06), glow_mat)
    _box(unit, "ButtonTray", Vector3(0, 0.73, 0.48), Vector3(0.71, 0.12, 0.23), gold)
    for i in range(3):
        _sphere(unit, "ButtonLamp", Vector3(-0.20 + float(i) * 0.2, 0.82, 0.57), 0.045, glow_mat)
    # A stool is offset from the cabinet's facing edge.
    _cylinder(unit, "StoolSeat", Vector3(0, 0.61, 1.25), 0.30, 0.15, velvet)
    _cylinder(unit, "StoolStem", Vector3(0, 0.30, 1.25), 0.08, 0.5, brass)

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
    _box(bar_area, "BarBackboard", Vector3(-1.40, 2.75, -12.76),
        Vector3(11.4, 3.30, 0.16), bar_front)
    for y in [1.9, 2.75, 3.60]:
        _box(bar_area, "BottleShelf", Vector3(-1.38, y, -12.52),
            Vector3(10.85, 0.09, 0.36), gold)
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
    _text(bar_area, "MIDNIGHT BAR", Vector3(-1.38, 4.58, -12.40), 0, 68)

    # All barstools are now supplied solely by model_interior.gd.
    # Do not spawn cylinder placeholders behind the imported stools.

    for x in [-6.25, -3.5, -0.75, 1.95, 4.10]:
        _sphere(bar_area, "Pendant", Vector3(x, 4.45, -9.70), 0.16, warm_white)
        _cylinder(bar_area, "PendantStem", Vector3(x, 5.26, -9.70), 0.025, 1.49, gold)

func _game_table(pos: Vector3, label: String, index: int) -> void:
    var group := Node3D.new()
    group.name = label + str(index)
    group.position = pos
    gaming.add_child(group)
    var base := _cylinder(group, "TableSupport", Vector3(0, 0.49, 0),
        0.18, 0.94, dark_wood)
    base.rotation.y = float(index) * 0.2
    _cylinder(group, "GoldTableRim", Vector3(0, 0.96, 0), 1.25, 0.14, gold, true, 24)
    _cylinder(group, "FeltSurface", Vector3(0, 1.045, 0), 1.14, 0.035, green_felt, false, 24)
    for n in range(5):
        var angle := float(n) * TAU / 5.0 + 0.18
        var cx := sin(angle) * 1.78
        var cz := cos(angle) * 1.78
        _cylinder(group, "ChairSeat", Vector3(cx, 0.51, cz), 0.34, 0.20, velvet)
        _cylinder(group, "ChairLeg", Vector3(cx, 0.23, cz), 0.08, 0.41, dark_wood)
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

func _make_details() -> void:
    _text(decor, "SLOTS", Vector3(0, 4.54, 13.7), 0, 62)
    _text(decor, "TABLE GAMES", Vector3(-15, 3.55, -12.89), 0, 57)
    # Space decorative topiary between sofa groups instead of inside cushions.
    for pos in [Vector3(2.9, 0, 12.2), Vector3(-3.65, 0, 12),
                Vector3(-20.95, 0, -0.78), Vector3(-7.2, 0, -1.25),
                Vector3(-31.15, 0, -0.78), Vector3(-41.4, 0, -0.78)]:
        var pot := _cylinder(decor, "PlantPot", pos + Vector3(0, 0.32, 0), 0.29, 0.65, stone, true, 12)
        pot.set_meta("decor_type", "plant")
        _cylinder(decor, "PlantStem", pos + Vector3(0, 0.95, 0), 0.07, 0.65, dark_wood)
        var leaves := _material(Color("#214f3c"), 0.93)
        _sphere(decor, "PlantLeaves", pos + Vector3(0, 1.50, 0), 0.53, leaves)
    # Distinctive octagonal chandelier at the bend; the L has a visual landmark.
    _cylinder(decor, "ChandelierMount", Vector3(-1.4, 5.75, -6.8), 0.25, 0.3, brass)
    _cylinder(decor, "ChandelierStem", Vector3(-1.4, 5.2, -6.8), 0.055, 0.9, gold)
    for i in range(12):
        var angle := float(i) * TAU / 12.0
        var x := -1.4 + sin(angle) * 1.22
        var z := -6.8 + cos(angle) * 1.22
        _sphere(decor, "ChandelierBulb", Vector3(x, 4.75, z), 0.115, warm_white)
        _cylinder(decor, "ChandelierChain", Vector3(x, 5.13, z), 0.025, 0.64, gold)

func _omni(pos: Vector3, tint: Color, energy: float, reach: float,
        cast_shadows: bool = false) -> void:
    var light := OmniLight3D.new()
    light.name = "WarmCasinoLamp"
    light.position = pos
    light.light_color = tint
    light.light_energy = energy
    light.omni_range = reach
    light.shadow_enabled = cast_shadows
    if cast_shadows:
        light.shadow_bias = 0.08
        light.shadow_blur = 1.30
    lights.add_child(light)

func _make_lights() -> void:
    # Four overhead fixtures cast shadows, the rest are inexpensive fill.
    # Reducing omnidirectional overlap restores visible contrast and depth.
    var ceiling_positions := [
        Vector3(0, 4.8, 9.2), Vector3(0, 4.8, 2.3),
        Vector3(1.3, 4.8, -7.0), Vector3(-8, 4.8, -6.0),
        Vector3(-17, 4.8, -6.0), Vector3(-26, 4.8, -6.0),
        Vector3(-35, 4.8, -6.0), Vector3(-43, 4.8, -6.0)
    ]
    for i in range(ceiling_positions.size()):
        _omni(ceiling_positions[i], Color("#ffdaa7"), 1.5, 11.5,
            i in [0, 2, 4, 6])
    _omni(Vector3(1.2, 3.35, -9.8), Color("#ffba71"), 1.05, 7.0)
    for pos in [Vector3(5.55, 3.1, 10.5), Vector3(-5.55, 3.1, 8.4),
                Vector3(-10, 3.1, -12.6), Vector3(-21.0, 3.1, -12.6),
                Vector3(-33, 3.1, -12.6), Vector3(-43, 3.1, -12.6)]:
        _sphere(decor, "WallSconce", pos, 0.16, warm_white)
        _omni(pos, Color("#ffd39c"), 0.42, 4.0)
