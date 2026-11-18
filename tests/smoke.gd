extends SceneTree

func _initialize() -> void:
    call_deferred("_run_smoke")

func _run_smoke() -> void:
    var menu: PackedScene = load("res://menu.tscn")
    var scene: PackedScene = load("res://main.tscn")
    if menu == null or scene == null:
        push_error("Casino Anomaly scenes missing")
        quit(1)
        return
    var world: Node3D = scene.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    await process_frame
    var player: Camera3D = world.get_node_or_null("Player/Camera3D") as Camera3D
    var architecture: Node3D = world.get_node_or_null("Architecture") as Node3D
    var carpet: Node3D = world.get_node_or_null("RedCarpet") as Node3D
    var slots: Node3D = world.get_node_or_null("SlotMachines") as Node3D
    var bar: Node3D = world.get_node_or_null("CornerBar") as Node3D
    var tables: Node3D = world.get_node_or_null("GamingTables") as Node3D
    var lounge: Node3D = world.get_node_or_null("Lounge") as Node3D
    if player == null or architecture == null or carpet == null or slots == null or bar == null or tables == null or lounge == null:
        push_error("Missing functional hall sections")
        quit(1)
        return
    var main_floor: MeshInstance3D = architecture.get_node_or_null("OakMainWing") as MeshInstance3D
    var west_floor: MeshInstance3D = architecture.get_node_or_null("OakWestWing") as MeshInstance3D
    var first_runner: MeshInstance3D = carpet.get_node_or_null("ApproachRunner") as MeshInstance3D
    var bend: MeshInstance3D = carpet.get_node_or_null("TurnRunner") as MeshInstance3D
    var second_runner: MeshInstance3D = carpet.get_node_or_null("WestRunner") as MeshInstance3D
    if main_floor == null or west_floor == null or first_runner == null or bend == null or second_runner == null:
        push_error("The intended left-turn hall or carpet is missing")
        quit(1)
        return
    var oak: StandardMaterial3D = main_floor.get_active_material(0) as StandardMaterial3D
    var jacquard: StandardMaterial3D = first_runner.get_active_material(0) as StandardMaterial3D
    if oak == null or oak.albedo_texture == null or jacquard == null or jacquard.albedo_texture == null or jacquard.normal_texture == null:
        push_error("Poly Haven PBR textures are incomplete")
        quit(1)
        return
    # Sketchfab furniture replaces prototype nodes; count replacements as
    # furnishings, not as missing old whitebox meshes.
    var sketchfab: Node3D = world.get_node_or_null("SketchfabFurniture") as Node3D
    var slot_replacements := 0
    var table_replacements := 0
    if sketchfab != null:
        slot_replacements = int(sketchfab.get("replaced_slots"))
        table_replacements = int(sketchfab.get("replaced_roulette")) + int(sketchfab.get("replaced_blackjack"))
    var total_slots := slots.get_child_count() + slot_replacements
    var total_tables := tables.get_child_count() + table_replacements
    if total_slots < 10 or total_tables < 6 or lounge.get_child_count() < 35:
        push_error("Casino furnishing incomplete: slots=%d, tables=%d, lounge=%d" % [total_slots, total_tables, lounge.get_child_count()])
        quit(1)
        return
    if not bar.has_node("BarRunFacingApproach") or not bar.has_node("BarRunAlongTurn"):
        push_error("The bar must wrap around the left turn")
        quit(1)
        return
    if not bar.has_node("BarRoundedCorner") or not bar.has_node("BarCounterSideInset"):
        push_error("The corner bar counter must be visibly continuous and rounded")
        quit(1)
        return
    var west_aabb: AABB = west_floor.get_aabb()
    var runner_aabb: AABB = second_runner.get_aabb()
    if west_aabb.size.x < 39.9 or runner_aabb.size.x < 43.2:
        push_error("The second leg must retain its doubled length and extended carpet")
        quit(1)
        return
    var far_wall: MeshInstance3D = architecture.get_node_or_null("FarExitWall") as MeshInstance3D
    if far_wall == null or far_wall.position.x > -45.9:
        push_error("The exit end wall was not relocated with the extended wing")
        quit(1)
        return
    var models: Node3D = world.get_node_or_null("ModelInteriors") as Node3D
    if models == null or models.get("successful_model_ids").size() != 10 or int(models.get("placed_model_count")) < 29:
        push_error("All 10 requested Poly Haven models must be placed in the room")
        quit(1)
        return
    for asset_id in [
        "Chandelier_02", "Chandelier_01", "brass_candleholders",
        "marble_bust_01", "fancy_picture_frame_01",
        "security_camera_01", "wine_bottles_01",
        "bar_chair_round_01", "CoffeeCart_01", "modern_wooden_cabinet"
    ]:
        if not bool(models.get("successful_model_ids").has(asset_id)):
            push_error("Missing imported model: " + asset_id)
            quit(1)
            return
    # Material tangent basis is essential for correct normalmapped PBR floors.
    for floor in [main_floor, west_floor, first_runner, bend, second_runner]:
        var surface_arrays: Array = floor.mesh.surface_get_arrays(0)
        var tangents: PackedFloat32Array = surface_arrays[Mesh.ARRAY_TANGENT]
        var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
        if tangents.size() != vertices.size() * 4:
            push_error("Floor surface missing valid normal-map tangents: " + floor.name)
            quit(1)
            return

    var interior: Node3D = models
    var count_busts := 0
    var count_stools := 0
    var count_candles := 0
    var wine_on_shelf := false
    var coffee_correct := false
    var cabinet_correct := false
    for item in interior.get_children():
        var placement: String = str(item.get_meta("placement_group", ""))
        if placement == "MarbleBust":
            count_busts += 1
            if absf(absf(item.rotation.y) - PI) > 0.05:
                push_error("A marble bust still faces the wall")
                quit(1)
                return
        elif placement == "CounterStool" or placement == "SideStool":
            count_stools += 1
            var cushion: MeshInstance3D = item.get_node_or_null("VelvetSeatCushion") as MeshInstance3D
            if cushion == null or cushion.position.y < 1.0:
                push_error("An imported barstool is missing its full-height upholstered seat")
                quit(1)
                return
            if item.get_node_or_null("ModelSolidBody") == null:
                push_error("An imported stool has no collision")
                quit(1)
                return
        elif placement == "BarWine":
            push_error("Flickering labelled bottles remain on the bar counter")
            quit(1)
            return
        elif placement == "ShelfWine":
            wine_on_shelf = true
        elif placement == "SingleBrassCandleholder":
            count_candles += 1
            var actual_candles := 0
            for piece in item.find_children("*", "MeshInstance3D", true, false):
                actual_candles += 1
                if not piece.name.begins_with("brass_candleholder_03"):
                    push_error("Candleholder trio was not split into individual meshes")
                    quit(1)
                    return
            if actual_candles != 1:
                push_error("A coffee table must have precisely one candleholder model")
                quit(1)
                return
        elif placement == "CoffeeServiceCart":
            coffee_correct = absf(absf(item.rotation.y) - PI) < 0.05
        elif placement == "BarServiceCabinet":
            var body: StaticBody3D = item.get_node_or_null("ModelSolidBody") as StaticBody3D
            if body != null:
                var shape_node: CollisionShape3D = body.get_node_or_null("ModelCollisionShape") as CollisionShape3D
                var shape: BoxShape3D = shape_node.shape as BoxShape3D if shape_node != null else null
                cabinet_correct = item.position.y >= 0.24 and shape != null and shape.size.x >= 3.0
    if count_busts != 2 or count_stools != 10 or count_candles != 4 or not wine_on_shelf \
        or not coffee_correct or not cabinet_correct or interior.get_node_or_null("BarCabinetPlinth") == null:
        push_error("Interior QA failed: busts=%d stools=%d candles=%d shelfWine=%s coffee=%s cabinet=%s plinth=%s" % [count_busts, count_stools, count_candles, str(wine_on_shelf), str(coffee_correct), str(cabinet_correct), str(interior.get_node_or_null("BarCabinetPlinth") != null)])
        quit(1)
        return

    world.queue_free()
    print("Casino Anomaly scenes and PBR floor smoke PASS")
    quit(0)
