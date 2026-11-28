extends SceneTree
## Door E prompt must follow the actual authorable door face, not a tiny
## midpoint aim cone. Reject wrong side, off-door and distant interactions.
const INTRO = preload("res://gameplay/tutorial.tscn")


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("Tutorial door interaction QA: " + why)
    quit(1)


func _run() -> void:
    var room := INTRO.instantiate() as Node3D
    if room == null:
        _fail("Tutorial room missing")
        return
    root.add_child(room)
    await physics_frame
    await physics_frame
    await process_frame
    var door := room.get_node("SideGalleries/EastGallery/AccessBays/MainCasinoEntrance") as Node3D
    var camera := room.get_node("Player/Camera3D") as Camera3D
    var player := room.get_node("Player") as CharacterBody3D
    # Door is rotated in the saved scene; test in its own coordinates.
    player.global_position = door.to_global(Vector3(0.0, 1.24, 3.5))
    camera.look_at(door.to_global(Vector3(0.0, 1.7, 0.0)), Vector3.UP)
    if not bool(room.call("_is_looking_at_door")):
        _fail("Standing in front of and aiming at the door should show E")
        return
    for target in [Vector3(-0.83, 0.6, 0.0), Vector3(0.85, 2.55, 0.0),
            Vector3(0.92, 1.2, 0.0)]:
        camera.look_at(door.to_global(target), Vector3.UP)
        if not bool(room.call("_is_looking_at_door")):
            _fail("Targeting the real door panel edge must still allow E: " + str(target))
            return
    camera.look_at(door.to_global(Vector3(3.5, 1.4, 0.0)), Vector3.UP)
    if bool(room.call("_is_looking_at_door")):
        _fail("Looking beside the doorway should not show E")
        return
    player.global_position = door.to_global(Vector3(0.0, 1.24, 7.5))
    camera.look_at(door.to_global(Vector3(0.0, 1.5, 0.0)), Vector3.UP)
    if bool(room.call("_is_looking_at_door")):
        _fail("Door interaction works from across the whole room")
        return
    player.global_position = door.to_global(Vector3(0.0, 1.24, -1.0))
    camera.look_at(door.to_global(Vector3(0.0, 1.5, 0.0)), Vector3.UP)
    if bool(room.call("_is_looking_at_door")):
        _fail("Door can be activated from the wrong side")
        return
    for gallery in room.get_node("SideGalleries").get_children():
        for bay in gallery.get_node("AccessBays").get_children():
            if bay == door:
                continue
            player.global_position = bay.to_global(Vector3(0,1.02,1.8))
            camera.look_at(bay.to_global(Vector3(0,1.6,0)),Vector3.UP)
            if bool(room.call("_is_looking_at_door")):
                _fail("Reserved construction door is interactable")
                return
    player.global_position = door.to_global(Vector3(0,1.02,2.0))
    camera.look_at(door.to_global(Vector3(0,1.5,0)),Vector3.UP)
    var blocker := StaticBody3D.new()
    room.add_child(blocker)
    blocker.global_position = camera.global_position.lerp(door.to_global(Vector3(0,1.5,0)),0.5)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(0.7,2,0.7)
    collider.shape = shape
    blocker.add_child(collider)
    await physics_frame
    await physics_frame
    if bool(room.call("_is_looking_at_door")):
        _fail("Door can be activated through an obstruction")
        return
    room.queue_free()
    await process_frame
    print("Casino Anomaly tutorial door interaction QA PASS")
    root.get_node("AudioDirector").call("request_quit")
