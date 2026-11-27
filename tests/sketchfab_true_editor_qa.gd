extends SceneTree
## Unlike the standard SceneTree regression suite, this test is launched
## with --editor. It verifies @tool _ready and the actual internal preview,
## not just the public test helper.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("Casino true editor preview QA: " + reason)
    quit(1)

func _run() -> void:
    if not Engine.is_editor_hint():
        _fail("Run this test with --editor to cover @tool initialization")
        return
    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        _fail("Cannot load main.tscn in editor mode")
        return
    var world := packed.instantiate() as Node3D
    if world == null:
        _fail("No authoring scene")
        return
    root.add_child(world)
    for i in range(5):
        await process_frame
    var imported := world.get_node_or_null("SketchfabFurniture")
    # A converted Godot authoring scene has real saved furniture, so the
    # legacy transient-preview assertion must not fire.
    var authored: Node3D = null
    if imported != null:
        authored = imported.get_node_or_null("EditableImportedModels") as Node3D
    if authored != null:
        if bool(imported.call("has_active_editor_preview")):
            _fail("Converted scene unexpectedly creates an internal duplicate")
            return
        var roles := {"retro_slot_machine": 0, "roulette_table": 0,
            "blackjack_table": 0, "poker_set": 0}
        var cabinets := 0
        for item in authored.get_children():
            var source := str(item.get_meta("source_asset", ""))
            if roles.has(source):
                roles[source] = int(roles[source]) + 1
            if str(item.get_meta("furniture_kind", "")) == "roulette_table":
                cabinets += 1
        # The permanent authored scene can intentionally omit the retro
        # hero; transient previews of older procedural rooms still need it.
        if int(roles["retro_slot_machine"]) > 1 or roles["roulette_table"] != 3 \
                or roles["blackjack_table"] != 1 or roles["poker_set"] != 1 \
                or cabinets != 3:
            _fail("Authored imported furniture missing in the editor: " + str(roles))
            return
        var original_saved := world.get_node_or_null("SlotMachines/Slot_01") as Node3D
        if original_saved == null or original_saved.visible:
            _fail("Converted slot model overlaps its procedural placeholder")
            return
        world.queue_free()
        await process_frame
        await process_frame
        if is_instance_valid(world):
            _fail("Editor QA fixture was not freed")
            return
        if not await _wait_for_editor_idle():
            _fail("Editor filesystem scan did not finish")
            return
        print("Casino Anomaly true Godot editor model preview QA PASS")
        quit(0)
        return
    if imported == null or not imported.has_method("has_active_editor_preview") \
            or not bool(imported.call("has_active_editor_preview")):
        _fail("@tool editor _ready did not create the transient imported preview")
        return
    var role_counts := {"retro_slot_machine": 0, "roulette_table": 0,
        "blackjack_table": 0, "poker_set": 0}
    var cabinets := 0
    for child in imported.get_children(true):
        if child.name != "_EditorOnlyImportedFurniturePreview":
            continue
        if child.owner != null:
            _fail("Preview was incorrectly made a persisted scene child")
            return
        for model in child.get_children():
            var source_asset := str(model.get_meta("source_asset", ""))
            if role_counts.has(source_asset):
                role_counts[source_asset] += 1
            if str(model.get_meta("furniture_kind", "")) == "roulette_table":
                cabinets += 1
    if role_counts["retro_slot_machine"] != 1 \
            or role_counts["roulette_table"] != 3 \
            or role_counts["blackjack_table"] != 1 \
            or role_counts["poker_set"] != 1 or cabinets != 3:
        _fail("Editor loaded without expected replacement models: " + str(role_counts))
        return
    var original := world.get_node_or_null("SlotMachines/Slot_01") as Node3D
    if original == null or original.visible:
        _fail("Editor-only placeholder is not hidden")
        return
    world.queue_free()
    await process_frame
    await process_frame
    if is_instance_valid(world):
        _fail("Editor QA fixture was not freed")
        return
    if not await _wait_for_editor_idle():
        _fail("Editor filesystem scan did not finish")
        return
    print("Casino Anomaly true Godot editor model preview QA PASS")
    quit(0)


func _wait_for_editor_idle() -> bool:
    # Quitting a real editor while its initial filesystem scan is still
    # running leaves editor-owned viewport/text/texture RIDs behind.
    var filesystem := EditorInterface.get_resource_filesystem()
    if filesystem == null:
        return false
    var deadline := Time.get_ticks_msec() + 20000
    while filesystem.is_scanning():
        if Time.get_ticks_msec() >= deadline:
            return false
        await process_frame
    await process_frame
    await process_frame
    return true
