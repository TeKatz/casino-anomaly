extends SceneTree
## Editor preview must use the SAME Sketchfab replacements and exact
## authored positions as runtime, but never serialize/import collision
## bodies or permanently hide the placeholders in the saved scene.
const ROOM = preload("res://main.tscn")

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
    var preview := imported.call("create_editor_preview_for_test") as Node3D
    if preview == null or preview.owner != null:
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
    # without reparenting or deleting anything from main.tscn.
    imported.call("clear_editor_preview_for_test")
    if not retro.visible or not tables.get_node("Roulette2").visible:
        _fail("Disabling preview did not restore saved placeholder visibility")
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
    quit(0)
