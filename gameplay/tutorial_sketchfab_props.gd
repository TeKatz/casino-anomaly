@tool
extends Node3D
## Exact Sketchfab replacements are optional until their original glTF ZIPs
## have been downloaded by the owner and extracted during asset import.
const SOURCE := "res://models/tutorial_user/"

func _ready() -> void:
    _install_lights()
    if _add("desk_bell", "DeskBell", Vector3(-2.15, 1.234, -1.07), Vector3(.20,.18,.20)):
        _hide_old("ReceptionDetails", ["ServiceBellBase","ServiceBellDome","ServiceBellButton"])
    if _add("books_with_magnifier", "BooksWithMagnifier", Vector3(-2.15,1.275,1.12), Vector3(.54,.26,.38)):
        _hide_old("ReceptionDetails", ["GuestRegisterCover","RegisterPages","RegisterSpine"])
    if _add("vintage_gramophone", "VintageGramophone", Vector3(2.92,1.285,.14), Vector3(.55,.62,.53)):
        _console()

func _install_lights() -> void:
    var places := [
        ["RightSconceA", Vector3(3.42,2.49,-2.65)],
        ["RightSconceB", Vector3(3.42,2.49,.75)],
        ["ExitSconceLeft", Vector3(-1.51,2.50,-4.45)],
        ["ExitSconceRight", Vector3(1.51,2.50,-4.45)]
    ]
    for p in places:
        if _add("wall_light", "WallLight"+str(p[0]), p[1], Vector3(.24,.37,.22)):
            _hide_old("LightingAndCeiling/"+str(p[0]), ["Mount","Arm","Shade"])

func _hide_old(group: String, names: Array) -> void:
    for name in names:
        var item := get_parent().get_node_or_null(group+"/"+str(name)) as VisualInstance3D
        if item != null:
            item.visible = false

func _add(slug: String, title: String, center: Vector3, envelope: Vector3) -> bool:
    var path := SOURCE+slug+"/scene.gltf"
    if not ResourceLoader.exists(path):
        path = SOURCE+slug+"/scene.glb"
    if not ResourceLoader.exists(path):
        return false
    var packed := load(path) as PackedScene
    if packed == null:
        push_warning("Missing imported scene for "+slug)
        return false
    var model := packed.instantiate() as Node3D
    if model == null:
        push_warning("Sketchfab source is not a 3D scene: "+slug)
        return false
    model.name = title
    add_child(model)
    if slug == "wall_light":
        # Imported lamps face the room, not along the wall.
        model.rotation.y = PI * 0.5 if center.x > 3.0 else PI
    var bound := _bounds(model)
    if bound.size.x < .0001 or bound.size.y < .0001 or bound.size.z < .0001:
        model.queue_free()
        return false
    var fit := minf(envelope.x/bound.size.x, minf(envelope.y/bound.size.y, envelope.z/bound.size.z))
    if fit <= 0.0:
        model.queue_free()
        return false
    model.scale = Vector3.ONE*fit
    bound = _bounds(model)
    # Exact contact with the receiving surface, not an approximate centre:
    # imported Sketchfab coordinates vary considerably between assets.
    var anchored_y := center.y - bound.get_center().y
    match slug:
        "books_with_magnifier", "desk_bell":
            anchored_y = 1.144 - bound.position.y # Existing reception top
        "vintage_gramophone":
            anchored_y = 0.970 - bound.position.y # New sideboard top
    var anchored_x := center.x - bound.get_center().x
    var anchored_z := center.z - bound.get_center().z
    if slug == "wall_light":
        # Flush the fixture's rearmost bound to the real wall face with a
        # 9mm clearance instead of letting it float several centimetres away.
        if center.x > 3.0:
            anchored_x = 3.566 - bound.end.x # Right inner wall at x=3.575
        else:
            anchored_z = -4.586 - bound.position.z # Entrance wall z=-4.595
    model.position = Vector3(anchored_x, anchored_y, anchored_z)
    return true

func _bounds(model: Node3D) -> AABB:
    var total := AABB()
    var found := false
    for part in model.find_children("*", "MeshInstance3D", true, false):
        var mesh := part as MeshInstance3D
        if mesh.mesh == null:
            continue
        var local := global_transform.affine_inverse()*mesh.global_transform
        var piece := local*mesh.get_aabb()
        total = total.merge(piece) if found else piece
        found = true
    return total

func _console() -> void:
    # Complete solid cabinet on the right. The player aisle |x| < 1.3 is clear.
    var cabinet := StaticBody3D.new()
    cabinet.name = "GramophoneConsole"
    add_child(cabinet)
    _box(cabinet, "Body", Vector3(2.93,.47,.14), Vector3(.74,.90,.54), "res://bar_side_material.tres")
    _box(cabinet, "Top", Vector3(2.93,.945,.14), Vector3(.82,.05,.60), "res://bar_top_material.tres")
    _box(cabinet, "Plinth", Vector3(2.93,.075,.14), Vector3(.80,.15,.58), "res://bar_top_material.tres")
    var collision := CollisionShape3D.new()
    collision.position = Vector3(2.93,.48,.14)
    collision.name = "BodyCollision"
    var shape := BoxShape3D.new()
    shape.size = Vector3(.82,.96,.60)
    collision.shape = shape
    cabinet.add_child(collision)

func _box(parent: Node3D, title: String, at: Vector3, size: Vector3, material_path: String) -> void:
    var block := MeshInstance3D.new()
    block.name = title
    block.position = at
    var mesh := BoxMesh.new()
    mesh.size = size
    block.mesh = mesh
    block.material_override = load(material_path) as Material
    parent.add_child(block)
