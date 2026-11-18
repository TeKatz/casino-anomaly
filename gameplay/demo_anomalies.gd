extends RefCounted
## Temporary, deliberately obvious test anomalies using EXISTING labels only.
## Replace these with curated anomaly modules later; no scene is modified on disk.

const PATHS := {
    "bar_label": "CornerBar/Sign_MIDNIGHT_BAR",
    "entrance_label": "Architecture/Sign_CASINO_ANOMALY",
    "table_label": "Decor/Sign_TABLE_GAMES"
}
const DEMO_IDS := ["bar_label", "entrance_label", "table_label"]

var target: Label3D
var previous_text := ""
var previous_color := Color.WHITE


func available_ids(room: Node3D) -> Array[String]:
    var result: Array[String] = []
    for id in DEMO_IDS:
        if room.get_node_or_null(PATHS[id]) is Label3D:
            result.append(id)
    return result


func apply(room: Node3D, id: String) -> bool:
    clear()
    if id.is_empty():
        return true
    if not PATHS.has(id):
        return false
    target = room.get_node_or_null(PATHS[id]) as Label3D
    if target == null:
        return false
    previous_text = target.text
    previous_color = target.modulate
    match id:
        "bar_label":
            target.text = "MIDNIGHT B4R"
        "entrance_label":
            target.text = "CASINO AN0MALY"
        "table_label":
            target.text = "TABLE G4MES"
    target.modulate = Color("#f5a2a2")
    return true


func clear() -> void:
    if target != null and is_instance_valid(target):
        target.text = previous_text
        target.modulate = previous_color
    target = null
