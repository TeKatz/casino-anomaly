extends SceneTree

# Targeted regressions from the ten screenshots in the November visual pass.
# These checks examine instantiated meshes, collisions and world placements.
func _initialize() -> void:
    call_deferred("_run")

func _bad(message: String) -> void:
    push_error("Casino screenshot QA: " + message)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://gameplay/casino/main.tscn")
    if packed == null:
        _bad("Casino hall cannot be loaded")
        return
    var hall: Node3D = packed.instantiate() as Node3D
    root.add_child(hall)
    await process_frame
    await process_frame

    var architecture: Node3D = hall.get_node_or_null("Architecture") as Node3D
    var decor: Node3D = hall.get_node_or_null("Decor") as Node3D
    var bar: Node3D = hall.get_node_or_null("CornerBar") as Node3D
    var models: Node3D = hall.get_node_or_null("ModelInteriors") as Node3D
    var gaming: Node3D = hall.get_node_or_null("GamingTables") as Node3D
    if architecture == null or decor == null or bar == null or models == null or gaming == null:
        _bad("Required scene sections do not exist")
        return

    # Entry lettering faces the actual approach, and the obsolete SLOTS
    # label no longer hangs across its upper luminous border.
    var entrance: Label3D = architecture.get_node_or_null("Sign_CASINO_ANOMALY") as Label3D
    if entrance == null or absf(wrapf(entrance.rotation.y - PI, -PI, PI)) > 0.0001:
        _bad("The casino entrance lettering is mirrored from the hallway")
        return
    if entrance.position.y > 4.4 or decor.get_node_or_null("Sign_SLOTS") != null:
        _bad("The entrance heading still overlaps its luminous frame")
        return

    # No obsolete white globe/chain placeholders are allowed around the
    # imported, independent chandelier model.
    for child in decor.get_children():
        if child.name.begins_with("Chandelier"):
            _bad("A primitive chandelier globe or chain is still rendered")
            return
    for child in bar.get_children():
        if child.name.begins_with("Pendant"):
            _bad("A white placeholder globe or rod remains above the bar")
            return

    # A designer may edit or remove individual shelf boards. Every visible
    # authored shelf must have precisely one matching collision at its
    # current position, and no collision from a deleted shelf may remain.
    var rear: StaticBody3D = bar.get_node_or_null("BarBackboard_Collision") as StaticBody3D
    if rear == null or rear.get_child_count() == 0:
        _bad("Rear bar wood wall does not block players")
        return
    var shelves := 0
    var colliders := 0
    for child in bar.get_children():
        if child is MeshInstance3D and child.name.begins_with("BottleShelf"):
            shelves += 1
            var matching := bar.get_node_or_null(str(child.name) + "_Collision") as StaticBody3D
            var shape_node := matching.get_node_or_null("ShelfShape") as CollisionShape3D if matching != null else null
            if shape_node == null or not (shape_node.shape is BoxShape3D) \
                    or matching.position.distance_to(child.position) > 0.01:
                _bad("An edited bar shelf has missing or misaligned gameplay collision")
                return
        elif child is StaticBody3D and child.get_meta("collision_for", "") == "BottleShelf":
            colliders += 1
    if shelves == 0 or colliders != shelves:
        _bad("Bar shelf collision count no longer matches the saved shelf layout")
        return

    var sign_panel: MeshInstance3D = bar.get_node_or_null("BarSignPanel") as MeshInstance3D
    var sign_text: Label3D = bar.get_node_or_null("Sign_MIDNIGHT_BAR") as Label3D
    if sign_panel == null or sign_text == null:
        _bad("Bar signage objects are missing")
        return
    # A designer may move the sign panel. The text should still be near its
    # backing panel and horizontally centered, but not at a fixed world point.
    if absf(sign_text.position.x - sign_panel.position.x) > 0.12             or absf(sign_text.position.y - sign_panel.position.y) > 0.12             or int(sign_text.horizontal_alignment) != HORIZONTAL_ALIGNMENT_CENTER:
        _bad("MIDNIGHT BAR text is no longer aligned to its sign panel")
        return

    # Moving the cat away from Cards7 restores a separate viewing position,
    # while the small side table keeps all its seats within the floor band.
    var cat: Node3D = null
    for child in models.get_children():
        if child.get_meta("placement_group", "") == "ConcreteCatDisplay":
            cat = child as Node3D
            break
    var game: Node3D = gaming.get_node_or_null("Cards7") as Node3D
    if cat == null or game == null:
        _bad("Cat landmark or nearby cards table is missing")
        return
    var cat_floor := Vector2(cat.position.x, cat.position.z)
    var table_floor := Vector2(game.position.x, game.position.z)
    # Preserve editor placements, including moving the cat to a
    # completely different part of the room. Only reject real overlap.
    if cat_floor.distance_to(table_floor) < 0.8:
        _bad("Cat statue intersects the card table")
        return
    if game.scale.x > 0.70 or game.scale.z > 0.70:
        _bad("Cards7 still has full-size stools in a narrow wall aisle")
        return

    hall.queue_free()
    print("Casino Anomaly ten screenshot layout QA PASS")
    root.get_node("AudioDirector").call("request_quit")
