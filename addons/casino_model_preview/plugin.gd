@tool
extends EditorPlugin

const SketchfabImport = preload("res://addons/casino_model_preview/asset_installer.gd")
const BAKE_MENU_NAME := "Casino: Importierte Modelle bearbeitbar machen"
var _waiting_for_model_import := false
var _model_import_refresh_pending := false
## Guard the authored main.tscn when the in-editor Sketchfab preview hides
## original placeholders. Undo these temporary visibility overrides BEFORE
## the editor serializes a scene; rebuild the preview AFTER the scene saved.

var _pending_restore: WeakRef


func _enter_tree() -> void:
    add_tool_menu_item(BAKE_MENU_NAME, _make_imported_models_editable)
    scene_saved.connect(_on_scene_saved)
    scene_changed.connect(_on_scene_changed)
    var fs := EditorInterface.get_resource_filesystem()
    if fs != null:
        fs.filesystem_changed.connect(_on_resource_filesystem_changed)
        fs.resources_reimported.connect(_on_resources_reimported)
    call_deferred("_ensure_local_editor_models")


func _exit_tree() -> void:
    remove_tool_menu_item(BAKE_MENU_NAME)
    if scene_saved.is_connected(_on_scene_saved):
        scene_saved.disconnect(_on_scene_saved)
    if scene_changed.is_connected(_on_scene_changed):
        scene_changed.disconnect(_on_scene_changed)
    var fs := EditorInterface.get_resource_filesystem()
    if fs != null:
        if fs.filesystem_changed.is_connected(_on_resource_filesystem_changed):
            fs.filesystem_changed.disconnect(_on_resource_filesystem_changed)
        if fs.resources_reimported.is_connected(_on_resources_reimported):
            fs.resources_reimported.disconnect(_on_resources_reimported)
    _waiting_for_model_import = false
    _model_import_refresh_pending = false
    _pending_restore = null


func _ensure_local_editor_models() -> void:
    # GitHub CI extracts the original ZIPs before importing the project,
    # but a fresh local checkout only has sketchfab_drop/*.zip.
    if not SketchfabImport.has_all_extracted():
        print("Casino Editor Furniture: unpacking verified Sketchfab models for Godot editor...")
        if not SketchfabImport.ensure_local_models():
            push_warning("Casino Editor Furniture: extraction failed. Run python tools/unpack_sketchfab_assets.py --require-all and reopen main.tscn.")
            return
        _waiting_for_model_import = true
        _model_import_refresh_pending = true
        print("Casino Editor Furniture: extracted 4 Sketchfab model packages; importing glTF...")
        _request_editor_scan()
    else:
        # Already extracted, but imported glTF resources may still be
        # building when the editor launches after a clean checkout.
        if not _all_scenes_imported():
            _waiting_for_model_import = true
            _model_import_refresh_pending = true
            _request_editor_scan()
        else:
            _refresh_edited_preview()


## One-time conversion: replaces ownerless, unselectable previews with true
## instances owned by main.tscn. Future editor and runtime sessions reuse them.
func _make_imported_models_editable() -> void:
    var root := EditorInterface.get_edited_scene_root()
    if root == null or root.scene_file_path != "res://main.tscn":
        push_warning("Casino: open main.tscn before converting imported models.")
        return
    if not _all_scenes_imported():
        push_warning("Casino: wait until the imported Sketchfab models are available, then retry.")
        return
    var sketchfab := root.get_node_or_null("SketchfabFurniture")
    if sketchfab == null or not sketchfab.has_method("bake_editable_models") \
            or not bool(sketchfab.call("bake_editable_models")):
        push_warning("Casino: Sketchfab furniture could not be converted.")
        return
    var model_layer := root.get_node_or_null("ModelInteriors")
    var converted := 0
    if model_layer != null:
        for marker in model_layer.get_children():
            if marker.has_method("bake_editable_model") \
                    and bool(marker.call("bake_editable_model", root)):
                converted += 1
    EditorInterface.mark_scene_as_unsaved()
    print("Casino: Sketchfab furniture and ", converted,
        " Poly Haven instances are now editable. Save main.tscn (Ctrl+S).")


func _request_editor_scan() -> void:
    var fs := EditorInterface.get_resource_filesystem()
    if fs != null and not fs.is_scanning():
        fs.scan()


func _all_scenes_imported() -> bool:
    for slug in ["roulette_table", "retro_slot_machine", "blackjack_table", "poker_set"]:
        var path := "res://models/sketchfab/%s/scene.gltf" % slug
        if not ResourceLoader.exists(path):
            return false
    return ResourceLoader.exists("res://models/sketchfab/poker_set/poker_props.glb")


func _on_resource_filesystem_changed() -> void:
    _refresh_after_import()


func _on_resources_reimported(_resources: PackedStringArray) -> void:
    _refresh_after_import()


func _refresh_after_import() -> void:
    if not _model_import_refresh_pending or not _all_scenes_imported():
        return
    _waiting_for_model_import = false
    _model_import_refresh_pending = false
    call_deferred("_refresh_edited_preview")


func _refresh_edited_preview() -> void:
    var root := EditorInterface.get_edited_scene_root()
    if root == null:
        return
    var layer := root.get_node_or_null("SketchfabFurniture")
    if layer != null and layer.has_method("_refresh_editor_preview"):
        layer.call_deferred("_refresh_editor_preview")


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
