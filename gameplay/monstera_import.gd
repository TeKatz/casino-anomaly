@tool
extends Node3D
## Substitute the original Giora Monstera glTF for the old placeholder mesh.
## Add the optimization pack at res://models/sketchfab_monstera/ before opening
## the Godot editor. This loader does NOT download assets at game runtime.
##
## Parent names Decor/Plant_00..05 intentionally remain stable for anomalies.
const SOURCE := "res://models/sketchfab_monstera/scene.gltf"
const ROTATIONS := [0.0, 58.0, 118.0, 174.0, 239.0, 304.0]
const HEIGHT_FACTOR := 1.14
const BASE_OFFSET := 0.5217841

var model: Node3D


func _ready() -> void:
    # Source is optional until the authored Sketchfab archive is installed.
    # Never replace a real plant with a generated fake or a stock billboard.
    if not ResourceLoader.exists(SOURCE, "PackedScene"):
        return
    var packed := load(SOURCE) as PackedScene
    if packed == null:
        push_warning("Monstera original glTF is not a valid Godot scene: " + SOURCE)
        return
    model = packed.instantiate() as Node3D
    if model == null:
        return
    model.name = "GioraMonsteraOriginal"
    model.scale = Vector3.ONE * HEIGHT_FACTOR
    model.position = Vector3(0, BASE_OFFSET * HEIGHT_FACTOR, 0)
    var index := clampi(int(str(name).trim_prefix("Plant_")), 0, 5)
    model.rotation.y = deg_to_rad(ROTATIONS[index])
    model.set_meta("source_asset", "giora_monstera_deliciosa")
    add_child(model)
    # Source is only hidden after successful original-model instantiation.
    # Keep the existing pot collision and the Plant_XX parent transforms.
    var old_pot := get_node_or_null("PlantPot_%02d" % index) as Node3D
    var old_foliage := get_node_or_null("PlantFoliage_%02d" % index) as Node3D
    if old_pot != null:
        old_pot.hide()
    if old_foliage != null:
        old_foliage.hide()
    # For precise physics do not use the broad old planter collision.
    # New planter footprint is ~0.30m diameter, vs ~0.60m originally.
    var body := get_node_or_null("PlantPot_%02d_Collision" % index)
    if body != null:
        var old_shape := body.get_child(0) as CollisionShape3D
        if old_shape != null:
            var shape := CylinderShape3D.new()
            shape.radius = 0.18
            shape.height = 0.62
            old_shape.shape = shape
            body.position.y = 0.31


func get_foliage_animation_target() -> Node3D:
    if model == null:
        return null
    var leaves := model.find_children("Leaves", "Node3D", true, false)
    if not leaves.is_empty():
        return leaves[0] as Node3D
    return null
