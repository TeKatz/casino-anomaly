extends SceneTree
## Source-derived 3D cards are imported as separate glTFs (not billboards).
## Each authored card stays individually movable in the editor.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("Casino playing cards QA: " + reason)
    quit(1)


func _run() -> void:
    var index_data := FileAccess.get_file_as_string("res://models/playing_cards/manifest.json")
    var manifest = JSON.parse_string(index_data)
    if typeof(manifest) != TYPE_DICTIONARY:
        _fail("Missing card extraction manifest")
        return
    if (manifest as Dictionary).get("faces", []).size() != 52:
        _fail("All 52 original card faces must remain available")
        return
    if not ResourceLoader.exists("res://models/playing_cards/individual/card_00.gltf") \
            or not ResourceLoader.exists("res://models/playing_cards/individual/card_51.gltf"):
        _fail("The independent first/last source glTF is missing")
        return

    var scene := load("res://models/playing_cards/individual/card_12.gltf") as PackedScene
    if scene == null:
        _fail("Could not load a separated source card glTF")
        return
    var source := scene.instantiate()
    root.add_child(source)
    var meshes: Array[MeshInstance3D] = []
    for found in source.find_children("*", "MeshInstance3D", true, false):
        meshes.append(found as MeshInstance3D)
    if meshes.size() != 3:
        _fail("Source card must preserve 3 separate volumetric faces/edge meshes")
        return
    var surface_count := 0
    var texturized := 0
    for piece in meshes:
        var render_mesh := piece.mesh
        if render_mesh == null:
            _fail("Extracted playing card contains empty geometry")
            return
        surface_count += render_mesh.get_surface_count()
        for surface_id in range(render_mesh.get_surface_count()):
            var mat := render_mesh.surface_get_material(surface_id) as BaseMaterial3D
            if mat != null and mat.albedo_texture != null:
                texturized += 1
    if surface_count != 3 or texturized < 2:
        _fail("Source face/back card textures were not preserved")
        return
    source.queue_free()

    var main := load("res://gameplay/casino/main.tscn") as PackedScene
    if main == null:
        _fail("Main room does not import with the new cards")
        return
    var world := main.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    # These cards used to pass a geometry-only test while buried under the
    # felt of an INVISIBLE blackjack table. Verify actual visible tables
    # and world-space heights, and reject the five white placeholder boxes.
    var card_nodes: Array[Node3D] = []
    for node in world.find_children("*", "Node3D", true, false):
        if node.has_meta("source_card_index"):
            card_nodes.append(node as Node3D)
    if card_nodes.size() != 16:
        _fail("Expected 16 individually editable original card instances, found %d" % card_nodes.size())
        return
    var counts := {"Cards5": 0, "Cards7": 0}
    var facedown_count := 0
    for card in card_nodes:
        var table := card.get_parent() as Node3D
        if table == null or not counts.has(str(table.name)) or not table.is_visible_in_tree():
            _fail("Playing card has no visible parent table: " + str(card.get_path()))
            return
        counts[str(table.name)] += 1
        var felt := table.get_node_or_null("FeltSurface") as MeshInstance3D
        if felt == null or not (felt.mesh is CylinderMesh):
            _fail("Playing card parent has no physical table surface")
            return
        var cylinder := felt.mesh as CylinderMesh
        var tabletop_y := felt.global_position.y + cylinder.height * 0.5
        if card.global_position.y < tabletop_y + 0.001 \
                or card.global_position.y > tabletop_y + 0.025:
            _fail("Card is inside, underneath or floating over the felt: %s (%.4f vs %.4f)" \
                % [card.name, card.global_position.y, tabletop_y])
            return
        if card.scale.x < 0.14:
            _fail("An original card is too small to read on its table")
            return
        if not card.is_visible_in_tree():
            _fail("A card is hidden by its ancestor or visibility setting")
            return
        var visible_meshes := card.find_children("*", "MeshInstance3D", true, false)
        if visible_meshes.size() != 3:
            _fail("Visible table card lost its 3D front, back or edge")
            return
        var textured_faces := 0
        for piece in visible_meshes:
            var render_mesh := (piece as MeshInstance3D).mesh
            if render_mesh == null:
                continue
            for surface_id in range(render_mesh.get_surface_count()):
                var mat := render_mesh.surface_get_material(surface_id) as BaseMaterial3D
                if mat != null and mat.albedo_texture != null:
                    textured_faces += 1
        if textured_faces < 2:
            _fail("Visible playing card has no textured front and back")
            return
        if bool(card.get_meta("face_down", false)):
            facedown_count += 1
    if counts["Cards5"] != 8 or counts["Cards7"] != 8 or facedown_count != 2:
        _fail("Original cards not distributed across two visible gaming tables")
        return
    for table_name in ["Blackjack3", "Cards5", "Cards7"]:
        var table := world.get_node("GamingTables/" + table_name) as Node3D
        if table.get_node_or_null("CardBack") != null:
            _fail("Original white card placeholder was not deleted")
            return
        for child in table.get_children():
            if not (child is MeshInstance3D) or not ((child as MeshInstance3D).mesh is BoxMesh):
                continue
            if absf((child as MeshInstance3D).position.y - 1.082) < 0.001:
                _fail("A flat white placeholder card remains on " + table_name)
                return
    world.queue_free()
    await process_frame
    print("Casino Anomaly extracted playing cards QA PASS")
    quit(0)
