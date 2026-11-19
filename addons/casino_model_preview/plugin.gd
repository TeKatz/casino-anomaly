@tool
extends EditorPlugin
## Guard the authored main.tscn when the in-editor Sketchfab preview hides
## original placeholders. Undo these temporary visibility overrides BEFORE
## the editor serializes a scene; rebuild the preview AFTER the scene saved.

var _pending_restore: WeakRef


func _enter_tree() -> void:
    scene_saved.connect(_on_scene_saved)
    scene_changed.connect(_on_scene_changed)


func _exit_tree() -> void:
    if scene_saved.is_connected(_on_scene_saved):
        scene_saved.disconnect(_on_scene_saved)
    if scene_changed.is_connected(_on_scene_changed):
        scene_changed.disconnect(_on_scene_changed)
    _pending_restore = null


func _apply_changes() -> void:
    var root := EditorInterface.get_edited_scene_root()
    if root == null:
        return
    var layer := root.get_node_or_null("SketchfabFurniture")
    if layer == null or not layer.has_method("_clear_editor_preview"):
        return
    # The preview is transient, but temporarily hiding the original
    # authored Node3Ds *can* otherwise be serialized into main.tscn.
    if layer.has_method("has_active_editor_preview") and \
            bool(layer.call("has_active_editor_preview")):
        layer.call("_clear_editor_preview")
        _pending_restore = weakref(layer)


func _on_scene_saved(_filepath: String) -> void:
    _restore_preview()


func _on_scene_changed(scene_root: Node) -> void:
    if scene_root == null:
        return
    var layer := scene_root.get_node_or_null("SketchfabFurniture")
    if layer != null and layer.has_method("_refresh_editor_preview"):
        # Rebuild if we switched away during a pending save.
        layer.call_deferred("_refresh_editor_preview")
    _pending_restore = null


func _restore_preview() -> void:
    if _pending_restore == null:
        return
    var layer: Object = _pending_restore.get_ref()
    _pending_restore = null
    if is_instance_valid(layer) and layer.is_inside_tree() \
            and layer.has_method("_refresh_editor_preview"):
        layer.call_deferred("_refresh_editor_preview")
