extends SceneTree

func _initialize() -> void:
    var menu: PackedScene = load("res://menu.tscn")
    var room: PackedScene = load("res://main.tscn")
    if menu == null or room == null:
        push_error("Required Casino Anomaly scenes are missing")
        quit(1)
        return
    var world: Node3D = room.instantiate() as Node3D
    var floor: MeshInstance3D = world.get_node_or_null("Floor/WoodFloor") as MeshInstance3D
    var player: Camera3D = world.get_node_or_null("Player/Camera3D") as Camera3D
    if floor == null or player == null or floor.mesh == null:
        push_error("Casino Anomaly scene structure changed unexpectedly")
        quit(1)
        return
    var material: StandardMaterial3D = floor.get_active_material(0) as StandardMaterial3D
    if material == null or material.albedo_texture == null or material.normal_texture == null:
        push_error("Poly Haven floor material is incomplete")
        quit(1)
        return
    world.free()
    print("Casino Anomaly scenes and PBR floor smoke PASS")
    quit(0)
