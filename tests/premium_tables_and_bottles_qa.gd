extends SceneTree
## Three premium authored roulette tables, no flat placeholder betting tiles,
## fitted imported blackjack collision and editable signature bottles.

const ROOM = preload("res://main.tscn")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("Premium gaming furniture QA: " + message)
    quit(1)


func _run() -> void:
    var world := ROOM.instantiate() as Node3D
    if world == null:
        _fail("Cannot instantiate saved casino room")
        return
    root.add_child(world)
    await process_frame
    await process_frame
    var imported := world.get_node_or_null("SketchfabFurniture/EditableImportedModels") as Node3D
    if imported == null:
        _fail("Saved imported furniture section missing")
        return

    var roulette_count := 0
    for table in imported.get_children():
        if str(table.get_meta("furniture_kind", "")) != "roulette_table":
            continue
        roulette_count += 1
        if not str(table.scene_file_path).ends_with("premium_roulette_table.tscn"):
            _fail("An authored roulette cabinet still uses placeholder geometry")
            return
        var top := table.get_node_or_null("SolidTableTop") as MeshInstance3D
        var collider := table.get_node_or_null("SolidTableTopCollider") as StaticBody3D
        if top == null or collider == null or collider.get_child_count() == 0:
            _fail("Premium roulette table lacks solid body or visual tabletop")
            return
        for part in ["BettingFelt", "CarvedTableApron", "PaddedRail_Front",
                "PaddedRail_Back", "WheelAreaInset", "JoinedLowerBeam",
                "DealerChipRack", "BrassBead_Front", "BrassBead_Back"]:
            if table.get_node_or_null(part) == null:
                _fail("Premium roulette detail missing: " + part)
                return
        for n in range(37):
            var name := "BettingZero" if n == 0 else "BettingNumber_%02d" % n
            if table.get_node_or_null(name) == null:
                _fail("The roulette layout is missing number %d" % n)
                return
        if table.get_node_or_null("BettingTile") != null or table.get_node_or_null("GridVertical") != null:
            _fail("A placeholder betting grid survived the premium replacement")
            return
    if roulette_count != 3:
        _fail("Expected three real Roulette tables, got %d" % roulette_count)
        return

    var blackjack := imported.get_node_or_null("SketchfabBlackjack") as Node3D
    var body := blackjack.get_node_or_null("FurnitureCollider") as StaticBody3D if blackjack != null else null
    var collider := body.get_child(0) as CollisionShape3D if body != null and body.get_child_count() > 0 else null
    if collider == null or not (collider.shape is BoxShape3D):
        _fail("Blackjack lost its existing gameplay collision")
        return
    var box := collider.shape as BoxShape3D
    if box.size.y > 0.20 or box.size.x > 2.51 or box.size.z > 1.55             or box.margin > 0.025 or body.position.y < 0.7:
        _fail("Blackjack still has an oversized all-height bounding cube")
        return

    var bar := world.get_node_or_null("CornerBar") as Node3D
    if bar == null:
        _fail("Signature bar missing")
        return
    var bottle_count := 0
    var designs := {}
    # Saved editor layouts may add or remove individual bottles, and may
    # put additional editable bottle instances under another bottle root.
    # Their scene_file_path identifies them without counting mesh parts.
    for child in bar.find_children("Signature_*", "Node3D", true, false):
        if not str(child.name).begins_with("Signature_") or child.scene_file_path == "":
            continue
        designs[str(child.get_meta("bottle_design", ""))] = true
        bottle_count += 1
        if child.scene_file_path == "" or not world.is_editable_instance(child):
            _fail("Bar bottle is not a selectable/editable saved instance: " + child.name)
            return
        var shell := child.get_node_or_null("HandCutGlassShell") as MeshInstance3D
        if shell == null or shell.mesh == null or shell.owner != world:
            _fail("Bar bottle glass must be an owned, saved and editable scene mesh: " + child.name)
            return
    if bottle_count < 6 or designs.size() != 6:
        _fail("The editable signature bar must retain all six bottle designs")
        return
    world.queue_free()
    await process_frame
    print("Casino Anomaly premium tables and editable bottles QA PASS")
    quit(0)
