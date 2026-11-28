extends SceneTree

# Ensures the three exact Poly Haven texture sets are on the correct
# architectural surfaces, not merely present as unused files.

func _initialize() -> void:
    call_deferred("_run")

func _bad(reason: String) -> void:
    push_error("Casino finish test: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://gameplay/casino/main.tscn")
    if scene == null:
        _bad("Main scene missing")
        return
    var world: Node3D = scene.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    await process_frame

    var structure: Node3D = world.get_node_or_null("Architecture") as Node3D
    if structure == null:
        _bad("Architectural section missing")
        return
    for item in [
        ["assets/materials/lower_wall_material.tres", "wooden_panels"],
        ["assets/materials/upper_wall_material.tres", "artist-authored upper wall"],
        ["assets/materials/ceiling_material.tres", "roof_planks"]
    ]:
        var material: StandardMaterial3D = load("res://" + item[0]) as StandardMaterial3D
        # A texture may remain assigned while an artist intentionally
        # disables its normal-map contribution in the material inspector.
        # Guard the actual PBR source assets without overriding that choice.
        if material == null or material.albedo_texture == null \
                or material.normal_texture == null \
                or material.roughness_texture == null:
            _bad("Missing PBR texture maps for " + item[1])
            return

    var upper: MeshInstance3D = structure.get_node_or_null("NorthWestWall") as MeshInstance3D
    var ceiling: MeshInstance3D = structure.get_node_or_null("WestCeiling") as MeshInstance3D
    var lower: MeshInstance3D = structure.get_node_or_null("WoodWainscoting") as MeshInstance3D
    for entry in [
        [upper, "upper wall", 10.0],
        [ceiling, "roof_planks", 10.0],
        [lower, "wooden_panels", 2.0]
    ]:
        var node: MeshInstance3D = entry[0]
        if node == null:
            _bad("A configured wall or ceiling mesh is missing: " + entry[1])
            return
        var active: StandardMaterial3D = node.get_active_material(0) as StandardMaterial3D
        if active == null or active.albedo_texture == null \
                or active.uv1_scale.x < float(entry[2]):
            _bad("New " + entry[1] + " material is not correctly tiled on " + node.name)
            return
        if active.normal_texture == null or active.roughness_texture == null:
            _bad("Surface lost PBR normal/roughness maps: " + node.name)
            return

    var bar: Node3D = world.get_node_or_null("CornerBar") as Node3D
    var roulette: Node3D = world.get_node_or_null("SketchfabFurniture") as Node3D
    if bar == null or roulette == null:
        _bad("Bar and roulette sections missing")
        return
    var bar_pbr := 0
    for item in bar.get_children():
        if item is MeshInstance3D and (
                item.name.begins_with("BarRunFacingApproach")
                or item.name.begins_with("BarCounterFrontInset")):
            var mat: StandardMaterial3D = item.get_active_material(0) as StandardMaterial3D
            if mat == null or mat.albedo_texture == null:
                _bad("Bar surface missing PBR wood: " + item.name)
                return
            bar_pbr += 1
    if bar_pbr != 2:
        _bad("Countertop or bar panel missing")
        return
    var pillars := 0
    for item in structure.get_children():
        if item is MeshInstance3D and item.get_meta("decor_type", "") == "pillar":
            var mat: StandardMaterial3D = item.get_active_material(0) as StandardMaterial3D
            if mat == null or mat.albedo_texture == null:
                _bad("Pillar missing smoke speckled veneer")
                return
            pillars += 1
    if pillars < 20:
        _bad("Missing pillar veneer")
        return
    # Converted editor scenes keep the same cabinets under a permanent
    # authoring group instead of spawning them directly under the script.
    var roulette_models := roulette.get_node_or_null("EditableImportedModels") as Node3D
    if roulette_models == null:
        roulette_models = roulette
    var roulette_tables := 0
    for item in roulette_models.get_children():
        if item.get_meta("furniture_kind", "") == "roulette_table":
            roulette_tables += 1
            var top: MeshInstance3D = item.get_node_or_null("SolidTableTop") as MeshInstance3D
            if top == null or top.position.y > 0.89:
                _bad("Roulette table still too high")
                return
            var mat: StandardMaterial3D = top.get_active_material(0) as StandardMaterial3D
            if mat == null or mat.albedo_texture == null:
                _bad("Roulette table missing wood_table_001")
                return
    if roulette_tables != 3:
        _bad("Expected three roulette cabinets")
        return
    world.queue_free()
    print("Casino Anomaly architectural PBR finishes PASS")
    quit(0)
