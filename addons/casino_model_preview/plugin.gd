@tool
extends EditorPlugin

const SketchfabImport = preload("res://addons/casino_model_preview/asset_installer.gd")
const BAKE_MENU_NAME := "Casino: Importierte Modelle bearbeitbar machen"
const VOXEL_MENU_NAME := "Casino: VoxelGI neu backen..."
var _voxel_confirm: ConfirmationDialog
var _voxel_info: AcceptDialog
var _voxel_process_pid := -1
var _waiting_for_model_import := false
var _model_import_refresh_pending := false
## Guard the authored main.tscn when the in-editor Sketchfab preview hides
## original placeholders. Undo these temporary visibility overrides BEFORE
## the editor serializes a scene; rebuild the preview AFTER the scene saved.

var _pending_restore: WeakRef


func _enter_tree() -> void:
    add_tool_menu_item(BAKE_MENU_NAME, _make_imported_models_editable)
    add_tool_menu_item(VOXEL_MENU_NAME, _ask_voxel_bake)
    _voxel_confirm = ConfirmationDialog.new()
    _voxel_confirm.title = "Casino Anomaly – VoxelGI"
    _voxel_confirm.dialog_text = ("Alle offenen Szenen speichern und VoxelGI mit den aktuellen " +
        "Neon-Positionen neu backen?\n\n" +
        "Der Vorgang benötigt eine GPU und läuft in einem separaten Godot-Prozess. " +
        "Verändere main.tscn währenddessen nicht.")
    _voxel_confirm.ok_button_text = "Speichern und backen"
    add_child(_voxel_confirm)
    _voxel_confirm.confirmed.connect(_start_voxel_bake)
    _voxel_info = AcceptDialog.new()
    _voxel_info.title = "Casino Anomaly – VoxelGI"
    add_child(_voxel_info)
    set_process(false)
    scene_saved.connect(_on_scene_saved)
    scene_changed.connect(_on_scene_changed)
    var fs := EditorInterface.get_resource_filesystem()
    if fs != null:
        fs.filesystem_changed.connect(_on_resource_filesystem_changed)
        fs.resources_reimported.connect(_on_resources_reimported)
    call_deferred("_ensure_local_editor_models")


func _exit_tree() -> void:
    remove_tool_menu_item(BAKE_MENU_NAME)
    remove_tool_menu_item(VOXEL_MENU_NAME)
    set_process(false)
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


func _ask_voxel_bake() -> void:
    var root := EditorInterface.get_edited_scene_root()
    if root == null or root.scene_file_path != "res://main.tscn":
        _voxel_message("Öffne zuerst main.tscn im Godot-Editor.")
        return
    if _voxel_process_pid > 0 and OS.is_process_running(_voxel_process_pid):
        _voxel_message("Ein VoxelGI-Bake läuft bereits. Bitte nicht doppelt starten.")
        return
    _voxel_confirm.popup_centered()


func _start_voxel_bake() -> void:
    var root := EditorInterface.get_edited_scene_root()
    if root == null or root.scene_file_path != "res://main.tscn":
        _voxel_message("Die Casino-Szene ist nicht mehr geöffnet. Bake abgebrochen.")
        return
    # Explicit confirmation authorizes saving all open artist scenes.
    # The offline process reads ONLY the saved main.tscn from disk.
    EditorInterface.save_all_scenes()
    var executable := OS.get_executable_path()
    # On Windows prefer Godot's bundled console binary, if installed.
    # It shows the actual bake progress and any GPU error to the artist.
    if OS.get_name() == "Windows" and executable.to_lower().ends_with(".exe") \
            and not executable.to_lower().ends_with("_console.exe"):
        var console_path := executable.substr(0, executable.length() - 4) + "_console.exe"
        if FileAccess.file_exists(console_path):
            executable = console_path
    var args := PackedStringArray([
        "--path", ProjectSettings.globalize_path("res://"),
        "--script", "res://tools/bake_voxel_gi.gd"
    ])
    # Never --headless: VoxelGI.bake() requires a rendering device.
    _voxel_process_pid = OS.create_process(executable, args, true)
    if _voxel_process_pid <= 0:
        _voxel_message("Godot-Bake-Prozess konnte nicht gestartet werden.\n" +
            "Du kannst das Skript weiterhin über die Konsole ausführen.")
        return
    set_process(true)
    print("Casino: VoxelGI-Bake gestartet (PID ", _voxel_process_pid, ").")
    _voxel_message("VoxelGI-Baking gestartet. Bitte die Konsole auf " +
        "'Casino Anomaly VoxelGI OFFLINE BAKE PASS' prüfen.\n\n" +
        "Danach main.tscn neu öffnen, beide .res prüfen und committen.")


func _process(_delta: float) -> void:
    if _voxel_process_pid <= 0 or OS.is_process_running(_voxel_process_pid):
        return
    _voxel_process_pid = -1
    set_process(false)
    var fs := EditorInterface.get_resource_filesystem()
    if fs != null:
        fs.scan()
    print("Casino: Bake-Prozess beendet. Ergebnis in der Konsole prüfen; " +
        "main.tscn für die neue VoxelGI-Vorschau erneut öffnen.")


func _voxel_message(message: String) -> void:
    _voxel_info.dialog_text = message
    _voxel_info.popup_centered()


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
