extends SceneTree
## Tutorial spatial composition QA.
## Grounding and wall-face offsets are checked against authored geometry, not
## screenshots or hand-wavy tolerances. Models remain editable in a subscene.
const INTRO = preload("res://gameplay/tutorial.tscn")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("Casino Anomaly tutorial set dressing QA: " + message)
    quit(1)


func _bounds_in_room(room: Node3D, subtree: Node3D) -> AABB:
    var result := AABB()
    var found := false
    for item in subtree.find_children("*", "MeshInstance3D", true, false):
        var part := item as MeshInstance3D
        if part.mesh == null:
            continue
        var offset := room.global_transform.affine_inverse() * part.global_transform
        var piece := offset * part.get_aabb()
        result = result.merge(piece) if found else piece
        found = true
    return result


func _run() -> void:
    var room := INTRO.instantiate() as Node3D
    root.add_child(room)
    await process_frame
    var decor := room.get_node_or_null("Decoration") as Node3D
    if decor == null:
        _fail("Decor must be an authored subscene visible in the Godot editor")
        return

    var floor := room.get_node_or_null("Floor") as MeshInstance3D
    var floor_material := floor.get_active_material(0) as StandardMaterial3D if floor != null else null
    if floor_material == null or floor_material.albedo_texture == null or not floor_material.normal_enabled:
        _fail("Tutorial floor should use the existing fully textured PBR finish")
        return
    var fabric := decor.get_node_or_null("ArchitecturalJoinery/RightUpperFabric") as MeshInstance3D
    var wainscot := decor.get_node_or_null("ArchitecturalJoinery/LeftLowerWainscoting") as MeshInstance3D
    var rug := decor.get_node_or_null("CeremonialPath/BurgundyRunner") as MeshInstance3D
    var staff_register := decor.get_node_or_null("ReceptionDetails/GuestRegisterCover") as MeshInstance3D
    var lamp := decor.get_node_or_null("LightingAndCeiling/RightSconceA/WarmLight") as OmniLight3D
    if fabric == null or wainscot == null or rug == null or staff_register == null or lamp == null:
        _fail("Entry, wall panels, runner, reception details or sconces missing")
        return
    for item in [fabric, wainscot, rug]:
        var finish := item.get_active_material(0) as StandardMaterial3D
        if finish == null or finish.albedo_texture == null or not finish.normal_enabled:
            _fail("Architectural wood, fabric and runner must have real PBR textures")
            return

    # Floor mesh top y=0. Textured runner must rest on it and never share its
    # exact plane (a 2mm offset is deliberate to defeat z-fighting).
    var runner_mesh := rug.mesh as BoxMesh
    var runner_bottom := rug.position.y - runner_mesh.size.y * .5
    if runner_bottom < .001 or runner_bottom > .006 or rug.position.x != 0.0:
        _fail("Runner is floating, embedded or not centered in clear aisle")
        return
    var right_wall := fabric.mesh as BoxMesh
    if fabric.position.x + right_wall.size.x * .5 >= 3.573:
        _fail("Right wall cladding intersects existing wall surface")
        return
    var left_wall := wainscot.mesh as BoxMesh
    if wainscot.position.x - left_wall.size.x * .5 <= -3.573:
        _fail("Left wall cladding intersects existing wall surface")
        return

    # The player always has a clear central passage to the entrance door:
    # no furniture collision may enter the |x| < 1.3 m lane.
    var collision := decor.get_node_or_null("SolidFurniture/CollisionBody") as StaticBody3D
    if collision == null or collision.get_child_count() != 3:
        _fail("Waiting lounge and pedestal need exactly three grounded collisions")
        return
    for child in collision.get_children():
        var shape := child as CollisionShape3D
        if shape == null or not (shape.shape is BoxShape3D):
            _fail("Furniture collision must be a solid authored shape")
            return
        var half := (shape.shape as BoxShape3D).size * .5
        if shape.position.x - half.x < 1.29:
            _fail("Furniture blocks the player corridor: " + shape.name)
            return
        if shape.position.y - half.y < -.015:
            _fail("Furniture collision sinks into the floor: " + shape.name)
            return

    # Imported Poly Haven assets have PBR finishes and nontrivial geometry.
    # Assert their actual mesh AABB in scene space: we do not trust an
    # arbitrary wrapper offset that could bury models in walls or float them.
    for element in [
        ["WaitingLounge/UpholsteredSofa", 0.0, 0.035],
        ["WaitingLounge/TeaTable", 0.0, 0.035],
        ["EntranceDisplay/MarblePortraitBust", 0.92, 0.97]
    ]:
        var model := decor.get_node_or_null(str(element[0])) as Node3D
        if model == null:
            _fail("Curated furnishings not loaded: " + str(element[0]))
            return
        var bound := _bounds_in_room(room, model)
        if bound.size.y < .18 or bound.position.y < float(element[1]) - .02 \
                or bound.position.y > float(element[2]):
            _fail("Model not properly grounded on floor/plinth: " + str(element[0]) + " " + str(bound))
            return
        if bound.end.x > 3.55 or bound.end.z > 4.56 or bound.position.z < -4.59:
            _fail("Furnishing clips room envelope: " + str(element[0]) + " " + str(bound))
            return

    var display := decor.get_node_or_null("EntranceDisplay/PedestalCap") as MeshInstance3D
    if display == null or absf(display.position.y + (display.mesh as BoxMesh).size.y * .5 - .9305) > .005:
        _fail("Bust pedestal cannot support the statue at the correct height")
        return
    var chandelier := decor.get_node_or_null("LightingAndCeiling/CentralChandelier") as Node3D
    if chandelier == null:
        _fail("Ceiling focal point is missing")
        return
    var chandelier_bounds := _bounds_in_room(room, chandelier)
    if chandelier_bounds.size.y < .4 or chandelier_bounds.position.y < 2.65 \
            or chandelier_bounds.end.y > 4.02:
        _fail("Chandelier floats through ceiling or hangs into eye level")
        return
    if lamp.shadow_enabled or lamp.light_energy > .4 or lamp.omni_range > 3.0:
        _fail("Decorative wall lighting should stay subtle and inexpensive")
        return
    var desk_top := room.get_node("ReceptionMainTop") as MeshInstance3D
    var surface_y := desk_top.position.y + desk_top.scale.y * .5
    var book_bottom := staff_register.position.y - (staff_register.mesh as BoxMesh).size.y * .5
    if book_bottom < surface_y or book_bottom > surface_y + .01:
        _fail("Guest register does not rest on the reception counter")
        return

    if room.get_node_or_null("ExitDoor") == null \
            or room.get_node_or_null("CroupierStation") == null \
            or room.get_node_or_null("Player") == null:
        _fail("Set dressing must never replace actual tutorial gameplay")
        return

    room.queue_free()
    await process_frame
    print("Casino Anomaly tutorial set dressing spatial QA PASS")
    quit(0)
