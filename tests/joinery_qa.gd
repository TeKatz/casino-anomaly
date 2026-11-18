extends SceneTree

# The screenshot fixes are geometry/material regressions: verify actual
# instantiated joins, not only the presence of source files or scripts.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("Casino joinery QA: " + message)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://main.tscn")
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
            "res://" + source_name + "_material.tres") as StandardMaterial3D
        if mat == null or mat.albedo_texture == null                 or mat.normal_texture == null or mat.roughness_texture == null:
            _fail("Missing full Poly Haven PBR map set: " + source_name)
            return
        if not mat.albedo_texture.resource_path.contains(source_name):
            _fail("Wrong Poly Haven material source: " + source_name)
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
        elif mesh.name == "PillarBase":
            base_count += 1
            var foot := mesh.mesh as BoxMesh
            if foot == null or absf(mesh.position.y - foot.size.y * 0.5 - 0.005) > 0.011:
                _fail("Column foot fails to touch the floor")
                return
        elif mesh.name == "PillarCapital":
            capital_count += 1
            var crown := mesh.mesh as BoxMesh
            if crown == null or mesh.position.y + crown.size.y * 0.5 < 5.985:
                _fail("Column capital fails to join the ceiling")
                return
        elif mesh.name == "PillarGoldRing":
            _fail("Old coplanar pillar rings still present")
            return

    if pillar_count < 20 or base_count != pillar_count or capital_count != pillar_count:
        _fail("Column bases and capitals must match each existing pillar")
        return
    if wood_beam_count != 18:
        _fail("Expected 18 wood ceiling/wall beams, got " + str(wood_beam_count))
        return

    var rail_count := 0
    var piping_count := 0
    for item in carpet.get_children():
        if not (item is MeshInstance3D):
            continue
        var mesh: MeshInstance3D = item as MeshInstance3D
        var mat: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
        if mesh.name.contains("Border"):
            if mesh.name.contains("Gold"):
                piping_count += 1
                if mat == null or mat.albedo_texture == null                         or not mat.albedo_texture.resource_path.contains("bi_stretch"):
                    _fail("Gold border is missing the requested Bi Stretch texture")
                    return
            elif mesh.name != "ApproachRunner" and mesh.name != "TurnRunner"                     and mesh.name != "WestRunner":
                rail_count += 1
                if mat == null or mat.albedo_texture == null                         or not mat.albedo_texture.resource_path.contains("herringbone_parquet"):
                    _fail("Parquet rail missing requested PBR texture")
                    return
                if mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
                    _fail("Rounded rail has no mesh surface")
                    return
        elif mesh.name.contains("GoldPiping"):
            piping_count += 1
            if mat == null or mat.albedo_texture == null                     or not mat.albedo_texture.resource_path.contains("bi_stretch"):
                _fail("Textured piping missing")
                return
    # Two border pieces use End names, not Border. Check them directly.
    for name in ["EntryBorderEnd", "WestBorderEnd"]:
        if not carpet.has_node(name):
            _fail("The carpet lacks a closed end: " + name)
            return
    if rail_count != 6 or piping_count != 6:
        _fail("Expected 6 rounded wood rails and 6 gold fabric trims, found %d and %d" % [
            rail_count, piping_count])
        return
    for name in ["ApproachBorderDark", "WestBorderDark", "EndTrim"]:
        if carpet.has_node(name):
            _fail("Old box-based carpet frame still present: " + name)
            return

    world.queue_free()
    print("Casino Anomaly joinery and PBR texture QA PASS")
    quit(0)
