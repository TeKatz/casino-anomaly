extends RefCounted
## Authoritative registry. New anomalies only need one entry referencing an
## effect module with can_apply(room, definition), apply(room, definition),
## clear(). The game and the developer picker discover it automatically.
const LabelSwap = preload("res://gameplay/anomalies/label_swap.gd")
const DEFINITIONS := [
    {
        "id": "bar_label",
        "category_en": "Signs", "category_de": "Beschriftungen",
        "title_en": "Midnight Bar sign", "title_de": "Midnight-Bar-Schild",
        "description_en": "One letter of the bar name is replaced.",
        "description_de": "Ein Buchstabe im Barschild verändert sich.",
        "handler": LabelSwap,
        "target_path": "CornerBar/Sign_MIDNIGHT_BAR",
        "replacement_text": "MIDNIGHT B4R"
    },
    {
        "id": "entrance_label",
        "category_en": "Signs", "category_de": "Beschriftungen",
        "title_en": "Casino entrance sign", "title_de": "Casino-Eingangsschild",
        "description_en": "The casino name contains a zero.",
        "description_de": "Der Casinoname enthält eine Null.",
        "handler": LabelSwap,
        "target_path": "Architecture/Sign_CASINO_ANOMALY",
        "replacement_text": "CASINO AN0MALY"
    },
    {
        "id": "table_label",
        "category_en": "Signs", "category_de": "Beschriftungen",
        "title_en": "Table Games sign", "title_de": "Table-Games-Schild",
        "description_en": "One letter of the table games sign changes.",
        "description_de": "Ein Buchstabe auf dem Spieltischschild verändert sich.",
        "handler": LabelSwap,
        "target_path": "Decor/Sign_TABLE_GAMES",
        "replacement_text": "TABLE G4MES"
    }
]

static func entries() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry in DEFINITIONS:
        result.append(entry.duplicate())
    return result

static func get_entry(id: String) -> Dictionary:
    for entry in DEFINITIONS:
        if str(entry["id"]) == id:
            return entry.duplicate()
    return {}

static func available_ids(room: Node3D) -> Array[String]:
    var result: Array[String] = []
    if room == null:
        return result
    for entry in DEFINITIONS:
        var handler: RefCounted = entry["handler"].new()
        if bool(handler.call("can_apply", room, entry)):
            result.append(str(entry["id"]))
    return result
