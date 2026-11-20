extends RefCounted
## Single-active-anomaly adapter over interchangeable effect modules.
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
var active_handler: RefCounted

func available_ids(room: Node3D) -> Array[String]:
    return Catalog.available_ids(room)

func apply(room: Node3D, id: String) -> bool:
    clear()
    if id.is_empty():
        return true
    var definition := Catalog.get_entry(id)
    if definition.is_empty():
        return false
    var handler: RefCounted = definition["handler"].new()
    if not bool(handler.call("apply", room, definition)):
        return false
    active_handler = handler
    return true

func clear() -> void:
    if active_handler != null:
        active_handler.call("clear")
        active_handler = null
