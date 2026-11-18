extends SceneTree

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var scene: PackedScene = load("res://main.tscn")
    if scene == null:
        push_error("Main hall scene is missing")
        quit(1)
        return
    var world: Node3D = scene.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    await process_frame
    var layer: Node3D = world.get_node_or_null("SketchfabFurniture") as Node3D
    if layer == null or layer.get("replaced_slots") != 1 \
            or layer.get("replaced_roulette") < 3 \
            or layer.get("replaced_blackjack") < 1 \
            or layer.get("poker_props_placed") != 1:
        push_error("Sketchfab model replacements are incomplete")
        quit(1)
        return
    for asset in ["retro_slot_machine", "roulette_table", "blackjack_table", "poker_set"]:
        var match_found := false
        for node in layer.get_children():
            if node.get_meta("source_asset", "") == asset:
                match_found = true
                if asset != "poker_set" and node.get_node_or_null("FurnitureCollider") == null:
                    push_error("Sketchfab furniture missing collision: " + asset)
                    quit(1)
                    return
        if not match_found:
            push_error("Source model not actually placed: " + asset)
            quit(1)
            return
    if load("res://casino2_preview.tscn") == null:
        push_error("Separate Casino_2 preview scene is missing")
        quit(1)
        return
    world.queue_free()
    print("Casino Anomaly Sketchfab model smoke PASS")
    quit(0)
