extends RefCounted
## Data-driven anomaly catalog. Add ONE CasinoAnomalyDefinition .tres to
## anomaly_definitions/; it is automatically available in gameplay and archive.
## ResourceLoader.list_directory works with exported .pck resources in Godot 4.5.
const DEFINITION_DIR := "res://gameplay/anomaly_definitions"
# Deliberately less specific than archive descriptions. Every family has its
# own clue; variants inherit the family's clue rather than reveal the variant.
const REVIEW_HINTS := {
    "against_gravity": ["Some movement defied its natural direction.", "Eine Bewegung widersprach ihrer natürlichen Richtung."],
    "amber_ceiling_light": ["Compare the warmth of the light between areas.", "Vergleiche die Wärme des Lichts in den Bereichen."],
    "backrooms": ["The usual route did not lead where it should.", "Der gewohnte Weg führte nicht ans erwartete Ziel."],
    "bar_label": ["Read familiar words more carefully.", "Lies vertraute Schriftzüge etwas genauer."],
    "bare_monstera": ["Something living-looking seemed unusually sparse.", "Etwas Lebendigwirkendes erschien ungewöhnlich kahl."],
    "black_bloom": ["Watch for subtle changes on large surfaces.", "Achte auf kleine Veränderungen großer Flächen."],
    "blank_reels": ["A familiar display was missing visual detail.", "Einer vertrauten Anzeige fehlten visuelle Details."],
    "blue_runner": ["A familiar surface had an unfamiliar color.", "Eine vertraute Fläche hatte eine fremde Farbe."],
    "burgundy_felt": ["Compare the colors around the gaming area.", "Vergleiche die Farben im Spielbereich."],
    "bust_turned": ["Pay attention to which way objects face.", "Achte darauf, wohin Gegenstände ausgerichtet sind."],
    "candleholder_shifted": ["Small objects were not quite centered.", "Kleine Gegenstände standen nicht ganz mittig."],
    "cool_ceiling_light": ["The light felt colder in one area.", "In einem Bereich wirkte das Licht kälter."],
    "crimson_hall": ["The overall lighting mood had changed.", "Die allgemeine Lichtstimmung hatte sich verändert."],
    "crooked_painting": ["Look for slight departures from straight lines.", "Achte auf kleine Abweichungen von geraden Linien."],
    "dark_marquee": ["Some familiar illuminated details were absent.", "Einige vertraute Leuchtdetails fehlten."],
    "empty_footsteps": ["The floor showed signs of an unseen presence.", "Der Boden verriet eine unsichtbare Anwesenheit."],
    "empty_reserve": ["Compare the small details of repeated objects.", "Vergleiche kleine Details ähnlicher Gegenstände."],
    "entrance_label": ["A familiar word was almost, but not quite, right.", "Ein vertrautes Wort war beinahe, aber nicht ganz richtig."],
    "extra_guest": ["The quiet areas held more than expected.", "In den ruhigen Bereichen war mehr als erwartet."],
    "false_jackpot": ["A display was demanding unusual attention.", "Eine Anzeige zog ungewöhnlich viel Aufmerksamkeit auf sich."],
    "floating_hand": ["Something was not resting where it should.", "Etwas ruhte nicht dort, wo es sollte."],
    "forgotten_door": ["Something unfamiliar reacted to your approach.", "Etwas Unvertrautes reagierte auf deine Annäherung."],
    "horse_spotlight_off": ["A decorative area was lit unusually.", "Ein dekorativer Bereich war ungewöhnlich beleuchtet."],
    "inverted_cat": ["Some decorative spaces were unexpectedly empty.", "Einige dekorative Plätze waren unerwartet leer."],
    "invisible_dealer": ["Watch what happens at unattended games.", "Beobachte, was an unbeaufsichtigten Spielen passiert."],
    "last_kings": ["A familiar arrangement had lost some pieces.", "Einer vertrauten Anordnung fehlten einzelne Teile."],
    "lightless_horse": ["One object responded strangely to the light.", "Ein Gegenstand reagierte seltsam auf das Licht."],
    "missing_hand": ["Look for what is absent, not just what is new.", "Achte auf Fehlendes, nicht nur auf Neues."],
    "ownerless_shadow": ["Light and its traces did not quite agree.", "Licht und seine Spuren passten nicht ganz zusammen."],
    "pendulum": ["Look above eye level for subtle movement.", "Achte oberhalb der Augenhöhe auf kleine Bewegungen."],
    "plant_forward": ["Compare objects along the walking route.", "Vergleiche Gegenstände entlang des Laufwegs."],
    "silent_countdown": ["Notice displays and sounds that share a rhythm.", "Achte auf Anzeigen und Geräusche mit gleichem Rhythmus."],
    "stay_here": ["Familiar messages conveyed an unusual intent.", "Vertraute Hinweise vermittelten eine fremde Absicht."],
    "stool_out_of_line": ["Repeated objects did not line up as usual.", "Ähnliche Gegenstände standen nicht wie gewohnt in Reihe."],
    "synchronized_busts": ["Some still objects seemed to move together.", "Manche regungslosen Dinge schienen sich gemeinsam zu bewegen."],
    "table_label": ["Check the lettering between different areas.", "Prüfe die Beschriftung der verschiedenen Bereiche."],
    "the_escort": ["Your position seemed to influence a presence.", "Dein Standort schien eine Anwesenheit zu beeinflussen."],
    "the_flood": ["The floor behaved differently as time passed.", "Der Boden verhielt sich mit der Zeit anders."],
    "the_other_side": ["The room concealed an impossible perspective.", "Der Raum verbarg eine unmögliche Perspektive."],
    "they_are_listening": ["Notice how the atmosphere changes with location.", "Achte darauf, wie sich die Atmosphäre je nach Ort verändert."],
    "unfinished_game": ["Something continued without the expected end.", "Etwas setzte sich ohne das erwartete Ende fort."],
    "watchful_camera": ["Small technical details indicated unusual activity.", "Kleine technische Details verrieten ungewöhnliche Aktivität."],
    "watching_canvases": ["Some decoration seemed less static than usual.", "Manche Dekoration wirkte weniger regungslos als gewohnt."],
    "west_chandelier_dim": ["Compare the light sources above the room.", "Vergleiche die Lichtquellen oberhalb des Raums."],
    "wrong_reflection": ["Compare the room with what it seems to reflect.", "Vergleiche den Raum mit dem, was er zu spiegeln scheint."],
}
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


# These are stable collection keys, not necessarily selectable definition IDs.
# A family survives the retirement of its original form.
static func discoverable_ids() -> Array[String]:
    _ensure_loaded()
    var result: Array[String] = []
    for entry in _entries:
        var key := str(entry.get("family_id", entry["id"]))
        if bool(entry.get("discoverable", true)) and not result.has(key):
            result.append(key)
    return result


# Prefer the original active form; otherwise use a deterministic active
# representative. Never make a retired ID resolve through get_entry().
static func family_entry(id: String) -> Dictionary:
    _ensure_loaded()
    var fallback: Dictionary = {}
    for entry in _entries:
        if str(entry.get("family_id", entry["id"])) != id:
            continue
        if fallback.is_empty() or (not bool(fallback.get("discoverable", true)) and bool(entry.get("discoverable", true))):
            fallback = entry
        if str(entry["id"]) == id and bool(entry.get("discoverable", true)):
            return entry.duplicate()
    return fallback.duplicate()


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

static func family(id: String) -> String:
    var entry := get_entry(id)
    return str(entry.get("family_id", id))

static func family_entries(id: String) -> Array[Dictionary]:
    _ensure_loaded()
    var result: Array[Dictionary] = []
    for entry in _entries:
        if str(entry.get("family_id", entry["id"])) == id and bool(entry.get("discoverable", true)):
            result.append(entry.duplicate())
    return result

static func rarity_weight(rarity: String) -> float:
    return float({"common": 50.0, "uncommon": 27.0, "rare": 15.0, "exceptional": 6.0, "singularity": 2.0}.get(rarity, 50.0))

static func rarity_name(rarity: String, de: bool) -> String:
    var names := {"common": ["Gewöhnlich", "Common"], "uncommon": ["Ungewöhnlich", "Uncommon"],
        "rare": ["Selten", "Rare"], "exceptional": ["Außergewöhnlich", "Exceptional"],
        "singularity": ["Singularität", "Singularity"]}
    return str(names.get(rarity, names["common"])[0 if de else 1])


static func review_hint(id: String, de: bool) -> String:
    var pair: Array = REVIEW_HINTS.get(family(id), [])
    return str(pair[1 if de else 0]) if pair.size() == 2 else ""


static func missed_review_hint(verdict: Dictionary, de: bool) -> String:
    var id := str(verdict.get("anomaly_id", ""))
    if id.is_empty() or bool(verdict.get("correct", false)) or bool(verdict.get("choice_anomaly", false)) or bool(verdict.get("traversal", false)):
        return ""
    if not bool(verdict.get("expected_anomaly", true)):
        return ""
    return review_hint(id, de)
