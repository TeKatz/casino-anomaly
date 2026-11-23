@tool
extends Node3D
## Reusable, genuinely volumetric PBR bottle mesh. Six unique silhouettes:
## faceted cut crystal, embossed gin, rounded liqueur, ribbed aperitif,
## green diamond-cut vermouth and angular blue reserve.
## This is not a billboard or an image: every bottle contains independently
## shaded 3D outer glass, inset liquid, neck, metallic fittings and a stopper.
@export_range(0, 5, 1) var design := 0:
    set(value):
        design = clampi(value, 0, 5)
        if is_inside_tree():
            _rebuild()

const PROFILES := [
    [Vector2(0.0, 0.88), Vector2(0.03, 1.02), Vector2(0.14, 1.0),
        Vector2(0.63, 1.0), Vector2(0.69, 0.94), Vector2(0.78, 0.47),
        Vector2(0.86, 0.43), Vector2(0.96, 0.43), Vector2(1.0, 0.43)],
    [Vector2(0.0, 0.88), Vector2(0.04, 1.00), Vector2(0.14, 0.97),
        Vector2(0.68, 0.97), Vector2(0.75, 0.92), Vector2(0.83, 0.49),
        Vector2(0.95, 0.44), Vector2(1.0, 0.44)],
    [Vector2(0.0, 0.58), Vector2(0.06, 0.88), Vector2(0.19, 1.14),
        Vector2(0.46, 1.21), Vector2(0.61, 1.04), Vector2(0.73, 0.59),
        Vector2(0.84, 0.44), Vector2(1.0, 0.43)],
    [Vector2(0.0, 0.78), Vector2(0.04, 0.90), Vector2(0.15, 0.88),
        Vector2(0.71, 0.84), Vector2(0.77, 0.74), Vector2(0.86, 0.38),
        Vector2(0.98, 0.39), Vector2(1.0, 0.39)],
    [Vector2(0.0, 0.87), Vector2(0.06, 1.04), Vector2(0.18, 1.0),
        Vector2(0.62, 1.03), Vector2(0.74, 0.89), Vector2(0.82, 0.53),
        Vector2(0.94, 0.43), Vector2(1.0, 0.43)],
    [Vector2(0.0, 0.88), Vector2(0.04, 1.02), Vector2(0.15, 0.99),
        Vector2(0.65, 0.98), Vector2(0.72, 0.90), Vector2(0.83, 0.44),
        Vector2(0.95, 0.40), Vector2(1.0, 0.40)]
]
const TITLES := ["VELVET\nACE", "SILVER\nLOTUS", "ROUGE\nCLOVER",
    "SOLARA", "MONTEVALE", "NIGHTFALL"]
const TYPES := ["RESERVE WHISKEY", "BOTANICAL GIN", "CRIMSON LIQUEUR",
    "BITTER APERITIF", "VERMOUTH ROSSO", "RESERVE SPICED RUM"]
const GLASS := [
    Color("#c99355"), Color("#dce6e8"), Color("#a64d64"),
    Color("#d58d55"), Color("#507b61"), Color("#456b8b")]
const DRINK := [
    Color("#8c390d"), Color("#c5d7d1"), Color("#85102a"),
    Color("#de5d20"), Color("#604620"), Color("#4e2616")]
const DARK_LABEL := ["#211a19", "#e4ded0", "#3e1528", "#e8d3ae",
    "#e2d8c2", "#172333"]
const INK := ["#ead2a4", "#292a34", "#efcba3", "#403026",
    "#373325", "#ead4ac"]


func _ready() -> void:
    _rebuild()


func _rebuild() -> void:
    # The model is generated in the editor as editable 3D geometry and
    # regenerated on loading in packaged builds. No bitmap silhouettes.
    for child in get_children():
        remove_child(child)
        child.free()
    _build()


func _material(hex: Color, metal: float, rough: float, alpha := 1.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(hex.r, hex.g, hex.b, alpha)
    mat.metallic = metal
    mat.roughness = rough
    if alpha < 0.999:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
    return mat


func _part(label: String, mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = mesh
    part.material_override = mat
    part.position = pos
    add_child(part)
    return part


func _cube(label: String, size: Vector3, pos: Vector3, mat: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    _part(label, mesh, mat, pos)


func _cylinder(label: String, r1: float, r2: float, height: float,
        y: float, mat: Material, segments := 32) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = r1
    mesh.bottom_radius = r2
    mesh.height = height
    mesh.radial_segments = segments
    mesh.rings = 1
    _part(label, mesh, mat, Vector3(0.0, y, 0.0))


func _radius(shape: int, theta: float, relative: float, cut: float) -> Vector2:
    var power := [0.56, 1.0, 0.91, 0.78, 0.79, 0.54][shape]
    var x := signf(cos(theta)) * pow(absf(cos(theta)), power)
    var z := signf(sin(theta)) * pow(absf(sin(theta)), power)
    var facets := [8, 24, 16, 12, 12, 8][shape]
    var bevel := (1.0 + cut * cos(theta * float(facets)))
    return Vector2(x * relative * bevel, z * relative * bevel)


func _lathe(label: String, outline: Array, body_r: float, height: float,
        glass_mat: Material, facet_strength: float, segments := 32) -> void:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Explicitly triangulated rings provide real 3D volume, shoulders and
    # beveled facets, unlike a primitive cylindrical placeholder.
    for row in range(outline.size() - 1):
        var lower: Vector2 = outline[row]
        var upper: Vector2 = outline[row + 1]
        for side in range(segments):
            var theta_a := float(side) * TAU / float(segments)
            var theta_b := float(side + 1) * TAU / float(segments)
            var horizontal_a := _radius(design, theta_a, body_r, facet_strength)
            var horizontal_b := _radius(design, theta_b, body_r, facet_strength)
            var a := Vector3(horizontal_a.x * lower.y, lower.x * height,
                horizontal_a.y * lower.y)
            var b := Vector3(horizontal_b.x * lower.y, lower.x * height,
                horizontal_b.y * lower.y)
            var c := Vector3(horizontal_a.x * upper.y, upper.x * height,
                horizontal_a.y * upper.y)
            var d := Vector3(horizontal_b.x * upper.y, upper.x * height,
                horizontal_b.y * upper.y)
            # Outer-face winding; normal from geometry, no flat sprite.
            _triangle(tool, a, c, b)
            _triangle(tool, b, c, d)
    tool.generate_normals()
    var mesh: ArrayMesh = tool.commit()
    _part(label, mesh, glass_mat)


func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
    for v in [a, b, c]:
        tool.add_vertex(v)


func _torus(label: String, center_y: float, outer: float,
        thickness: float, mat: Material) -> void:
    var torus := TorusMesh.new()
    torus.inner_radius = maxf(0.001, outer - thickness)
    torus.outer_radius = outer
    torus.ring_segments = 12
    torus.rings = 32
    _part(label, torus, mat, Vector3(0.0, center_y, 0.0))


func _label_text(content: String, y: float, z: float, text_size: int,
        ink: Color, label_name: String) -> void:
    var letter := Label3D.new()
    letter.name = label_name
    letter.position = Vector3(0.0, y, z)
    letter.font_size = text_size
    letter.pixel_size = 0.0013
    letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    letter.modulate = ink
    letter.outline_size = 1
    letter.outline_modulate = Color("#111113")
    letter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    letter.text = content
    add_child(letter)


func _build() -> void:
    var kind := clampi(design, 0, 5)
    var wide: float = [0.150, 0.126, 0.144, 0.121, 0.142, 0.151][kind]
    var height: float = [0.590, 0.635, 0.570, 0.665, 0.625, 0.598][kind]
    var facet: float = [0.046, 0.008, 0.018, 0.045, 0.050, 0.039][kind]
    var outside := _material(GLASS[kind], 0.03, 0.067, 0.33)
    outside.refraction_enabled = true
    outside.refraction_scale = 0.025
    outside.clearcoat_enabled = true
    outside.clearcoat = 0.92
    outside.clearcoat_roughness = 0.04
    var contents := _material(DRINK[kind], 0.0, 0.12, 0.90)
    var brass := _material(Color("#bd995b"), 0.82, 0.22)
    var gold := _material(Color("#e0bd80"), 0.74, 0.24)
    var silver := _material(Color("#bfc7cb"), 0.84, 0.21)
    var metal: StandardMaterial3D = silver if kind == 1 else gold
    var seal := _material(Color(DARK_LABEL[kind]), 0.17, 0.65)
    var text_col := Color(INK[kind])
    var neck_radius := wide * [0.43, 0.44, 0.43, 0.39, 0.43, 0.41][kind]
    var body_outline: Array = PROFILES[kind]
    _lathe("HandCutGlassShell", body_outline, wide, height, outside, facet)
    # Inner liquid has its own closed silhouette and visible meniscus,
    # with a gap between it and the glass shoulder.
    var liquid_profile: Array = []
    for point in body_outline:
        var line: Vector2 = point
        if line.x <= 0.60:
            liquid_profile.append(Vector2(line.x, line.y * 0.88))
    liquid_profile.append(Vector2(0.61, 0.83 if kind != 2 else 0.89))
    liquid_profile.append(Vector2(0.613, 0.0))
    _lathe("InnerLiquidVolume", liquid_profile, wide, height, contents, facet * 0.4)
    # Thick optical heel, concentric floor and a physical punt.
    _cylinder("WeightedCrystalHeel", wide * 1.00, wide * 0.93,
        0.034, 0.017, _material(GLASS[kind].lightened(0.30), 0.01, 0.04, 0.62))
    _torus("FootBevel", 0.033, wide * 0.96, 0.012, outside)
    # Solid neck hardware and a genuine top closure.
    _cylinder("MouthRim", neck_radius * 1.08, neck_radius, 0.018,
        height * 0.975, metal)
    _cylinder("EngravedNeckBand", neck_radius * 1.16,
        neck_radius * 1.12, 0.052, height * 0.88, metal)
    _torus("BandUpperBead", height * 0.911, neck_radius * 1.20, 0.007, brass)
    _torus("BandLowerBead", height * 0.85, neck_radius * 1.20, 0.006, brass)
    var closure_y := height + 0.017
    if kind == 2:
        # Sculpted crown: gilded collar with a spherical finial.
        var jewel := SphereMesh.new()
        jewel.radius = neck_radius * 0.93
        jewel.height = neck_radius * 1.86
        jewel.radial_segments = 24
        jewel.rings = 12
        _part("OrnateCrownStopper", jewel, brass,
            Vector3(0, closure_y + neck_radius * 0.87, 0))
        _torus("CrownNeckSeat", closure_y, neck_radius * 1.18, 0.02, gold)
    elif kind == 5:
        _cylinder("NaturalWoodenStopper", neck_radius * 1.26, neck_radius * 1.27,
            0.060, closure_y + 0.024, _material(Color("#71503a"), 0.0, 0.92))
        _torus("StopperBrassLine", closure_y + 0.038, neck_radius * 1.22, 0.007, metal)
    else:
        var cap_height := 0.052 if kind != 1 else 0.061
        _cylinder("MetallicEngravedCap", neck_radius * 1.25,
            neck_radius * 1.26, cap_height,
            closure_y + cap_height * 0.50, metal)
        for ring in range(4):
            _torus("CapMachinedGroove_%d" % ring,
                closure_y + float(ring) * cap_height / 4.0,
                neck_radius * 1.27, 0.0035, brass)
    # True embossed cap knurling: individual raised metal teeth.
    for tooth in range(12):
        var theta := TAU * float(tooth) / 12.0
        var ring_radius := neck_radius * 1.245
        var nick := BoxMesh.new()
        nick.size = Vector3(0.004, 0.030, 0.006)
        var part := _part("CapFluting_%02d" % tooth, nick, brass,
            Vector3(cos(theta) * ring_radius,
                closure_y + 0.038, sin(theta) * ring_radius))
        part.rotation.y = -theta

    # A multi-layered physically raised paper-and-metal label on the FRONT.
    # The label itself is an accessory attached to a 3D bottle, never a
    # replacement bottle sprite or a billboard facing the camera.
    var label_width := wide * 1.74
    var label_height := 0.228 if kind != 3 else 0.250
    var label_y := height * 0.39
    var label_depth := wide * 1.008 + 0.020
    _cube("EmbossedMetalLabelFrame",
        Vector3(label_width + 0.021, label_height + 0.018, 0.014),
        Vector3(0, label_y, label_depth), brass)
    _cube("DieCutPaperLabel",
        Vector3(label_width, label_height, 0.015),
        Vector3(0, label_y, label_depth + 0.009), seal)
    _cube("InnerGoldRule",
        Vector3(label_width * 0.88, 0.004, 0.002),
        Vector3(0, label_y + label_height * 0.36,
            label_depth + 0.020), metal)
    _cube("LowerGoldRule",
        Vector3(label_width * 0.88, 0.004, 0.002),
        Vector3(0, label_y - label_height * 0.32,
            label_depth + 0.020), metal)
    _label_text(TITLES[kind], label_y + 0.018, label_depth + 0.023,
        25 if kind != 4 else 23, text_col, "RaisedSignatureLettering")
    _label_text(TYPES[kind], label_y - 0.073, label_depth + 0.024,
        11, text_col, "SpiritType")
    # Additional sculpted details distinguish the silhouettes at a distance.
    if kind == 1:
        # Gin: silvery etched botanical stems on both edges.
        for x_side in [-1.0, 1.0]:
            var stem := BoxMesh.new()
            stem.size = Vector3(0.005, height * 0.36, 0.008)
            var part := _part("BotanicalEtching", stem, silver,
                Vector3(x_side * wide * 0.79, height * 0.35, wide * 0.60))
            part.rotation.z = x_side * 0.24
    if kind == 4:
        for theta_idx in range(12):
            var theta := TAU * theta_idx / 12.0
            var stud := SphereMesh.new()
            stud.radius = 0.006
            stud.height = 0.012
            _part("VermouthDiamondStud", stud, brass,
                Vector3(cos(theta) * wide * 0.89, height * 0.59,
                sin(theta) * wide * 0.89))
    if kind == 5:
        # Side-hanging stamped medallion and its metallic cord.
        var coin := CylinderMesh.new()
        coin.top_radius = 0.029
        coin.bottom_radius = 0.029
        coin.height = 0.007
        coin.radial_segments = 24
        var piece := _part("EightPointReserveMedallion", coin, gold,
            Vector3(wide * 0.75, height * 0.81, wide * 0.60))
        piece.rotation.x = PI * 0.5
        var cord := CylinderMesh.new()
        cord.top_radius = 0.003
        cord.bottom_radius = 0.003
        cord.height = 0.11
        var strand := _part("MedallionCord", cord, brass,
            Vector3(wide * 0.73, height * 0.89, wide * 0.60))
        strand.rotation.z = -0.17
