extends Node3D

# First room-design pass. Everything is intentionally modular so assets may replace
# the whitebox furniture later without rebuilding the room or its collision layout.
const OAK: StandardMaterial3D = preload("res://floor_material.tres")
const JACQUARD: StandardMaterial3D = preload("res://carpet_material.tres")
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
    fabric = JACQUARD.duplicate() as StandardMaterial3D
    fabric.uv1_scale = Vector3.ONE
    wall_paint = _material(Color("#202a35"), 0.82)
    wall_panel = _material(Color("#4a2a2b"), 0.8)
    dark_wood = _material(Color("#37221b"), 0.65)
    gold = _material(Color("#b88d4d"), 0.34, 0.7)
    brass = _material(Color("#86643d"), 0.32, 0.65)
    velvet = _material(Color("#50252d"), 0.88)
    green_felt = _material(Color("#194c3e"), 0.98)
    screen_black = _material(Color("#101720"), 0.25)
    stone = _material(Color("#3b3b43"), 0.72)
    dark_ceiling = _material(Color("#171d27"), 0.88)
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
    mesh_node.material_override = mat
    mesh_node.position = position_3d
    parent.add_child(mesh_node)
    if solid:
        var body := StaticBody3D.new()
        body.name = label + "_Collision"
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
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = surface.commit()
    section.add_child(node)

func _make_architecture() -> void:
    # Two non-overlapping floor sections form the L (a concave corner at -6,0).
    _floor_quad("OakMainWing", -6.0, 6.0, -13.0, 14.0, 0.005, wood, 1.20, architecture)
    _floor_quad("OakWestWing", -26.0, -6.0, -13.0, 0.0, 0.005, wood, 1.20, architecture)
    _box(architecture, "MainWingFloorCollider", Vector3(0, -0.12, 0.5), Vector3(12, 0.24, 27), dark_wood, true).visible = false
    _box(architecture, "WestWingFloorCollider", Vector3(-16, -0.12, -6.5), Vector3(20, 0.24, 13), dark_wood, true).visible = false
    # Outer perimeter walls, broken only at the deliberate concave corner.
    _wall("EntryBackWall", Vector3(0, 3.0, 14.18), Vector3(12.4, WALL_HEIGHT, 0.36))
    _wall("RightMainWall", Vector3(6.18, 3.0, 0.5), Vector3(0.36, WALL_HEIGHT, 27.4))
    _wall("NorthWestWall", Vector3(-10, 3.0, -13.18), Vector3(32.4, WALL_HEIGHT, 0.36))
    _wall("FarExitWall", Vector3(-26.18, 3.0, -6.5), Vector3(0.36, WALL_HEIGHT, 13.4))
    _wall("SouthWestWall", Vector3(-16, 3.0, 0.18), Vector3(20.4, WALL_HEIGHT, 0.36))
    _wall("LeftMainWall", Vector3(-6.18, 3.0, 7), Vector3(0.36, WALL_HEIGHT, 14.4))

    _box(architecture, "MainCeiling", Vector3(0, 6.10, 0.5), Vector3(12.2, 0.23, 27.2), dark_ceiling)
    _box(architecture, "WestCeiling", Vector3(-16, 6.10, -6.5), Vector3(20.2, 0.23, 13.2), dark_ceiling)

    # Wainscoting, trims and pillars make the wall segments read as one casino.
    for item in [
        [Vector3(0, 1.02, 14.0), Vector3(12, 2.0, 0.12)],
        [Vector3(5.99, 1.02, 0.5), Vector3(0.12, 2.0, 27)],
        [Vector3(-10, 1.02, -12.99), Vector3(32, 2.0, 0.12)],
        [Vector3(-25.99, 1.02, -6.5), Vector3(0.12, 2.0, 13)],
        [Vector3(-16, 1.02, -0.01), Vector3(20, 2.0, 0.12)],
        [Vector3(-5.99, 1.02, 7), Vector3(0.12, 2.0, 14)]
    ]:
        _box(architecture, "WoodWainscoting", item[0], item[1], wall_panel)
    for z in [12.0, 6.0, 0.0, -6.0, -12.0]:
        _column(Vector3(5.65, 0, z))
    for x in [-24.0, -18.0, -12.0, -6.0]:
        _column(Vector3(x, 0, -12.7))
    _column(Vector3(-5.8, 0, 0.1))
    for x in [-21.0, -14.0, -8.0]:
        _column(Vector3(x, 0, 0.2))
    for z in [4.0, 11.0]:
        _column(Vector3(-5.7, 0, z))
    for x in [-25.9, -6.0, 6.0]:
        _box(architecture, "CeilingGoldBeam", Vector3(x, 5.82, -6.5), Vector3(0.09, 0.14, 12.8), gold)
    for z in [0.0, 7.0, 13.0]:
        _box(architecture, "CeilingTrim", Vector3(0, 5.85, z), Vector3(11.8, 0.13, 0.12), gold)
    for x in [-24.0, -17.0, -10.0]:
        _box(architecture, "WestCeilingTrim", Vector3(x, 5.85, -6.5), Vector3(0.12, 0.13, 12.8), gold)
    # Entry framing and end wall doors (decorative until anomaly logic is added).
    _box(architecture, "EntryDoor", Vector3(0, 1.5, 13.97), Vector3(3.2, 3, 0.1), dark_wood)
    for x in [-1.64, 1.64]:
        _box(architecture, "EntryDoorRail", Vector3(x, 1.7, 13.8), Vector3(0.075, 3.3, 0.11), gold)
    _text(architecture, "CASINO ANOMALY", Vector3(0, 4.15, 13.88), 0, 76)
    for z in [-9.65, -3.7]:
        _box(architecture, "ExitDoor", Vector3(-25.94, 1.62, z), Vector3(0.1, 3.25, 2.05), dark_wood)
        _box(architecture, "ExitFrameTop", Vector3(-25.84, 3.35, z), Vector3(0.22, 0.11, 2.26), gold)
        for dz in [-1.09, 1.09]:
            _box(architecture, "ExitFrame", Vector3(-25.84, 1.7, z + dz), Vector3(0.2, 3.3, 0.08), gold)
        _text(architecture, "EXIT", Vector3(-25.72, 4.02, z), PI / 2.0, 58)

func _wall(label: String, pos: Vector3, size: Vector3) -> void:
    _box(architecture, label, pos, size, wall_paint, true)
    if size.x > size.z:
        _box(architecture, label + "_Crown", Vector3(pos.x, 5.63, pos.z), Vector3(size.x, 0.13, 0.42), gold)
    else:
        _box(architecture, label + "_Crown", Vector3(pos.x, 5.63, pos.z), Vector3(0.42, 0.13, size.z), gold)

func _column(pos: Vector3) -> void:
    _box(architecture, "FlutedPillar", pos + Vector3(0, 2.78, 0), Vector3(0.33, 5.3, 0.33), dark_wood)
    for y in [0.19, 5.36, 5.55]:
        _box(architecture, "PillarGoldRing", pos + Vector3(0, y, 0), Vector3(0.52, 0.13, 0.52), gold)

func _make_carpet() -> void:
    # The runner turns LEFT as approached from the entrance (+Z heading -Z).
    # Three coplanar patches meet edge-to-edge and do not z-fight.
    var strip_half := 1.57
    _carpet_patch("ApproachRunner", -strip_half, strip_half, -3.48, 12.7)
    _carpet_patch("TurnRunner", -strip_half, strip_half, -6.62, -3.48)
    _carpet_patch("WestRunner", -24.9, -strip_half, -6.62, -3.48)

    var trim := _material(Color("#331a20"), 0.92)
    for x in [-strip_half, strip_half]:
        _box(carpeting, "ApproachBorderDark", Vector3(x, 0.038, 4.61), Vector3(0.16, 0.047, 16.18), trim)
        _box(carpeting, "ApproachGoldPiping", Vector3(x + (0.115 if x < 0 else -0.115), 0.067, 4.61),
            Vector3(0.025, 0.012, 16.18), gold)
    for z in [-6.62, -3.48]:
        _box(carpeting, "WestBorderDark", Vector3(-13.24, 0.038, z), Vector3(23.33, 0.047, 0.16), trim)
        _box(carpeting, "WestGoldPiping", Vector3(-13.24, 0.067, z + (0.115 if z < -5 else -0.115)),
            Vector3(23.33, 0.012, 0.025), gold)
    _box(carpeting, "EndTrim", Vector3(-24.9, 0.045, -5.05), Vector3(0.13, 0.035, 3.14), gold)

func _carpet_patch(label: String, x0: float, x1: float, z0: float, z1: float) -> void:
    _floor_quad(label, x0, x1, z0, z1, FLOOR_Y, fabric, 0.52, carpeting)

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
    # An asymmetrical mini-bank near the turn adds some visual layering.
    n += 1
    _slot_machine(Vector3(3.7, 0, -2.3), -PI / 2.0, colors[2], n)

func _make_bar() -> void:
    # Perpendicular runs wrap around the outside of the left-turn corner.
    _box(bar_area, "BarRunFacingApproach", Vector3(2.8, 0.61, -9.12),
        Vector3(5.2, 1.18, 0.85), dark_wood, true)
    _box(bar_area, "BarRunAlongTurn", Vector3(5.0, 0.61, -7.3),
        Vector3(0.85, 1.18, 3.85), dark_wood, true)
    _box(bar_area, "BarCounterFront", Vector3(2.8, 1.22, -9.12),
        Vector3(5.43, 0.13, 1.08), gold)
    _box(bar_area, "BarCounterSide", Vector3(5.0, 1.22, -7.3),
        Vector3(1.05, 0.13, 4.1), gold)
    _box(bar_area, "BarCounterTopInset", Vector3(2.7, 1.305, -9.12),
        Vector3(4.95, 0.06, 0.81), dark_wood)
    _box(bar_area, "BarBackboard", Vector3(2.6, 2.75, -12.76),
        Vector3(5.9, 3.3, 0.16), dark_wood)
    for y in [1.9, 2.75, 3.6]:
        _box(bar_area, "BottleShelf", Vector3(2.5, y, -12.50),
            Vector3(5.25, 0.09, 0.37), gold)
    var bottles := [
        Color("#80b69d"), Color("#a66d4f"), Color("#8a659e"), Color("#e5b66f")
    ]
    for row in range(3):
        for i in range(11):
            var x := 0.10 + float(i) * 0.47
            var y := 2.13 + float(row) * 0.85
            var color := _material(bottles[(i + row) % bottles.size()], 0.22)
            _cylinder(bar_area, "Bottle", Vector3(x, y, -12.48), 0.105, 0.39, color, false, 10)
            _cylinder(bar_area, "BottleNeck", Vector3(x, y + 0.25, -12.48), 0.052, 0.13, color, false, 10)
    _box(bar_area, "BarSignPanel", Vector3(2.55, 4.68, -12.52),
        Vector3(3.65, 0.88, 0.14), screen_black)
    _text(bar_area, "MIDNIGHT BAR", Vector3(2.55, 4.56, -12.41), 0, 65)
    for i in range(3):
        var x := 0.75 + float(i) * 1.65
        _cylinder(bar_area, "BarStoolSeat", Vector3(x, 0.72, -7.72), 0.33, 0.13, velvet)
        _cylinder(bar_area, "BarStoolStem", Vector3(x, 0.36, -7.72), 0.075, 0.62, brass)
    for z in [-5.8, -7.35]:
        _cylinder(bar_area, "SideBarStool", Vector3(3.82, 0.72, z), 0.32, 0.12, velvet)
        _cylinder(bar_area, "SideStoolStem", Vector3(3.82, 0.35, z), 0.07, 0.61, brass)
    for x in [1.0, 2.7, 4.4]:
        _sphere(bar_area, "Pendant", Vector3(x, 4.37, -9.55), 0.16, warm_white)
        _cylinder(bar_area, "PendantStem", Vector3(x, 5.2, -9.55), 0.025, 1.58, gold)

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
    _game_table(Vector3(-10.7, 0, -10.0), "Roulette", 2)
    _game_table(Vector3(-17.2, 0, -10.2), "Blackjack", 3)
    _game_table(Vector3(-22.6, 0, -10.0), "Roulette", 4)
    _game_table(Vector3(-10.7, 0, -1.95), "Cards", 5)

func _make_lounge() -> void:
    for i in range(2):
        var x := -18.4 - float(i) * 4.2
        _box(lounge, "SofaBase", Vector3(x, 0.39, -1.17), Vector3(2.25, 0.57, 1.05), velvet, true)
        _box(lounge, "SofaBack", Vector3(x, 0.85, -0.67), Vector3(2.25, 0.95, 0.23), velvet)
        for dx in [-1.04, 1.04]:
            _box(lounge, "SofaArm", Vector3(x + dx, 0.62, -1.2),
                Vector3(0.20, 0.58, 1.08), velvet)
        _cylinder(lounge, "CoffeeTable", Vector3(x, 0.42, -2.75), 0.53, 0.12, dark_wood, true)
        _cylinder(lounge, "CoffeeTableLeg", Vector3(x, 0.21, -2.75), 0.10, 0.35, brass)
        _sphere(lounge, "Lamp", Vector3(x + 0.6, 0.56, -2.75), 0.10, warm_white)

func _make_details() -> void:
    _text(decor, "SLOTS", Vector3(0, 4.54, 13.7), 0, 62)
    _text(decor, "TABLE GAMES", Vector3(-15, 3.55, -12.89), 0, 57)
    for pos in [Vector3(3.7, 0, 11.2), Vector3(-3.65, 0, 12),
                Vector3(-23.0, 0, -1.4), Vector3(-7.2, 0, -1.25)]:
        _cylinder(decor, "PlantPot", pos + Vector3(0, 0.32, 0), 0.29, 0.65, stone, true, 12)
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

func _omni(pos: Vector3, tint: Color, energy: float, reach: float) -> void:
    var light := OmniLight3D.new()
    light.name = "WarmCasinoLamp"
    light.position = pos
    light.light_color = tint
    light.light_energy = energy
    light.omni_range = reach
    light.shadow_enabled = false
    lights.add_child(light)

func _make_lights() -> void:
    for pos in [
        Vector3(0, 4.8, 9.2), Vector3(0, 4.8, 2.3),
        Vector3(1.3, 4.8, -7.0), Vector3(-8, 4.8, -6.0),
        Vector3(-17, 4.8, -6.0), Vector3(-23.5, 4.8, -6.0)
    ]:
        _omni(pos, Color("#ffdaa7"), 1.8, 13.5)
    _omni(Vector3(3.8, 3.35, -9.8), Color("#ffba71"), 1.25, 7.5)
    for pos in [Vector3(5.55, 3.1, 10.5), Vector3(-5.55, 3.1, 8.4),
                Vector3(-10, 3.1, -12.6), Vector3(-21.0, 3.1, -12.6)]:
        _sphere(decor, "WallSconce", pos, 0.16, warm_white)
        _omni(pos, Color("#ffd39c"), 0.55, 5.0)
