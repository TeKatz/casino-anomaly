extends SceneTree

# One-time migration of the authoritative 3D level from procedural generators
# to regular, editable children in main.tscn. Never run this over a hand-edited
# populated scene: the guard preserves all later designer modifications.
func _initialize() -> void:
    call_deferred("_bake")


func _own_recursive(node: Node, scene_root: Node) -> int:
    node.owner = scene_root
    var count := 1
    for child in node.get_children():
        count += _own_recursive(child, scene_root)
    return count


func _bake() -> void:
    var loaded := load("res://main.tscn") as PackedScene
    if loaded == null:
        push_error("Could not load main.tscn for authoring migration")
        quit(1)
        return
    var world := loaded.instantiate() as Node3D
    if world == null:
        push_error("Main scene must be Node3D")
        quit(1)
        return
    if (world.get_node("Architecture") as Node3D).get_child_count() > 0:
        print("Room already authored; not rebaking over artist changes")
        quit(0)
        return

    # Bypass Sketchfab's runtime replacements, and FX particles, while
    # leaving every original slot, table and model-placement marker intact.
    world.set_meta("_baking_room", true)
    root.add_child(world)
    await process_frame
    await process_frame
    await process_frame

    # Static atmosphere originally existed ONLY while running the game:
    # explicitly construct and serialize neon strips, illuminated frames,
    # and the four decorative spotlights. Runtime particles stay procedural.
    var fx := world.get_node("CasinoAtmosphere") as Node3D
    fx.call("_architecture")
    fx.call("_spot", "CatHighlight", Vector3(-8.45, 4.7, -3.25),
        Vector3(-8.45, 1.0, -1.04), 1.05)
    fx.call("_spot", "ChessHighlight", Vector3(-28.6, 4.7, -4.25),
        Vector3(-28.6, 0.65, -2.75), 0.85)
    fx.call("_spot", "HorseHighlight", Vector3(-44.1, 4.8, -3.1),
        Vector3(-44.2, 1.1, -1.35), 1.05)
    fx.call("_spot", "BustHighlight", Vector3(-3.5, 4.8, 10.8),
        Vector3(-2.75, 1.35, 12.15), 0.75)

    var owned := 0
    for section_name in [
        "Architecture", "RedCarpet", "SlotMachines", "GamingTables",
        "CornerBar", "Decor", "Lighting", "CasinoAtmosphere"
    ]:
        var section := world.get_node(section_name) as Node3D
        if section == null:
            push_error("Required section missing: " + section_name)
            quit(1)
            return
        for child in section.get_children():
            if child.owner == null:
                owned += _own_recursive(child, world)
            else:
                # Slot/table anchors are saved in the existing file, but
                # their generated geometry and physics are not yet owned.
                for generated in child.get_children():
                    if generated.owner == null:
                        owned += _own_recursive(generated, world)

    # Bake only model-support structures. The 41 imported glTF previews
    # remain linked to their existing authoring anchors and are not copied
    # into main.tscn as huge duplicate meshes.
    var models := world.get_node("ModelInteriors") as Node3D
    for child in models.get_children():
        if child.owner != null:
            continue
        if child.name.begins_with("BustPedestal_") or                 child.name.begins_with("DecorativeStatuePlinth_") or                 child.name == "BarCabinetPlinth" or                 child.name.begins_with("ChandelierWarmLight_"):
            owned += _own_recursive(child, world)

    if fx.get_node_or_null("EntrySignTop") == null or             models.get_node_or_null("BustPedestal_01") == null or             world.get_node_or_null("Decor/Plant_00/PlantPot_00") == null or             world.get_node_or_null("SlotMachines/Slot_02/PlayerStool") == null:
        push_error("Baked environment missing required visual/editable props")
        quit(1)
        return

    # Do not accidentally serialize the character after several frames of
    # gravity, or the eye camera after its breathing interpolation.
    var player := world.get_node("Player") as CharacterBody3D
    player.position = Vector3(0, 1.02, 11.1)
    player.velocity = Vector3.ZERO
    var camera := world.get_node("Player/Camera3D") as Camera3D
    camera.position = Vector3(0, 0.55, 0)
    camera.rotation = Vector3.ZERO

    world.remove_meta("_baking_room")
    var authored := PackedScene.new()
    var packed_error := authored.pack(world)
    if packed_error != OK:
        push_error("PackedScene failed: %s" % packed_error)
        quit(1)
        return
    var saved_error := ResourceSaver.save(authored, "res://main.tscn")
    if saved_error != OK:
        push_error("Could not save authored casino: %s" % saved_error)
        quit(1)
        return
    print("Casino Anomaly full room authoring BAKE PASS: ", owned,
        " generated nodes became saved editor nodes")
    quit(0)
