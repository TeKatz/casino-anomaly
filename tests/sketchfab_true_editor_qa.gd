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
    print("Casino Anomaly true Godot editor model preview QA PASS")
    quit(0)
