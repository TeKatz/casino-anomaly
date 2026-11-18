extends Node3D

# Casino_2 is an entire 3D room, not a piece of furniture.
# Preview it separately to avoid layering another room over our L-shaped hall.

func _ready() -> void:
    var path := "res://models/sketchfab/casino_2/scene.gltf"
    if not ResourceLoader.exists(path):
        push_warning("Casino_2 source model not installed yet")
        return
    var packed: PackedScene = load(path) as PackedScene
    if packed == null:
        push_error("Casino_2 glTF could not be loaded")
        return
    var imported: Node3D = packed.instantiate() as Node3D
    add_child(imported)
    var box := AABB()
    var found := false
    for item in imported.find_children("*", "MeshInstance3D", true, false):
        var part: MeshInstance3D = item as MeshInstance3D
        if part.mesh == null:
            continue
        var relative: Transform3D = imported.global_transform.affine_inverse() * part.global_transform
        var current: AABB = relative * part.get_aabb()
        box = box.merge(current) if found else current
        found = true
    if not found or box.size.y <= 0.001:
        imported.queue_free()
        return
    # Sketchfab authoring units are large; normalize to a ~25 m preview room.
    var scale_factor: float = 25.0 / maxf(box.size.x, box.size.z)
    imported.scale = Vector3.ONE * scale_factor
    imported.position = Vector3(
        -(box.position.x + box.size.x * 0.5) * scale_factor,
        -box.position.y * scale_factor,
        -(box.position.z + box.size.z * 0.5) * scale_factor
    )
    print("Separate Casino_2 environment preview imported successfully")
