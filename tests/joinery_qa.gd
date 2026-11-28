extends SceneTree

# The screenshot fixes are geometry/material regressions: verify actual
# instantiated joins, not only the presence of source files or scripts.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("Casino joinery QA: " + message)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://gameplay/casino/main.tscn")
    if scene == null:
        _fail("Main scene is missing")
        return
    var world: Node3D = scene.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    await process_frame
    var architecture: Node3D = world.get_node_or_null("Architecture") as Node3D
    var carpet: Node3D = world.get_node_or_null("RedCarpet") as Node3D
    if architecture == null or carpet == null:
        _fail("Architectural or carpet node missing")
        return

    for source_name in [
        "brown_planks_05", "herringbone_parquet", "bi_stretch"
    ]:
        var mat: StandardMaterial3D = load(
            "res://assets/materials/" + source_name + "_material.tres") as StandardMaterial3D
        if mat == null or mat.albedo_texture == null                 or mat.normal_texture == null or mat.roughness_texture == null:
            _fail("Missing full Poly Haven PBR map set: " + source_name)
            return
        # The authored parquet uses the Oak Wood Planks albedo on the
        # existing Herringbone roughness/normal maps. Preserve that deliberate
        # mixed PBR material, while keeping strict sources for other finishes.
        var albedo_source: String = "oak_wood_planks" if source_name == "herringbone_parquet" else str(source_name)
        if not mat.albedo_texture.resource_path.contains(albedo_source):
            _fail("Wrong authored Poly Haven albedo: " + source_name)
            return

    var pillar_count := 0
    var base_count := 0
    var capital_count := 0
    var wood_beam_count := 0
    for item in architecture.get_children():
        if not (item is MeshInstance3D):
            continue
        var mesh: MeshInstance3D = item as MeshInstance3D
        var active: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
        var is_beam := mesh.name.contains("CeilingTrim")             or mesh.name.contains("CeilingGoldBeam")             or mesh.name.ends_with("_Crown")
        if is_beam:
            wood_beam_count += 1
            if active == null or active.albedo_texture == null                     or not active.albedo_texture.resource_path.contains("brown_planks_05"):
                _fail("Upper beam lost its exact wood texture: " + mesh.name)
                return
            var body := mesh.mesh as BoxMesh
            if body == null or mesh.position.y + body.size.y * 0.5 < 5.985:
                _fail("Upper beam stops below the ceiling: " + mesh.name)
                return
        if mesh.get_meta("decor_type", "") == "pillar":
            pillar_count += 1
        elif mesh.name.begins_with("PillarBase") and not mesh.name.begins_with("PillarBaseCollar"):
            base_count += 1
            var foot := mesh.mesh as BoxMesh
            if foot == null or absf(mesh.position.y - foot.size.y * 0.5 - 0.005) > 0.011:
                _fail("Column foot fails to touch the floor")
                return
        elif mesh.name.begins_with("PillarCapital") and not mesh.name.begins_with("PillarCapitalCollar"):
            capital_count += 1
            var crown := mesh.mesh as BoxMesh
            if crown == null or mesh.position.y + crown.size.y * 0.5 < 5.985:
                _fail("Column capital fails to join the ceiling")
                return
        elif mesh.name == "PillarGoldRing":
            _fail("Old coplanar pillar rings still present")
            return

    # Pillar bases are optional decorative nodes in the visual editor.
    # Their surviving geometry is validated above; missing bases are valid.
    # Extra bases or missing structural capitals remain suspicious.
    if pillar_count < 20 or base_count > pillar_count or capital_count != pillar_count:
        _fail("Column cores/bases/capitals invalid: cores=%d, bases=%d, capitals=%d" % [
            pillar_count, base_count, capital_count])
        return
    # Three long pieces were duplicates of wall crowns (depth fighting).
    # Six uniquely butt-jointed crowns and nine transverse ceiling members
    # remain; none may use the old longitudinal CeilingGoldBeam name.
    if wood_beam_count != 15:
        _fail("Expected 15 non-overlapping wood ceiling/wall members, got " + str(wood_beam_count))
        return
    for item in architecture.get_children():
        if item.name.begins_with("CeilingGoldBeam"):
            _fail("Duplicate longitudinal beam still overlaps its wall crown")
            return
    var north: MeshInstance3D = architecture.get_node_or_null("NorthWestWall_Crown") as MeshInstance3D
    var far: MeshInstance3D = architecture.get_node_or_null("FarExitWall_Crown") as MeshInstance3D
    var south: MeshInstance3D = architecture.get_node_or_null("SouthWestWall_Crown") as MeshInstance3D
    if north == null or far == null or south == null:
        _fail("Trimmed wall crown joinery is missing")
        return
    var north_mesh := north.mesh as BoxMesh
    var far_mesh := far.mesh as BoxMesh
    var south_mesh := south.mesh as BoxMesh
    if north_mesh == null or far_mesh == null or south_mesh == null:
        _fail("Wall crowns lost their BoxMesh profiles")
        return
    if north_mesh.size.x > 51.58 or far_mesh.size.z > 12.58 or south_mesh.size.x > 39.78:
        _fail("Wall crown at the room end penetrates a perpendicular crown")
        return

    # One continuous closed wood profile and ONE matching gold inlay
    # replace six independent rails and six overlapping box trims.
    var timber: MeshInstance3D = carpet.get_node_or_null("CarpetPerimeterWood") as MeshInstance3D
    var inlay: MeshInstance3D = carpet.get_node_or_null("CarpetPerimeterGold") as MeshInstance3D
    if timber == null or inlay == null:
        _fail("Continuous L-shaped carpet edging is missing")
        return
    var wood_mat: StandardMaterial3D = timber.get_active_material(0) as StandardMaterial3D
    var gold_mat: StandardMaterial3D = inlay.get_active_material(0) as StandardMaterial3D
    # Scene-authored perimeter materials may preserve the original
    # Herringbone albedo even when the shared .tres template switches to oak.
    # Both versions keep full PBR maps and are valid authored choices.
    if wood_mat == null or wood_mat.albedo_texture == null \
            or wood_mat.normal_texture == null or wood_mat.roughness_texture == null:
        _fail("Beveled timber edging is missing its PBR texture maps")
        return
    var edging_albedo: String = wood_mat.albedo_texture.resource_path
    if not edging_albedo.contains("herringbone_parquet") \
            and not edging_albedo.contains("oak_wood_planks"):
        _fail("Beveled timber edging has an unexpected albedo texture: " + edging_albedo)
        return
    if gold_mat == null or gold_mat.albedo_texture == null             or not gold_mat.albedo_texture.resource_path.contains("bi_stretch"):
        _fail("Flush gold fabric inlay must retain the Bi Stretch maps")
        return

    var actual_count := 0
    for item in carpet.get_children():
        if item is MeshInstance3D:
            actual_count += 1
            if not item.name in [
                "ApproachRunner", "TurnRunner", "WestRunner",
                "CarpetPerimeterWood", "CarpetPerimeterGold"
            ]:
                _fail("Obsolete overlapping carpet trim remains: " + item.name)
                return
    if actual_count != 5:
        _fail("Expected 3 carpet patches and 2 continuous perimeter meshes")
        return

    var timber_arrays: Array = timber.mesh.surface_get_arrays(0)
    var timber_points: PackedVector3Array = timber_arrays[Mesh.ARRAY_VERTEX]
    # 6 connected edges * 10 closed bevel faces * 2 triangles * 3 corners.
    if timber_points.size() != 360:
        _fail("Beveled timber mesh has unexpected face topology")
        return
    var upward_top_faces := 0
    for i in range(0, timber_points.size(), 3):
        var p: Vector3 = timber_points[i]
        var q: Vector3 = timber_points[i + 1]
        var r: Vector3 = timber_points[i + 2]
        var normal: Vector3 = (q - p).cross(r - p)
        if normal.length_squared() <= 0.000000001:
            _fail("Timber contains a zero-area face")
            return
        if absf(p.y - 0.077) < 0.0001                 and absf(q.y - 0.077) < 0.0001                 and absf(r.y - 0.077) < 0.0001:
            upward_top_faces += 1
            if normal.y <= 0.0:
                _fail("Timber top face is back-facing at some camera angles")
                return
    if upward_top_faces != 12:
        _fail("Expected two outward-facing flat top triangles per perimeter edge")
        return

    var inlay_arrays: Array = inlay.mesh.surface_get_arrays(0)
    var inlay_points: PackedVector3Array = inlay_arrays[Mesh.ARRAY_VERTEX]
    if inlay_points.size() != 36:
        _fail("Gold inlay must consist of six connected strips")
        return
    for i in range(0, inlay_points.size(), 3):
        var a: Vector3 = inlay_points[i]
        var b: Vector3 = inlay_points[i + 1]
        var c: Vector3 = inlay_points[i + 2]
        if (b - a).cross(c - a).y <= 0.0:
            _fail("A gold inlay face disappears from above at certain angles")
            return
        if absf(a.y - 0.0785) > 0.0001:
            _fail("Gold inlay no longer rests flush on the timber top")
            return
    # Vertex identity at each of the six corners, including the entry and
    # concave L-bend: both edges MUST share exactly the same endpoints.
    for edge_i in range(6):
        var next_i := (edge_i + 1) % 6
        var end_inner: Vector3 = inlay_points[edge_i * 6 + 1]
        var end_outer: Vector3 = inlay_points[edge_i * 6 + 2]
        var start_inner: Vector3 = inlay_points[next_i * 6]
        var start_outer: Vector3 = inlay_points[next_i * 6 + 5]
        if end_inner.distance_to(start_inner) > 0.00001                 or end_outer.distance_to(start_outer) > 0.00001:
            _fail("Gold inlay contains an open or doubled corner")
            return

    world.queue_free()
    print("Casino Anomaly joinery and PBR texture QA PASS")
    root.get_node("AudioDirector").call("request_quit")
