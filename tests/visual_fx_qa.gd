extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://main.tscn")
    if packed == null:
        push_error("Casino scene missing")
        quit(1)
        return
    var hall: Node3D = packed.instantiate() as Node3D
    root.add_child(hall)
    await process_frame
    await process_frame
    var fx: Node3D = hall.get_node_or_null("CasinoAtmosphere") as Node3D
    var env: WorldEnvironment = hall.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if fx == null or env == null or env.environment == null or not env.environment.glow_enabled:
        push_error("Missing visual environment")
        quit(1)
        return
    if not fx.has_node("EntrySignTop") or not fx.has_node("BarSignTop"):
        push_error("Missing luminous casino signage")
        quit(1)
        return
    if fx.find_children("*", "SpotLight3D", true, false).size() != 4:
        push_error("Display lighting invalid")
        quit(1)
        return
    var spill_count := fx.find_children("SlotSpill*", "OmniLight3D", true, false).size()
    if spill_count < 4 or spill_count > 6:
        push_error("Screen spill light budget exceeded")
        quit(1)
        return
    if fx.find_children("*", "CollisionObject3D", true, false).size() != 0:
        push_error("Decorative FX may not add collisions")
        quit(1)
        return
    print("Casino Anomaly visual FX QA PASS")
    hall.queue_free()
    quit(0)
