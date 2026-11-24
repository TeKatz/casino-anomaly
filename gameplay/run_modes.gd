extends RefCounted
const IDS := ["classic", "endless", "nightmare", "time_trial", "research", "expedition"]
const PENALTY_SECONDS := 20.0

static func normalize(id: String) -> String:
    return id if IDS.has(id) else "classic"

static func title(id: String, de: bool) -> String:
    var names := {"classic": ["Klassisch", "Classic"], "endless": ["Endlos", "Endless"],
        "nightmare": ["Albtraum", "Nightmare"], "time_trial": ["Zeitprüfung", "Time trial"],
        "research": ["Forschung", "Research"], "expedition": ["Expedition", "Expedition"]}
    return str(names[normalize(id)][0 if de else 1])

static func description(id: String, de: bool) -> String:
    var descriptions := {
        "classic": ["12 richtige Entscheidungen in Folge. Fehler setzen die Serie zurück.", "12 consecutive correct decisions. Mistakes reset the streak."],
        "endless": ["Eine Fehlentscheidung beendet den Lauf. Wie weit kommst du?", "One mistake ends the run. How far can you go?"],
        "nightmare": ["12 richtige Entscheidungen, kein Fehler erlaubt. Subtile Varianten sind häufiger.", "12 correct decisions, no mistakes allowed. Subtle variants are more frequent."],
        "time_trial": ["12 Räume. Jeder Fehler kostet 20 Sekunden. Pausen zählen nicht.", "12 rooms. Each mistake adds 20 seconds. Pauses do not count."],
        "research": ["20 Räume ohne Serien-Reset. Unbekannte Anomalien werden bevorzugt.", "20 rooms without streak resets. Unknown anomalies are prioritized."],
        "expedition": ["Referenzraum, dann eine garantierte Backrooms-Expedition. Finde den Ausgang.", "Reference room, then a guaranteed Backrooms expedition. Find the exit."]}
    return str(descriptions[normalize(id)][0 if de else 1])

static func target(id: String) -> int:
    match id:
        "endless": return 0
        "research": return 20
        "expedition": return 2
        _: return 12

static func unlock(id: String, stats: Dictionary, records: Dictionary) -> bool:
    if id == "nightmare":
        return int(stats.get("classic_completions", stats.get("completions", 0))) > 0
    if id == "expedition":
        return bool(records.get("backrooms", {}).get("recognized", false))
    return true

static func unlock_hint(id: String, de: bool) -> String:
    if id == "nightmare":
        return "Schließe Klassisch ab." if de else "Complete Classic."
    if id == "expedition":
        return "Identifiziere eine Singularität." if de else "Identify a singularity."
    return ""
