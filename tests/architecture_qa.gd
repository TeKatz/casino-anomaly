extends SceneTree

# Ensures the three exact Poly Haven texture sets are on the correct
# architectural surfaces, not merely present as unused files.

func _initialize() -> void:
    call_deferred("_run")

func _bad(reason: String) -> void:
    push_error("Casino finish test: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://main.tscn")
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
        ["lower_wall_material.tres", "wooden_panels"],
        ["upper_wall_material.tres", "book_pattern"],
        ["ceiling_material.tres", "roof_planks"]
    ]:
        var material: StandardMaterial3D = load("res://" + item[0]) as StandardMaterial3D
        if material == null or material.albedo_texture == null \
                or not material.normal_enabled or material.normal_texture == null \
                or material.roughness_texture == null:
            _bad("Missing PBR texture maps for " + item[1])
            return

    var upper: MeshInstance3D = structure.get_node_or_null("NorthWestWall") as MeshInstance3D
    var ceiling: MeshInstance3D = structure.get_node_or_null("WestCeiling") as MeshInstance3D
    var lower: MeshInstance3D = structure.get_node_or_null("WoodWainscoting") as MeshInstance3D
    for entry in [
        [upper, "book_pattern", 10.0],
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

    world.queue_free()
    print("Casino Anomaly architectural PBR finishes PASS")
    quit(0)
