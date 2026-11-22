extends RefCounted
## Data-driven anomaly catalog. Add ONE CasinoAnomalyDefinition .tres to
## anomaly_definitions/; it is automatically available in gameplay and archive.
## ResourceLoader.list_directory works with exported .pck resources in Godot 4.5.
const DEFINITION_DIR := "res://gameplay/anomaly_definitions"
static var _loaded := false
static var _entries: Array[Dictionary] = []


static func _ensure_loaded() -> void:
    if _loaded:
        return
    _loaded = true
    var seen := {}
    var filenames := ResourceLoader.list_directory(DEFINITION_DIR)
    filenames.sort()
    for filename in filenames:
        if not filename.ends_with(".tres"):
            continue
        var resource := ResourceLoader.load(DEFINITION_DIR.path_join(filename))
        if resource == null or not resource.has_method("to_entry"):
            push_error("Invalid anomaly definition resource: " + filename)
            continue
        if not bool(resource.get("enabled")):
            continue
        var entry: Dictionary = resource.call("to_entry")
        var id := str(entry.get("id", ""))
        if id.is_empty() or seen.has(id):
            push_error("Empty or duplicate anomaly ID in " + filename)
            continue
        if not (entry.get("handler") is Script) or str(entry.get("target_path", "")).is_empty():
            push_error("Missing anomaly handler or target: " + filename)
            continue
        var translated := true
        for key in ["title_en", "title_de", "description_en", "description_de", "category_en", "category_de"]:
            if str(entry.get(key, "")).is_empty():
                push_error("Missing anomaly translation " + key + ": " + filename)
                translated = false
        if not translated:
            continue
        seen[id] = true
        _entries.append(entry)


static func entries() -> Array[Dictionary]:
    _ensure_loaded()
    var result: Array[Dictionary] = []
    for entry in _entries:
        result.append(entry.duplicate())
    return result


static func get_entry(id: String) -> Dictionary:
    _ensure_loaded()
    for entry in _entries:
        if str(entry["id"]) == id:
            return entry.duplicate()
    return {}


static func discoverable_ids() -> Array[String]:
    _ensure_loaded()
    var result: Array[String] = []
    for entry in _entries:
        if bool(entry.get("discoverable", true)):
            result.append(str(entry["id"]))
    return result


static func available_ids(room: Node3D) -> Array[String]:
    _ensure_loaded()
    var result: Array[String] = []
    if room == null:
        return result
    for entry in _entries:
        var handler: RefCounted = (entry["handler"] as Script).new()
        if bool(handler.call("can_apply", room, entry)):
            result.append(str(entry["id"]))
    return result
