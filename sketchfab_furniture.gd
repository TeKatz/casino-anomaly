extends Node3D
# Imported user-provided Sketchfab CC BY 4.0 models.
# Low-poly original placeholders only disappear after the corresponding
# complete glTF scene has been loaded and placed successfully.

const FOLDER := "res://models/sketchfab/"
var assets: Dictionary = {}
var replaced_slots := 0
var replaced_roulette := 0
var replaced_blackjack := 0
var poker_props_placed := 0

func _ready() -> void:
    call_deferred("_populate")

func _load_scene(slug: String, filename: String = "scene.gltf") -> PackedScene:
    var path := FOLDER + slug + "/" + filename
    if not ResourceLoader.exists(path):
        return null
    if assets.has(path):
        return assets[path]
    var scene: PackedScene = load(path) as PackedScene
    if scene != null:
        assets[path] = scene
    else:
        push_warning("Sketchfab model import failed: " + path)
    return scene

func _mesh_bounds(scene_root: Node3D) -> AABB:
    var result := AABB()
    var found := false
    for candidate in scene_root.find_children("*", "MeshInstance3D", true, false):
        var part: MeshInstance3D = candidate as MeshInstance3D
        if part.mesh == null:
            continue
        var xform: Transform3D = scene_root.global_transform.affine_inverse() * part.global_transform
        var box: AABB = xform * part.get_aabb()
        result = result.merge(box) if found else box
        found = true
    return result

func _spawn(slug: String, label: String, spot: Vector3, max_width: float,
        max_height: float, yaw: float = 0.0, filename: String = "scene.gltf",
        add_collision: bool = true) -> Node3D:
    var packed := _load_scene(slug, filename)
    if packed == null:
        return null
    var wrapper := Node3D.new()
    wrapper.name = label
    wrapper.position = spot
    wrapper.rotation.y = yaw
    wrapper.set_meta("source_asset", slug)
    add_child(wrapper)
    var model: Node3D = packed.instantiate() as Node3D
    if model == null:
        wrapper.queue_free()
        push_error("Sketchfab model does not instantiate as a 3D node: " + slug)
        return null
    wrapper.add_child(model)
    var size: AABB = _mesh_bounds(model)
    if size.size.y < 0.001 or maxf(size.size.x, size.size.z) < 0.001:
        wrapper.queue_free()
        push_warning("Empty or unorientable imported Sketchfab mesh: " + slug)
        return null
    var factor: float = minf(max_width / maxf(size.size.x, size.size.z), max_height / size.size.y)
    model.scale = Vector3.ONE * factor
    model.position = Vector3(
        -(size.position.x + size.size.x * 0.5) * factor,
        -size.position.y * factor,
        -(size.position.z + size.size.z * 0.5) * factor
    )
    if add_collision:
        var body := StaticBody3D.new()
        body.name = "FurnitureCollider"
        body.position.y = size.size.y * factor * 0.5
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = Vector3(
            maxf(size.size.x * factor, 0.25),
            maxf(size.size.y * factor, 0.25),
            maxf(size.size.z * factor, 0.25)
        )
        shape.shape = box
        body.add_child(shape)
        wrapper.add_child(body)
    return wrapper

func _populate() -> void:
    var hall: Node3D = get_parent() as Node3D
    if hall == null:
        return
    var slots: Node3D = hall.get_node_or_null("SlotMachines") as Node3D
    var tables: Node3D = hall.get_node_or_null("GamingTables") as Node3D
    if slots == null or tables == null:
        push_error("Casino room layout missing while importing Sketchfab furniture")
        return

    # The retro machine is ~500k triangles. Use ONE hero machine initially,
    # not ten copies: the existing prototypes stay in other places.
    var retro := slots.get_node_or_null("Slot_01") as Node3D
    if retro != null:
        var hero := _spawn("retro_slot_machine", "RetroSlotHero",
            retro.position, 1.42, 1.72, retro.rotation.y)
        if hero != null:
            retro.queue_free()
            replaced_slots += 1

    for table in tables.get_children():
        if not (table is Node3D):
            continue
        var table_node: Node3D = table as Node3D
        var name_lower := table_node.name.to_lower()
        if name_lower.begins_with("roulette"):
            var replacement := _spawn("roulette_table", "SketchfabRoulette",
                table_node.position, 2.75, 1.18, -PI * 0.5)
            if replacement != null:
                table_node.queue_free()
                replaced_roulette += 1
        elif name_lower.begins_with("blackjack"):
            var replacement := _spawn("blackjack_table", "SketchfabBlackjack",
                table_node.position, 2.60, 0.94, 0.0)
            if replacement != null:
                table_node.queue_free()
                replaced_blackjack += 1
                var cards := _spawn("poker_set", "PokerCardAndChips",
                    table_node.position + Vector3(0, 0.95, 0), 0.90, 0.20, 0.0,
                    "poker_props.glb", false)
                if cards != null:
                    poker_props_placed += 1
    print("Sketchfab furniture imported: slots=", replaced_slots,
        ", roulette=", replaced_roulette, ", blackjack=", replaced_blackjack,
        ", poker props=", poker_props_placed)
