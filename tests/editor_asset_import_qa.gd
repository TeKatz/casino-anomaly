extends SceneTree
## Reproduce a freshly cloned local editor checkout, where the five ZIPs
## are checked into git but models/sketchfab is ignored. ZIPReader can
## unpack one verified source *without Python*.
const IMPORTER = preload("res://addons/casino_model_preview/asset_installer.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("Casino Sketchfab editor asset import QA: " + reason)
    quit(1)

func _run() -> void:
    var catalog: Variant = JSON.parse_string(
        FileAccess.get_file_as_string("res://sketchfab_drop/catalog.json"))
    if not (catalog is Dictionary):
        _fail("Missing Sketchfab catalog")
        return
    var entry: Dictionary = {}
    for candidate in catalog.get("models", []):
        if str(candidate.get("id", "")) == "blackjack_table":
            entry = candidate
            break
    if entry.is_empty():
        _fail("No blackjack source ZIP in pinned catalog")
        return
    var output_root := "user://casino_model_preview_import_qa"
    var directory := ProjectSettings.globalize_path(
        output_root.path_join("blackjack_table"))
    # Each CI run gets a clean user://, never touches res://models/sketchfab.
    if not IMPORTER.unpack_one(entry, output_root) \
            or not IMPORTER._ready_on_disk("blackjack_table", output_root):
        _fail("ZIPReader could not extract and verify a pinned local asset")
        return
    var source_path := output_root.path_join("blackjack_table/scene.gltf")
    if not FileAccess.get_file_as_string(source_path).contains("\"version\""):
        _fail("Extracted glTF is empty or malformed")
        return
    # Remove temporary files; runtime and editor mesh folders are untouched.
    var src := DirAccess.open(directory)
    if src != null:
        for filename in src.get_files():
            DirAccess.remove_absolute(directory.path_join(filename))
        for subdir in src.get_directories():
            var d := DirAccess.open(directory.path_join(subdir))
            if d != null:
                for filename in d.get_files():
                    DirAccess.remove_absolute(directory.path_join(subdir).path_join(filename))
            DirAccess.remove_absolute(directory.path_join(subdir))
    DirAccess.remove_absolute(directory)
    print("Casino Sketchfab local editor extraction QA PASS")
    quit(0)
