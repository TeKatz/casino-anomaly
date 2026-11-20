extends RefCounted
## Authoritative registry. New anomalies only need one entry referencing an
## effect module with can_apply(room, definition), apply(room, definition),
## clear(). The game and the developer picker discover it automatically.
const LabelSwap = preload("res://gameplay/anomalies/label_swap.gd")
const PropTransform = preload("res://gameplay/anomalies/prop_transform.gd")
const LightVariation = preload("res://gameplay/anomalies/light_variation.gd")
const ChandelierBlackout = preload("res://gameplay/anomalies/chandelier_blackout.gd")
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
    },

    # Six small misplaced/rotated props. The original model, authored
    # collider, and relative child transforms remain intact.
    {
        "id": "stool_out_of_line",
        "category_en": "Objects", "category_de": "Gegenstände",
        "title_en": "Bar stool out of line", "title_de": "Verrückter Barhocker",
        "description_en": "One counter stool stands a little farther into the room.",
        "description_de": "Ein Barhocker steht etwas weiter im Raum.",
        "handler": PropTransform,
        "target_path": "ModelInteriors/CounterStool_04",
        "position_offset": Vector3(0.25, 0.0, 0.78)
    },
    {
        "id": "plant_forward",
        "category_en": "Objects", "category_de": "Gegenstände",
        "title_en": "Plant farther forward", "title_de": "Vorgezogene Pflanze",
        "description_en": "A lounge plant is closer to the walkway.",
        "description_de": "Eine Pflanze steht näher am Gang.",
        "handler": PropTransform,
        "target_path": "Decor/Plant_02",
        "position_offset": Vector3(0.0, 0.0, -0.90)
    },
    {
        "id": "plant_misplaced",
        "category_en": "Objects", "category_de": "Gegenstände",
        "title_en": "Plant shifted sideways", "title_de": "Seitlich versetzte Pflanze",
        "description_en": "Another planter is no longer in its usual spot.",
        "description_de": "Ein anderer Pflanzkübel steht seitlich versetzt.",
        "handler": PropTransform,
        "target_path": "Decor/Plant_04",
        # In the gap between sofas 03/04, towards the aisle rather than
        # towards the north wall (the old +Z offset caused clipping).
        "position_offset": Vector3(0.45, 0.0, -0.80)
    },
    {
        "id": "crooked_painting",
        "category_en": "Objects", "category_de": "Gegenstände",
        "title_en": "Crooked painting", "title_de": "Schiefes Gemälde",
        "description_en": "A framed picture hangs at a slight angle.",
        "description_de": "Ein gerahmtes Gemälde hängt leicht schief.",
        "handler": PropTransform,
        "target_path": "ModelInteriors/FramedPainting_02",
        "position_offset": Vector3(0.0, 0.22, 0.0),
        "rotation_degrees": Vector3(0.0, 0.0, 7.0)
    },
    {
        "id": "candleholder_shifted",
        "category_en": "Objects", "category_de": "Gegenstände",
        "title_en": "Moved candleholder", "title_de": "Verrückter Kerzenhalter",
        "description_en": "A brass candleholder sits off-center on its table.",
        "description_de": "Ein Messingkerzenhalter steht nicht mehr mittig.",
        "handler": PropTransform,
        "target_path": "ModelInteriors/SingleBrassCandleholder_02",
        "position_offset": Vector3(0.26, 0.0, 0.12)
    },
    {
        "id": "bust_turned",
        "category_en": "Objects", "category_de": "Gegenstände",
        "title_en": "Turned marble bust", "title_de": "Verdrehte Marmorbüste",
        "description_en": "The statue's head faces a different direction.",
        "description_de": "Eine Marmorbüste blickt in eine andere Richtung.",
        "handler": PropTransform,
        "target_path": "ModelInteriors/MarbleBust_02",
        "rotation_degrees": Vector3(0.0, 35.0, 0.0)
    },

    # Four readable lighting changes: a full chandelier blackout, stronger
    # color shifts, and a powerful red statue spotlight.
    {
        "id": "west_chandelier_dim",
        "category_en": "Lighting", "category_de": "Beleuchtung",
        "title_en": "Chandeliers switched off", "title_de": "Alle Kronleuchter ausgeschaltet",
        "description_en": "Every chandelier light in the casino is extinguished.",
        "description_de": "Sämtliche Kronleuchter im Casino sind unbeleuchtet.",
        "handler": ChandelierBlackout,
        # Retained for catalog/UI test compatibility. The handler disables
        # all real chandelier lights, including additional nested lights.
        "target_path": "Lighting/WarmCasinoLamp_05"
    },
    {
        "id": "cool_ceiling_light",
        "category_en": "Lighting", "category_de": "Beleuchtung",
        "title_en": "Cool ceiling light", "title_de": "Kühles Deckenlicht",
        "description_en": "One warm overhead light has a strong bluish tint.",
        "description_de": "Ein warmes Deckenlicht wirkt plötzlich deutlich bläulich.",
        "handler": LightVariation,
        "target_path": "Lighting/WarmCasinoLamp_06",
        "color": Color("#72bfff"),
        "energy_scale": 1.90
    },
    {
        "id": "amber_ceiling_light",
        "category_en": "Lighting", "category_de": "Beleuchtung",
        "title_en": "Amber ceiling light", "title_de": "Bernsteinfarbenes Licht",
        "description_en": "A corridor section glows in a strong orange-red light.",
        "description_de": "Ein Gangabschnitt leuchtet deutlich kräftiger orange-rot.",
        "handler": LightVariation,
        "target_path": "Lighting/WarmCasinoLamp_03",
        "color": Color("#ff641e"),
        "energy_scale": 3.40
    },
    {
        "id": "horse_spotlight_off",
        "category_en": "Lighting", "category_de": "Beleuchtung",
        "title_en": "Red horse spotlight", "title_de": "Roter Pferde-Spot",
        "description_en": "The horse statue is brightly lit by a red spotlight.",
        "description_de": "Die Pferdestatue wird von einem sehr hellen roten Spot angestrahlt.",
        "handler": LightVariation,
        # Keep the stable ID so existing saves/debug selections do not break.
        "target_path": "CasinoAtmosphere/HorseHighlight",
        "color": Color("#ff7777"),
        "energy_scale": 5.60,
        "visible": true
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
