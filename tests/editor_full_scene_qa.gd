extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("Casino editor full-scene QA: " + message)
    quit(1)


func _run() -> void:
    var loaded := load("res://main.tscn") as PackedScene
    if loaded == null:
        _fail("main.tscn missing")
        return
    var world := loaded.instantiate() as Node3D
    var architecture := world.get_node_or_null("Architecture") as Node3D
    var slots := world.get_node_or_null("SlotMachines") as Node3D
    var decor := world.get_node_or_null("Decor") as Node3D
    var models := world.get_node_or_null("ModelInteriors") as Node3D
    var fx := world.get_node_or_null("CasinoAtmosphere") as Node3D
    if architecture == null or slots == null or decor == null or models == null or fx == null:
        _fail("Missing scene sections")
        return
    if architecture.get_child_count() < 20:
        _fail("Architecture is still only an editor-generated preview")
        return
    if not fx.has_node("EntrySignTop") or not fx.has_node("BarSignTop")             or not fx.has_node("EastCove") or not fx.has_node("SouthCove"):
        _fail("Ceiling and signage neon is missing from saved scene")
        return
    if fx.find_children("*", "SpotLight3D", true, false).size() != 4:
        _fail("Four authorable spotlights must be saved")
        return
    var bust := models.get_node_or_null("BustPedestal_01") as StaticBody3D
    if bust == null or bust.get_node_or_null("PolishedStonePedestal") == null             or bust.get_node_or_null("BustPedestalCollision") == null:
        _fail("Busting statue pedestal has no saved material or collision")
        return
    var plant := decor.get_node_or_null("Plant_00") as Node3D
    if plant == null or plant.get_node_or_null("PlantPot_00") == null             or plant.get_node_or_null("PlantPot_00_Collision") == null             or plant.get_node_or_null("PlantFoliage_00") == null:
        _fail("Plant meshes and collider are not under one saved editor node")
        return
    var slot := slots.get_node_or_null("Slot_02") as Node3D
    var stool := slot.get_node_or_null("PlayerStool") as Node3D if slot != null else null
    if stool == null or stool.get_node_or_null("StoolSeat") == null             or stool.get_node_or_null("StoolSeat_Collision") == null:
        _fail("Independent slot stool was not serialized")
        return
    var original_plant := plant.position
    var original_stool := stool.position
    var original_neon := (fx.get_node("EntrySignTop") as Node3D).position
    plant.position += Vector3(0.25, 0, 0)
    stool.position += Vector3(-0.25, 0, 0)
    (fx.get_node("EntrySignTop") as Node3D).position += Vector3(0, 0.10, 0)
    var models_before := models.get_child_count()
    var fx_static_before := fx.find_children("*", "SpotLight3D", true, false).size()
    root.add_child(world)
    await process_frame
    await process_frame
    await process_frame
    if not plant.position.is_equal_approx(original_plant + Vector3(0.25, 0, 0))             or not stool.position.is_equal_approx(original_stool + Vector3(-0.25, 0, 0))             or not (fx.get_node("EntrySignTop") as Node3D).position.is_equal_approx(original_neon + Vector3(0, 0.10, 0)):
        _fail("Runtime generator overwrote designer edits")
        return
    if fx.find_children("*", "SpotLight3D", true, false).size() != fx_static_before:
        _fail("Duplicate spotlights were spawned")
        return
    if models.get_child_count() != models_before:
        _fail("Duplicate saved model support/placement nodes were spawned")
        return
    if (world.get_node("SlotMachines") as Node3D).get_child_count() != 9:
        _fail("Runtime Sketchfab hero replacement failed")
        return
    print("Casino Anomaly complete Godot editor scene QA PASS")
    quit(0)
