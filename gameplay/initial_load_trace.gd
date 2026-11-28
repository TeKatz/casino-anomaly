extends RefCounted
## Crash breadcrumbs only during initial main-scene activation. Never do
## synchronous journal I/O during streamed room assembly or editor previews.
static func record(context: Node, event: String, details: Dictionary = {}) -> void:
    if Engine.is_editor_hint() or not context.is_inside_tree():
        return
    var loader := context.get_node_or_null("/root/SceneLoader")
    if loader == null or not bool(loader.get("active")) or not bool(loader.get("committing")) or str(loader.get("target_path")) != "res://gameplay/casino/main.tscn":
        return
    var cursor: Node = context
    while cursor != null:
        if cursor.has_meta("_menu_showcase") or cursor.has_meta("_streaming_assembly") or cursor.has_meta("_streaming_standby"):
            return
        cursor = cursor.get_parent()
    var journal := context.get_node_or_null("/root/CrashJournal")
    if journal != null and bool(journal.get("enabled")):
        journal.call("record", event, details)
