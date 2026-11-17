extends SceneTree

func _initialize() -> void:
    call_deferred("_run_smoke")

func _run_smoke() -> void:
    var menu: PackedScene = load("res://menu.tscn")
    var scene: PackedScene = load("res://main.tscn")
    if menu == null or scene == null:
        push_error("Casino Anomaly scenes missing")
        quit(1)
        return
    var world: Node3D = scene.instantiate() as Node3D
    root.add_child(world)
    var player: Camera3D = world.get_node_or_null("Player/Camera3D") as Camera3D
    var architecture: Node3D = world.get_node_or_null("Architecture") as Node3D
    var carpet: Node3D = world.get_node_or_null("RedCarpet") as Node3D
    var slots: Node3D = world.get_node_or_null("SlotMachines") as Node3D
    var bar: Node3D = world.get_node_or_null("CornerBar") as Node3D
    var tables: Node3D = world.get_node_or_null("GamingTables") as Node3D
    var lounge: Node3D = world.get_node_or_null("Lounge") as Node3D
    if player == null or architecture == null or carpet == null or slots == null or bar == null or tables == null or lounge == null:
        push_error("Missing functional hall sections")
        quit(1)
        return
    var main_floor: MeshInstance3D = architecture.get_node_or_null("OakMainWing") as MeshInstance3D
    var west_floor: MeshInstance3D = architecture.get_node_or_null("OakWestWing") as MeshInstance3D
    var first_runner: MeshInstance3D = carpet.get_node_or_null("ApproachRunner") as MeshInstance3D
    var bend: MeshInstance3D = carpet.get_node_or_null("TurnRunner") as MeshInstance3D
    var second_runner: MeshInstance3D = carpet.get_node_or_null("WestRunner") as MeshInstance3D
    if main_floor == null or west_floor == null or first_runner == null or bend == null or second_runner == null:
        push_error("The intended left-turn hall or carpet is missing")
        quit(1)
        return
    var oak: StandardMaterial3D = main_floor.get_active_material(0) as StandardMaterial3D
    var jacquard: StandardMaterial3D = first_runner.get_active_material(0) as StandardMaterial3D
    if oak == null or oak.albedo_texture == null or jacquard == null or jacquard.albedo_texture == null or jacquard.normal_texture == null:
        push_error("Poly Haven PBR textures are incomplete")
        quit(1)
        return
    if slots.get_child_count() < 10 or tables.get_child_count() < 4 or lounge.get_child_count() < 10:
        push_error("The visual casino furnishing pass is incomplete")
        quit(1)
        return
    if not bar.has_node("BarRunFacingApproach") or not bar.has_node("BarRunAlongTurn"):
        push_error("The bar must wrap around the left turn")
        quit(1)
        return
    world.queue_free()
    print("Casino Anomaly scenes and PBR floor smoke PASS")
    quit(0)
