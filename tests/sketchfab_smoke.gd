extends SceneTree

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    # The static import cleanup must work even inside an invisible standby
    # room and must not hide a mesh with a different transform or material.
    var model := Node3D.new()
    model.visible = false
    root.add_child(model)
    var mesh := ArrayMesh.new()
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var first := MeshInstance3D.new()
    first.mesh = mesh
    model.add_child(first)
    var duplicate := MeshInstance3D.new()
    duplicate.mesh = mesh
    model.add_child(duplicate)
    var distinct := MeshInstance3D.new()
    distinct.mesh = mesh
    distinct.position.z = 0.1
    model.add_child(distinct)
    var cache := preload("res://gameplay/runtime_asset_cache.gd")
    cache.stabilize_imported_model(model)
    if not first.visible or duplicate.visible or not distinct.visible:
        push_error("Static imported depth cleanup changed nonduplicate geometry or skipped standby")
        model.free()
        quit(1)
        return
    model.free()
    var scene: PackedScene = load("res://gameplay/casino/main.tscn")
    if scene == null:
        push_error("Main hall scene is missing")
        quit(1)
        return
    var world: Node3D = scene.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    await process_frame
    var layer: Node3D = world.get_node_or_null("SketchfabFurniture") as Node3D
    if layer == null:
        push_error("Sketchfab furniture layer is missing")
        quit(1)
        return
    # Generated instances and permanently authored editor instances share
    # the same metadata/collision contract, but have different parents.
    var placed_models := layer.get_node_or_null("EditableImportedModels") as Node3D
    if placed_models == null:
        placed_models = layer
    # Unlike the three gameplay roulette wheels, the retro hero is optional:
    # the level designer can remove that imported model in gameplay/casino/main.tscn.
    var authored_retro := 0
    for item in placed_models.get_children():
        if str(item.get_meta("source_asset", "")) == "retro_slot_machine":
            authored_retro += 1
    if authored_retro > 1 or int(layer.get("replaced_slots")) != authored_retro \
            or int(layer.get("replaced_roulette")) < 3 \
            or int(layer.get("replaced_blackjack")) < 1 \
            or int(layer.get("poker_props_placed")) != 1:
        push_error("Sketchfab model counters disagree with saved furniture")
        quit(1)
        return
    for asset in ["retro_slot_machine", "roulette_table", "blackjack_table", "poker_set"]:
        if asset == "retro_slot_machine" and authored_retro == 0:
            continue
        var match_found := false
        for node in placed_models.get_children():
            if node.get_meta("source_asset", "") == asset:
                match_found = true
                if asset != "poker_set" and asset != "roulette_table" \
                        and node.get_node_or_null("FurnitureCollider") == null:
                    push_error("Sketchfab furniture missing collision: " + asset)
                    quit(1)
                    return
                if asset == "blackjack_table":
                    var body := node.get_node_or_null("FurnitureCollider") as StaticBody3D
                    if body == null or body.get_child_count() != 1:
                        push_error("Blackjack must use one cheap collision shape")
                        quit(1)
                        return
                    var collider := body.get_child(0) as CollisionShape3D
                    if collider == null or not collider.shape is ConvexPolygonShape3D:
                        push_error("Blackjack still uses expensive triangle physics")
                        quit(1)
                        return
                    if (collider.shape as ConvexPolygonShape3D).points.size() != 16:
                        push_error("Blackjack collider is no longer the 16-point tabletop prism")
                        quit(1)
                        return
                if asset == "roulette_table":
                    if node.get_meta("placement_type", "") != "roulette_wheel":
                        push_error("Roulette model must now be the resized wheel")
                        quit(1)
                        return
                    if node.position.y < 1.00:
                        push_error("Roulette wheel is still lying on the floor")
                        quit(1)
                        return
        if not match_found:
            push_error("Source model not actually placed: " + asset)
            quit(1)
            return
    var roulette_tables := 0
    var raised_retro := 0
    for node in placed_models.get_children():
        if node.get_meta("furniture_kind", "") == "roulette_table":
            roulette_tables += 1
            var tabletop: StaticBody3D = node.get_node_or_null("SolidTableTopCollider") as StaticBody3D
            if tabletop == null or tabletop.get_child_count() == 0:
                push_error("New roulette table is missing a full sized solid top")
                quit(1)
                return
        elif node.name.begins_with("RetroSlotPlinth"):
            raised_retro += 1
            if node.get_node_or_null("PedestalBodyCollider") == null:
                push_error("Raised slot platform is missing its collision")
                quit(1)
                return
    if roulette_tables != 3 or raised_retro != authored_retro:
        push_error("Missing roulette tables or retro slot platform: tables=%d platform=%d" % [roulette_tables, raised_retro])
        quit(1)
        return
    if ResourceLoader.exists("res://casino2_preview.tscn"):
        push_error("Unused Casino_2 preview scene must be removed")
        quit(1)
        return
    world.queue_free()
    print("Casino Anomaly Sketchfab model smoke PASS")
    quit(0)
