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

    var main := load("res://main.tscn") as PackedScene
    if main == null:
        _fail("Main room does not import with the new cards")
        return
    var world := main.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    var group := world.get_node_or_null("PlayingCardDecor") as Node3D
    if group == null:
        _fail("Missing authored PlayingCardDecor wrapper")
        return
    var card_nodes: Array[Node3D] = []
    for item in group.get_children():
        if item is Node3D and item.has_meta("source_card_index"):
            card_nodes.append(item as Node3D)
    if card_nodes.size() != 16:
        _fail("Expected 16 individually editable wrapper nodes, found %d" % card_nodes.size())
        return
    for card in card_nodes:
        if card.get_node_or_null("OriginalMesh") == null:
            _fail("Authored card lost its original extracted glTF geometry")
            return
    var lounge_count := 0
    var blackjack_count := 0
    var facedown_count := 0
    for card in card_nodes:
        if not card.has_meta("source_card_index"):
            _fail("A 3D table card is missing its authored material index")
            return
        if card.scale.x < 0.09:
            _fail("An extracted card was incorrectly scaled")
            return
        if card.position.z > -5.0:
            lounge_count += 1
        else:
            blackjack_count += 1
        if bool(card.get_meta("face_down", false)):
            facedown_count += 1
    if lounge_count != 4 or blackjack_count != 12 or facedown_count != 2:
        _fail("Card distribution across the blackjack and lounge tables changed")
        return
    world.queue_free()
    await process_frame
    print("Casino Anomaly extracted playing cards QA PASS")
    quit(0)
