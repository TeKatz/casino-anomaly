extends RefCounted
## Pure profile progression. Legacy stats are converted once; stable IDs
## and earned achievement flags survive changes to balancing and catalog.
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const Modes = preload("res://gameplay/run_modes.gd")
const VERSION := 1
const MAX_LEVEL := 100

static func xp_for_next(level: int) -> int:
    return 150 + (level - 1) * 25

static func level_info(xp: int) -> Dictionary:
    var level := 1
    var remaining := maxi(xp, 0)
    while level < MAX_LEVEL and remaining >= xp_for_next(level):
        remaining -= xp_for_next(level)
        level += 1
    return {"level": level, "xp": xp, "current": remaining if level < MAX_LEVEL else 0,
        "next": xp_for_next(level) if level < MAX_LEVEL else 0}

static func rank(level: int, de: bool) -> String:
    var ranks := [[100, "Jenseits der Ordnung", "Beyond Order"],
        [75, "Wächter der Realität", "Reality Guardian"], [50, "Grenzgänger", "Threshold Walker"],
        [35, "Realitätsprüfer", "Reality Examiner"], [20, "Anomalieforscher", "Anomaly Researcher"],
        [10, "Spurenleser", "Trace Reader"], [5, "Beobachter", "Observer"], [1, "Besucher", "Visitor"]]
    for item in ranks:
        if level >= int(item[0]):
            return str(item[1 if de else 2])
    return ""

static func mastery(count: int, de: bool) -> String:
    if count >= 5: return "Gemeistert" if de else "Mastered"
    if count >= 3: return "Erforscht" if de else "Studied"
    return "Identifiziert" if de else "Identified"

static func migrate(stats: Dictionary, records: Dictionary) -> void:
    if int(stats.get("progression_version", 0)) >= VERSION:
        return
    var anomalies := 0
    var discoveries := 0
    for id in records:
        var record: Dictionary = records[id]
        var count := maxi(0, int(record.get("correct", 0)))
        anomalies += count
        if bool(record.get("recognized", false)):
            discoveries += 1
            record["variants"] = {id: true}
        records[id] = record
    var backrooms := int(records.get("backrooms", {}).get("correct", 0))
    var normal := maxi(0, int(stats.get("correct", 0)) - anomalies)
    var completed := int(stats.get("completions", 0))
    stats["xp"] = normal * 25 + maxi(0, anomalies - backrooms) * 50 + backrooms * 200 + discoveries * 150 + completed * 500
    stats["normal_correct"] = normal
    stats["anomaly_correct"] = anomalies
    stats["backrooms_completed"] = backrooms
    stats["classic_completions"] = completed
    stats["mode_records"] = {"classic": {"completed": completed, "best": int(stats.get("best_streak", 0))}}
    stats["achievements"] = {}
    stats["progression_version"] = VERSION

static func counts(records: Dictionary) -> Dictionary:
    var discovered := 0
    var mastered := 0
    var studied := 0
    var variants := 0
    var variant_total := 0
    for id in Catalog.discoverable_ids():
        var record: Dictionary = records.get(id, {})
        if bool(record.get("recognized", false)):
            discovered += 1
        var correct := int(record.get("correct", 0))
        if correct >= 3: studied += 1
        if correct >= 5: mastered += 1
        for entry in Catalog.family_entries(id):
            variant_total += 1
            if bool(record.get("variants", {}).get(entry["id"], false)):
                variants += 1
    return {"discovered": discovered, "mastered": mastered, "studied": studied,
        "variants": variants, "variant_total": variant_total}

static func award(stats: Dictionary, records: Dictionary, verdict: Dictionary, first: bool) -> int:
    var xp := 0
    var correct := bool(verdict.get("correct", false))
    var id := str(verdict.get("anomaly_id", ""))
    var mode := Modes.normalize(str(verdict.get("mode", "classic")))
    if correct:
        if id.is_empty():
            xp += 25
            stats["normal_correct"] = int(stats.get("normal_correct", 0)) + 1
            stats["normal_chain"] = int(verdict.get("normal_chain", 0))
            if not bool(verdict.get("assisted", false)):
                stats["best_normal_chain"] = maxi(int(stats.get("best_normal_chain", 0)), int(stats["normal_chain"]))
        else:
            xp += 200 if id == "backrooms" else 50
            stats["anomaly_correct"] = int(stats.get("anomaly_correct", 0)) + 1
            if id == "backrooms":
                stats["backrooms_completed"] = int(stats.get("backrooms_completed", 0)) + 1
            if first:
                xp += 150
    if not correct or not id.is_empty():
        stats["normal_chain"] = 0
    # Debugged decisions are rejected by ProfileManager. Other honest
    # decisions still award XP, but a manipulated run cannot earn records.
    if not bool(verdict.get("assisted", false)):
        var all_modes: Dictionary = stats.get("mode_records", {})
        var record: Dictionary = all_modes.get(mode, {})
        var streak := maxi(int(verdict.get("streak", 0)), int(verdict.get("previous_streak", 0)))
        if mode in ["classic", "endless", "nightmare"]:
            record["best"] = maxi(int(record.get("best", 0)), streak)
        if bool(verdict.get("finished", false)):
            record["runs"] = int(record.get("runs", 0)) + 1
            if not bool(verdict.get("failed", false)):
                record["completed"] = int(record.get("completed", 0)) + 1
                if mode == "classic":
                    stats["classic_completions"] = int(stats.get("classic_completions", 0)) + 1
                xp += 500 if mode in ["classic", "nightmare"] else (0 if mode == "expedition" else 200)
                if int(verdict.get("mistakes", 0)) == 0 and mode != "expedition":
                    stats["perfect_runs"] = int(stats.get("perfect_runs", 0)) + 1
                    xp += 750 if mode in ["classic", "nightmare"] else 200
                if mode == "time_trial":
                    var time := float(verdict.get("score_seconds", 0.0))
                    if time > 0.0:
                        var best := float(record.get("best_time", 0.0))
                        record["best_time"] = time if best <= 0.0 else minf(best, time)
                if mode == "classic" and int(verdict.get("mistakes", 0)) > 0:
                    stats["comebacks"] = int(stats.get("comebacks", 0)) + 1
        all_modes[mode] = record
        stats["mode_records"] = all_modes
    stats["xp"] = int(stats.get("xp", 0)) + xp
    return xp

static func achievement_definitions() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    # Stable IDs; localized names, descriptions and thresholds are data.
    var groups := [
        ["correct", "Richtige Entscheidungen", "Correct decisions", [1, 25, 100, 500, 1000], ["Der erste Schritt", "Aufmerksam", "Routine", "Unermüdlich", "Tausend Prüfungen"], ["First step", "Attentive", "Routine", "Relentless", "A thousand reviews"]],
        ["normal_correct", "Normale Räume korrekt erkannt", "Clear rooms correctly recognized", [10, 50, 250], ["Klarer Blick", "Nichts verändert", "Vertrauen"], ["Clear sight", "Nothing changed", "Trust"]],
        ["anomaly_correct", "Anomalien korrekt erkannt", "Anomalies correctly recognized", [5, 25, 100, 500], ["Erste Risse", "Spurenleser", "Geschultes Auge", "Realitätsprüfer"], ["First cracks", "Trace reader", "Trained eye", "Reality examiner"]],
        ["classic_completions", "Klassische Abschlüsse", "Classic completions", [1, 5, 10, 25], ["Es gibt einen Ausgang", "Wiederkehrer", "Stammgast", "Das Casino kennt dich"], ["There is an exit", "Returning guest", "Regular", "The casino knows you"]],
        ["level", "Spielerlevel", "Player level", [5, 10, 20, 35, 50, 75, 100], ["Beobachter", "Spurenleser", "Forscher", "Prüfer", "Grenzgänger", "Wächter", "Jenseits der Ordnung"], ["Observer", "Trace reader", "Researcher", "Examiner", "Threshold walker", "Guardian", "Beyond Order"]],
        ["discovered", "Anomaliefamilien identifiziert", "Anomaly families identified", [1, 5, 10], ["Erster Befund", "Archivist", "Sammler"], ["First finding", "Archivist", "Collector"]],
        ["mastered", "Anomaliefamilien gemeistert", "Anomaly families mastered", [1, 5, 10], ["Vertraute Abweichung", "Spezialist", "Meister der Abweichungen"], ["Familiar irregularity", "Specialist", "Master of irregularities"]],
        ["variants", "Erscheinungsformen identifiziert", "Forms identified", [10, 20, 30], ["Facetten", "Variationen", "Muster hinter dem Muster"], ["Facets", "Variations", "Pattern behind the pattern"]],
        ["endless_best", "Endlos-Serie", "Endless streak", [10, 25, 50, 100], ["Ohne Ende", "Standhaft", "Unaufhaltsam", "Unendlichkeit"], ["No end", "Steadfast", "Unstoppable", "Infinity"]],
        ["perfect_runs", "Fehlerfreie Durchläufe", "Flawless runs", [1, 5], ["Nichts entgeht dir", "Makellos"], ["Nothing escapes you", "Flawless"]],
        ["best_normal_chain", "Normale Räume in Folge erkannt", "Consecutive clear rooms recognized", [10], ["Paranoia unter Kontrolle"], ["Paranoia under control"]]
    ]
    for group in groups:
        for i in range(group[3].size()):
            var goal := int(group[3][i])
            result.append({"id": str(group[0]) + "_" + str(goal), "metric": group[0], "goal": goal,
                "de": group[4][i], "en": group[5][i], "description_de": "%s: %d" % [group[1], goal],
                "description_en": "%s: %d" % [group[2], goal], "secret": false})
    for item in [
        ["archive_complete", "archive_complete", 1, "Realitätsforscher", "Reality researcher", "Identifiziere alle Anomaliefamilien.", "Identify every anomaly family.", false],
        ["mastery_complete", "mastery_complete", 1, "Das ganze Bild", "The whole picture", "Meistere alle Anomaliefamilien.", "Master every anomaly family.", false],
        ["nightmare_clear", "nightmare_completed", 1, "Erwacht", "Awakened", "Schließe Albtraum ab.", "Complete Nightmare.", false],
        ["trial_clear", "time_trial_completed", 1, "Gegen die Uhr", "Against the clock", "Schließe eine Zeitprüfung ab.", "Complete a time trial.", false],
        ["research_clear", "research_completed", 1, "Feldforschung", "Field research", "Schließe Forschung ab.", "Complete Research.", false],
        ["expedition_clear", "expedition_completed", 1, "Rückkehrer", "Returnee", "Schließe eine Expedition ab.", "Complete an expedition.", true],
        ["backrooms_first", "backrooms_completed", 1, "Ein Ort, der nicht existiert", "A place that does not exist", "Finde den Ausgang aus den Backrooms.", "Escape the Backrooms.", true],
        ["backrooms_five", "backrooms_completed", 5, "Vertraute Fremde", "Familiar stranger", "Schließe die Backrooms fünfmal ab.", "Escape the Backrooms five times.", true],
        ["comeback", "comebacks", 1, "Trotz allem", "Against all odds", "Schließe Klassisch nach einem Fehler ab.", "Complete Classic after a mistake.", true]
    ]:
        result.append({"id": item[0], "metric": item[1], "goal": item[2], "de": item[3], "en": item[4],
            "description_de": item[5], "description_en": item[6], "secret": item[7]})
    return result

static func metrics(stats: Dictionary, records: Dictionary) -> Dictionary:
    var values := stats.duplicate()
    var collection := counts(records)
    values.merge(collection, true)
    values["level"] = level_info(int(stats.get("xp", 0)))["level"]
    var total := Catalog.discoverable_ids().size()
    values["archive_complete"] = int(total > 0 and int(collection["discovered"]) >= total)
    values["mastery_complete"] = int(total > 0 and int(collection["mastered"]) >= total)
    for mode in Modes.IDS:
        var record: Dictionary = stats.get("mode_records", {}).get(mode, {})
        values[mode + "_best"] = int(record.get("best", 0))
        if mode != "classic":
            values[mode + "_completed"] = int(record.get("completed", 0))
    return values

static func evaluate(stats: Dictionary, records: Dictionary) -> void:
    var unlocked: Dictionary = stats.get("achievements", {})
    var values := metrics(stats, records)
    for entry in achievement_definitions():
        if int(values.get(entry["metric"], 0)) >= int(entry["goal"]):
            unlocked[entry["id"]] = true
    stats["achievements"] = unlocked
