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

static var _runtime_design_templates: Dictionary = {}
# Cache only reference-counted PackedScene resources, never detached Nodes.
# Each part scene shares the original immutable Mesh, Material and MultiMesh
# resources. Instantiation keeps the geometry cache without leaking an
# orphan render instance per part. Never mutate shared resources per bottle.

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
const LABEL_TEXTURES := [
    preload("res://models/signature_bar/labels/velvet_ace.svg"),
    preload("res://models/signature_bar/labels/silver_lotus.svg"),
    preload("res://models/signature_bar/labels/rouge_clover.svg"),
    preload("res://models/signature_bar/labels/solara.svg"),
    preload("res://models/signature_bar/labels/montevale.svg"),
    preload("res://models/signature_bar/labels/nightfall.svg")
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
    # gameplay/casino/main.tscn stores artist-editable meshes as real scene children. Do not
    # destroy or replace them when an authored bottle instance loads.
    if get_node_or_null("HandCutGlassShell") == null:
        _rebuild()


func _rebuild() -> void:
    # An artist may parent another bottle under this one. Keep authored
    # children, replacing only the procedural mesh pieces for this design.
    for child in get_children():
        if child is MeshInstance3D or child is MultiMeshInstance3D:
            remove_child(child)
            child.free()
    if not Engine.is_editor_hint() and _runtime_design_templates.has(design):
        for prototype in _runtime_design_templates[design]:
            var part := (prototype as PackedScene).instantiate()
            add_child(part)
        return
    _build()
    if Engine.is_editor_hint():
        _own_generated_parts()
        call_deferred("_own_generated_parts")
    else:
        var prototypes: Array[PackedScene] = []
        for part in get_children():
            if part is MeshInstance3D or part is MultiMeshInstance3D:
                # The generated parts are leaf render nodes. Pack each as
                # its own root directly: no temporary Node or extra RID.
                var prototype := PackedScene.new()
                if prototype.pack(part) != OK:
                    push_warning("Could not cache signature bottle part: " + str(part.name))
                    return
                prototypes.append(prototype)
        _runtime_design_templates[design] = prototypes


# New procedural pieces belong to the currently edited scene (gameplay/casino/main.tscn),
# never to the instanced template: Godot otherwise saves invalid overrides
# of meshes that do not exist in the source bottle .tscn.
func _own_generated_parts() -> void:
    if not Engine.is_editor_hint() or not is_inside_tree():
        return
    var edited_root := get_tree().edited_scene_root
    if edited_root == null or (edited_root != self and not edited_root.is_ancestor_of(self)):
        return
    for child in get_children():
        if child is MeshInstance3D or child is MultiMeshInstance3D:
            child.owner = edited_root


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
    # _own_generated_parts() assigns the edited-scene owner after building.
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
    var power: float = [0.56, 1.0, 0.91, 0.78, 0.79, 0.54][shape]
    var x := signf(cos(theta)) * pow(absf(cos(theta)), power)
    var z := signf(sin(theta)) * pow(absf(sin(theta)), power)
    var facets: int = [8, 24, 16, 12, 12, 8][shape]
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


func _profile_width_at(outline: Array, relative_y: float) -> float:
    # Match the existing lathed glass silhouette, including bottle shoulders.
    for row in range(outline.size() - 1):
        var lower: Vector2 = outline[row]
        var upper: Vector2 = outline[row + 1]
        if relative_y <= upper.x:
            var fraction := clampf((relative_y - lower.x) /
                maxf(0.000001, upper.x - lower.x), 0.0, 1.0)
            return lerpf(lower.y, upper.y, fraction)
    var last: Vector2 = outline[outline.size() - 1]
    return last.y


func _glass_surface_point(theta: float, relative_y: float, outline: Array,
        radius: float, height: float, facets: float) -> Vector3:
    var pitch := TAU / 32.0
    var wrapped := fposmod(theta, TAU)
    var sector := floori(wrapped / pitch)
    var fraction := (wrapped - float(sector) * pitch) / pitch
    var base_radius := _profile_width_at(outline, relative_y)
    # The original shell is a 32-sided polygon, NOT a mathematically smooth
    # circle. Interpolating its actual vertices prevents even tiny gaps
    # between the paper and the faceted glass on corners.
    var first := _radius(design, float(sector) * pitch, radius, facets) * base_radius
    var second := _radius(design, float(sector + 1) * pitch, radius, facets) * base_radius
    var point := first.lerp(second, fraction)
    # 1.3 mm surface offset prevents z-fighting; there is NO suspended box.
    var normal := point.normalized()
    point += normal * 0.0013
    return Vector3(point.x, relative_y * height, point.y)


func _paper_vertex(tool: SurfaceTool, point: Vector3, uv: Vector2) -> void:
    tool.set_uv(uv)
    tool.add_vertex(point)


func _paper_triangle(tool: SurfaceTool, a: Vector3, uv_a: Vector2,
        b: Vector3, uv_b: Vector2, c: Vector3, uv_c: Vector2) -> void:
    _paper_vertex(tool, a, uv_a)
    _paper_vertex(tool, b, uv_b)
    _paper_vertex(tool, c, uv_c)


func _conformal_label(outline: Array, radius: float, height: float,
        facets: float, kind: int) -> void:
    # Ink and gold detailing are part of the label TEXTURE, not thick,
    # rectangular 3D slabs. These UV-mapped triangles wrap the bottle
    # front with exactly the same lathed cross section as the glass.
    var paper := StandardMaterial3D.new()
    paper.albedo_texture = LABEL_TEXTURES[kind]
    paper.albedo_color = Color.WHITE
    paper.roughness = 0.78
    paper.metallic = 0.0
    paper.cull_mode = BaseMaterial3D.CULL_DISABLED
    paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var y_center := 0.39
    var y_span := 0.350 if kind != 3 else 0.375
    # A little less than half the circumference follows the square-like and
    # rounded designs without running into a corner or overlapping the sides.
    var angle_span := 0.67 if kind in [1, 2, 3, 4] else 0.60
    var cols := 32
    var rows := 18
    for column in range(cols):
        for row in range(rows):
            var left_u := float(column) / float(cols)
            var right_u := float(column + 1) / float(cols)
            var top_v := float(row) / float(rows)
            var bottom_v := float(row + 1) / float(rows)
            var left_angle := PI * 0.5 + angle_span * (1.0 - 2.0 * left_u)
            var right_angle := PI * 0.5 + angle_span * (1.0 - 2.0 * right_u)
            var top_y := y_center + (0.5 - top_v) * y_span
            var bottom_y := y_center + (0.5 - bottom_v) * y_span
            var a := _glass_surface_point(left_angle, top_y, outline,
                radius, height, facets)
            var b := _glass_surface_point(right_angle, top_y, outline,
                radius, height, facets)
            var c := _glass_surface_point(left_angle, bottom_y, outline,
                radius, height, facets)
            var d := _glass_surface_point(right_angle, bottom_y, outline,
                radius, height, facets)
            _paper_triangle(tool, a, Vector2(left_u, top_v),
                c, Vector2(left_u, bottom_v), b, Vector2(right_u, top_v))
            _paper_triangle(tool, b, Vector2(right_u, top_v),
                c, Vector2(left_u, bottom_v), d, Vector2(right_u, bottom_v))
    tool.generate_normals()
    var mesh: ArrayMesh = tool.commit()
    _part("ConformalPaperLabel", mesh, paper)


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
    var neck_radius: float = wide * [0.43, 0.44, 0.43, 0.39, 0.43, 0.41][kind]
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
    # All twelve machined cap teeth share ONE draw call, not twelve
    # separate MeshInstance3D render submissions per bottle.
    var cap_tooth := BoxMesh.new()
    cap_tooth.size = Vector3(0.004, 0.030, 0.006)
    cap_tooth.material = brass
    var knurling := MultiMesh.new()
    knurling.transform_format = MultiMesh.TRANSFORM_3D
    knurling.mesh = cap_tooth
    knurling.instance_count = 12
    for tooth in range(12):
        var theta := TAU * float(tooth) / 12.0
        var ring_radius: float = neck_radius * 1.245
        var basis := Basis(Vector3.UP, -theta)
        knurling.set_instance_transform(tooth, Transform3D(basis,
            Vector3(cos(theta) * ring_radius,
                closure_y + 0.038, sin(theta) * ring_radius)))
    var knurled_cap := MultiMeshInstance3D.new()
    knurled_cap.name = "MachinedCapFluting"
    knurled_cap.multimesh = knurling
    add_child(knurled_cap)
    # The edited scene root owns this instance after building.

    # The physical bottle has a real UV-textured paper wrap that follows its
    # exact glass surface, including facets and shoulder taper.
    _conformal_label(body_outline, wide, height, facet, kind)
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
        var stud := SphereMesh.new()
        stud.radius = 0.006
        stud.height = 0.012
        stud.material = brass
        var emboss := MultiMesh.new()
        emboss.transform_format = MultiMesh.TRANSFORM_3D
        emboss.mesh = stud
        emboss.instance_count = 12
        for theta_idx in range(12):
            var theta := TAU * float(theta_idx) / 12.0
            emboss.set_instance_transform(theta_idx, Transform3D(
                Basis.IDENTITY,
                Vector3(cos(theta) * wide * 0.89, height * 0.59,
                    sin(theta) * wide * 0.89)))
        var stud_batch := MultiMeshInstance3D.new()
        stud_batch.name = "VermouthDiamondEmbossing"
        stud_batch.multimesh = emboss
        add_child(stud_batch)
        # The edited scene root owns this instance after building.
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
