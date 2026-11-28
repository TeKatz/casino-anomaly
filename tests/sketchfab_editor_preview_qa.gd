extends SceneTree
## Editor preview must use the SAME Sketchfab replacements and exact
## authored positions as runtime, but never serialize/import collision
## bodies or permanently hide the placeholders in the saved scene.
const ROOM = preload("res://gameplay/casino/main.tscn")
# Verify the editor save hook compiles in CI even though the editor GUI is
# not running in the headless test process.
const EDITOR_SAVE_GUARD = preload("res://addons/casino_model_preview/plugin.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("Sketchfab editor preview QA: " + reason)
    quit(1)

func _run() -> void:
    var world := ROOM.instantiate() as Node3D
    if world == null:
        _fail("Casino main scene cannot be instantiated")
        return
    var imported := world.get_node_or_null("SketchfabFurniture")
    var slots := world.get_node_or_null("SlotMachines") as Node3D
    var tables := world.get_node_or_null("GamingTables") as Node3D
    if imported == null or slots == null or tables == null:
        _fail("Authored furniture sections are missing")
        return
    var retro := slots.get_node_or_null("Slot_01") as Node3D
    if retro == null:
        _fail("Original hero placeholder is missing")
        return
    # After the editor converts the temporary models into authored scene
    # instances, there must be no transient preview at all. Test those
    # permanent children and the unchanged runtime replacement contract.
    var authored := imported.get_node_or_null("EditableImportedModels") as Node3D
    if authored != null:
        # A saved scene is authoritative. The old imported retro hero may
        # have been deliberately removed, while the three roulette wheels,
        # blackjack table and poker props remain required.
        var expected := {
            "retro_slot_machine": 0,
            "roulette_table": 3,
            "blackjack_table": 1,
            "poker_set": 1
        }
        var found := {
            "retro_slot_machine": 0,
            "roulette_table": 0,
            "blackjack_table": 0,
            "poker_set": 0
        }
        var cabinets := 0
        var plinths := 0
        for item in authored.get_children():
            var slug := str(item.get_meta("source_asset", ""))
            if found.has(slug):
                found[slug] = int(found[slug]) + 1
            if str(item.get_meta("furniture_kind", "")) == "roulette_table":
                cabinets += 1
                if item.get_node_or_null("SolidTableTopCollider") == null:
                    _fail("Authored roulette table has no physical tabletop")
                    return
            if item.name.begins_with("RetroSlotPlinth"):
                plinths += 1
                if item.get_node_or_null("PedestalBodyCollider") == null:
                    _fail("Authored retro pedestal lacks collision")
                    return
        var saved_retro := int(found["retro_slot_machine"])
        expected["retro_slot_machine"] = saved_retro
        if saved_retro > 1 or found != expected or cabinets != 3 or plinths != saved_retro:
            _fail("Authored furniture count is incorrect: %s, cabinets=%d, plinths=%d" % [str(found), cabinets, plinths])
            return
        if retro.visible or tables.get_node("Roulette2").visible:
            _fail("Authored imported models overlap visible placeholders")
            return
        var authored_count := authored.get_child_count()
        root.add_child(world)
        await process_frame
        await process_frame
        if bool(imported.call("has_active_editor_preview")) \
                or authored.get_child_count() != authored_count \
                or imported.get_child_count() != 1:
            _fail("Runtime unexpectedly recreated the saved imported models")
            return
        if int(imported.get("replaced_slots")) != saved_retro \
                or int(imported.get("replaced_roulette")) != 3 \
                or int(imported.get("replaced_blackjack")) != 1 \
                or int(imported.get("poker_props_placed")) != 1:
            _fail("Saved furniture metadata did not update runtime counters")
            return
        print("Casino Anomaly Sketchfab editor preview QA PASS")
        world.queue_free()
        root.get_node("AudioDirector").call("request_quit")
        return

    var preview := imported.call("create_editor_preview_for_test") as Node3D
    if preview == null or preview.owner != null \
            or not bool(imported.call("has_active_editor_preview")):
        _fail("Editor preview must exist as an unsaved, ownerless node")
        return
    var roles := {"retro_slot_machine": 0, "roulette_table": 0, "blackjack_table": 0, "poker_set": 0}
    var roulette_cabinets := 0
    var plinths := 0
    for part in preview.get_children():
        var slug := str(part.get_meta("source_asset", ""))
        if roles.has(slug):
            roles[slug] = int(roles[slug]) + 1
        if str(part.get_meta("furniture_kind", "")) == "roulette_table":
            roulette_cabinets += 1
            if part.get_node_or_null("SolidTableTop") == null:
                _fail("Preview roulette cabinet lacks its real tabletop")
                return
        if part.name.begins_with("RetroSlotPlinth"):
            plinths += 1
        if part.find_children("*", "CollisionShape3D", true, false).size() > 0:
            _fail("Editor-only preview must not create physics collisions")
            return
    if roles["retro_slot_machine"] != 1 or roles["roulette_table"] != 3 \
            or roles["blackjack_table"] != 1 or roles["poker_set"] != 1 \
            or roulette_cabinets != 3 or plinths != 1:
        _fail("Editor preview does not reproduce all six imported assets: " + str(roles))
        return
    if retro.visible or tables.get_node("Roulette2").visible:
        _fail("Editor preview still overlaps authored placeholders")
        return
    # Clear preview and confirm original authoring nodes are restored
    # without reparenting or deleting anything from gameplay/casino/main.tscn.
    imported.call("clear_editor_preview_for_test")
    if not retro.visible or not tables.get_node("Roulette2").visible:
        _fail("Disabling preview did not restore saved placeholder visibility")
        return
    if bool(imported.call("has_active_editor_preview")):
        _fail("Preview state was not cleared before scene save")
        return
    if imported.get_children(true).size() != 0:
        _fail("An internal preview model was accidentally left in the scene")
        return
    # Normal run must still install the identical imported replacements.
    root.add_child(world)
    await process_frame
    await process_frame
    if int(imported.get("replaced_slots")) != 1 \
            or int(imported.get("replaced_roulette")) != 3 \
            or int(imported.get("replaced_blackjack")) != 1:
        _fail("Editor preview changed the existing game replacement logic")
        return
    print("Casino Anomaly Sketchfab editor preview QA PASS")
    world.queue_free()
    root.get_node("AudioDirector").call("request_quit")
