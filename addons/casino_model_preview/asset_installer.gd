@tool
extends RefCounted
## Import only SHA-256-pinned user-supplied Sketchfab ZIPs into the ignored
## models/sketchfab/ folder. The editor does not require external Python.
## CI can still use tools/unpack_sketchfab_assets.py with its stricter checks.
const CATALOG := "res://sketchfab_drop/catalog.json"
const ZIP_DIR := "res://sketchfab_drop"
const MODEL_DIR := "res://models/sketchfab"
const MAX_FILE_BYTES := 45 * 1024 * 1024
const MAX_TOTAL_BYTES := 180 * 1024 * 1024


static func _records() -> Array:
    if not FileAccess.file_exists(CATALOG):
        push_error("Sketchfab editor import: missing catalog.json")
        return []
    var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
    if not (result is Dictionary) or result.get("schemaVersion") != 1 \
            or result.get("license") != "CC-BY-4.0":
        push_error("Sketchfab editor import: invalid signed asset catalog")
        return []
    var entries: Variant = result.get("models", [])
    return entries if entries is Array else []


static func _ready_on_disk(slug: String, base: String = MODEL_DIR) -> bool:
    var folder := base.path_join(slug)
    for required in ["scene.gltf", "scene.bin", "license.txt"]:
        if not FileAccess.file_exists(folder.path_join(required)):
            return false
    if slug == "poker_set" and not FileAccess.file_exists(folder.path_join("poker_props.glb")):
        return false
    return true


static func has_all_extracted() -> bool:
    var entries := _records()
    if entries.size() != 4:
        return false
    for record in entries:
        if not _ready_on_disk(str(record.get("id", ""))):
            return false
    return true


static func unpack_one(record: Dictionary, output_base: String = MODEL_DIR) -> bool:
    var slug := str(record.get("id", ""))
    if slug.is_empty() or not slug.replace("_", "").is_valid_identifier():
        push_error("Sketchfab editor import: unsafe model ID " + slug)
        return false
    if _ready_on_disk(slug, output_base):
        return true
    var archive_path := ZIP_DIR.path_join(slug + ".zip")
    var archive := FileAccess.open(archive_path, FileAccess.READ)
    if archive == null:
        push_error("Sketchfab editor import: missing source " + archive_path)
        return false
    var archive_size := archive.get_length()
    archive.close()
    if archive_size != int(record.get("bytes", -1)) \
            or FileAccess.get_sha256(archive_path).to_lower() != str(record.get("sha256", "")).to_lower():
        push_error("Sketchfab editor import: ZIP checksum does not match catalog: " + slug)
        return false

    var reader := ZIPReader.new()
    if reader.open(archive_path) != OK:
        push_error("Sketchfab editor import: cannot read ZIP " + slug)
        return false
    var entries := reader.get_files()
    for required in ["scene.gltf", "scene.bin", "license.txt"]:
        if not entries.has(required):
            reader.close()
            push_error("Sketchfab editor import: missing " + required + " in " + slug)
            return false
    if slug == "poker_set" and not entries.has("poker_props.glb"):
        reader.close()
        push_error("Sketchfab editor import: poker prop GLB is missing")
        return false

    var out_base := output_base.path_join(slug)
    var total := 0
    # A signed ZIP prevents arbitrary files being treated as importable. Still
    # reject absolute paths and traversal before writing into the project.
    for entry in entries:
        var parts := entry.split("/")
        if entry.begins_with("/") or entry.begins_with("\\") \
                or entry.contains("\\") or entry.contains(":") \
                or parts.has("..") or parts.has("."):
            reader.close()
            push_error("Sketchfab editor import: unsafe archive member: " + entry)
            return false
        if entry.ends_with("/"):
            continue
        var bytes := reader.read_file(entry)
        total += bytes.size()
        if bytes.size() > MAX_FILE_BYTES or total > MAX_TOTAL_BYTES:
            reader.close()
            push_error("Sketchfab editor import: oversized archive member in " + slug)
            return false
        var destination := out_base.path_join(entry)
        var absolute := ProjectSettings.globalize_path(destination)
        if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
            reader.close()
            push_error("Sketchfab editor import: cannot create " + absolute.get_base_dir())
            return false
        var file := FileAccess.open(absolute, FileAccess.WRITE)
        if file == null:
            reader.close()
            push_error("Sketchfab editor import: cannot write " + absolute)
            return false
        file.store_buffer(bytes)
        file.close()
    reader.close()
    if not _ready_on_disk(slug, output_base):
        push_error("Sketchfab editor import: incomplete extraction for " + slug)
        return false
    return true


static func ensure_local_models() -> bool:
    var entries := _records()
    if entries.size() != 4:
        push_error("Sketchfab editor import: expected four pinned ZIP archives")
        return false
    for item in entries:
        if not unpack_one(item):
            return false
    return true
