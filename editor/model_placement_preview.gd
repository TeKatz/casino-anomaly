@tool
extends Node3D
## A stable placement marker in main.tscn. Move/rotate/scale this node in
## Godot's regular 3D viewport. Before baking, glTF is preview-only;
## after baking, the selectable glTF child persists into gameplay.

@export var asset_id: String = ""
@export var target_height: float = 1.0
@export var max_footprint: float = 0.0
@export var wall_mount: bool = false
@export var mesh_variant: String = ""

var _preview: Node3D


func _ready() -> void:
    if Engine.is_editor_hint():
        if has_node("EditableImportedModel"):
            call_deferred("_sync_authored_variant")
        else:
            call_deferred("_create_preview")


## The editable instance is the complete imported glTF scene. Only the
## designated variant belongs on this placement marker, just as in runtime.
## Hide the unused siblings without changing the saved scene or donor asset.
func _sync_authored_variant() -> void:
    if not Engine.is_editor_hint() or mesh_variant.is_empty():
        return
    var imported := get_node_or_null("EditableImportedModel") as Node3D
    if imported == null:
        return
    for candidate in imported.find_children("*", "MeshInstance3D", true, false):
        var part := candidate as MeshInstance3D
        if part.mesh != null:
            part.visible = part.name.begins_with(mesh_variant)


func _create_preview() -> void:
    if not Engine.is_editor_hint() or not is_inside_tree() \
            or has_node("EditableImportedModel"):
        return
    if _preview != null and is_instance_valid(_preview):
        remove_child(_preview)
        _preview.free()
    var path := "res://models/%s/%s_1k.gltf" % [asset_id, asset_id]
    if asset_id.is_empty() or not ResourceLoader.exists(path):
        return
    var packed := load(path) as PackedScene
    if packed == null:
        return
    var imported := packed.instantiate() as Node3D
    if imported == null:
        return
    # Internal children are visible in 3D but cannot accidentally be saved
    # as duplicate game geometry by the scene editor.
    imported.name = "_EditorOnlyModelPreview"
    add_child(imported, false, Node.INTERNAL_MODE_BACK)
    _preview = imported
    var found := false
    var bounds := AABB()
    for candidate in imported.find_children("*", "MeshInstance3D", true, false):
        var piece := candidate as MeshInstance3D
        if piece.mesh == null:
            continue
        if not mesh_variant.is_empty() and not piece.name.begins_with(mesh_variant):
            piece.visible = false
            continue
        var local_transform := imported.global_transform.affine_inverse() * piece.global_transform
        var transformed: AABB = local_transform * piece.get_aabb()
        bounds = bounds.merge(transformed) if found else transformed
        found = true
    if not found or bounds.size.y <= 0.0001:
        return
    var factor := target_height / bounds.size.y
    if max_footprint > 0.0:
        factor = minf(factor, max_footprint / maxf(bounds.size.x, bounds.size.z))
    imported.scale = Vector3.ONE * factor
    imported.position = Vector3(
        -(bounds.position.x + bounds.size.x * 0.5) * factor,
        -bounds.position.y * factor,
        -(bounds.position.z + bounds.size.z * 0.5) * factor
    )
    if wall_mount:
        imported.position.y -= target_height * 0.5


## Promote the imported mesh to a normal scene instance. This preserves
## its current normalized placement while making the model itself selectable
## and its transform persistent in main.tscn.
func bake_editable_model(scene_root: Node) -> bool:
    if not Engine.is_editor_hint() or not is_inside_tree():
        return false
    if has_node("EditableImportedModel"):
        return true
    if not is_instance_valid(_preview):
        _create_preview()
    if not is_instance_valid(_preview):
        return false
    var model := _preview
    remove_child(model)
    model.name = "EditableImportedModel"
    add_child(model)
    model.owner = scene_root
    _preview = null
    return true
