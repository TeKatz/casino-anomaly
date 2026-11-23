extends PanelContainer
## Shared player-facing archive/statistics UI (menu and pause).
signal back_pressed

const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const MenuStyle = preload("res://ui/menu_style.gd")
const GOLD := Color("#dcb477")
const MUTED := Color("#a5b0bb")
var mode := "archive"
var heading: Label
var tabs: HBoxContainer
var body: VBoxContainer
var back_button: Button


func _ready() -> void:
    custom_minimum_size = Vector2(760, 560)
    add_theme_stylebox_override("panel", MenuStyle.panel())
    var margin := MarginContainer.new()
    for side in ["left", "right"]:
        margin.add_theme_constant_override("margin_" + side, 25)
    margin.add_theme_constant_override("margin_top", 22)
    margin.add_theme_constant_override("margin_bottom", 22)
    add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 10)
    margin.add_child(stack)
    heading = _label(stack, "", 25, GOLD)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tabs = HBoxContainer.new()
    stack.add_child(tabs)
    for tab in ["archive", "stats", "last"]:
        var button := Button.new()
        button.custom_minimum_size.y = 35
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(show_mode.bind(tab))
        button.set_meta("mode", tab)
        tabs.add_child(button)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(690, 385)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    stack.add_child(scroll)
    body = VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 10)
    scroll.add_child(body)
    back_button = Button.new()
    back_button.custom_minimum_size.y = 39
    back_button.pressed.connect(func() -> void: back_pressed.emit())
    stack.add_child(back_button)
    refresh_language()


func _de() -> bool:
    var settings = get_node_or_null("/root/GameSettings")
    return settings != null and str(settings.get_option("language")) == "de"


func _word(de: String, en: String) -> String:
    return de if _de() else en


func _field(entry: Dictionary, field: String) -> String:
    return str(entry.get(field + ("_de" if _de() else "_en"), entry.get("id", "")))


func _label(parent: Node, value: String, size: int = 16,
        color: Color = Color.WHITE) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(label)
    return label


func show_mode(next_mode: String = "archive") -> void:
    mode = next_mode
    if is_node_ready():
        refresh_language()


func refresh_language() -> void:
    if not is_node_ready():
        return
    heading.text = _word("CASINO-ARCHIV", "CASINO ARCHIVE")
    for button in tabs.get_children():
        var key := str(button.get_meta("mode"))
        if key == "archive":
            button.text = _word("ANOMALIEN", "ANOMALIES")
        elif key == "stats":
            button.text = _word("STATISTIKEN", "STATISTICS")
        else:
            button.text = _word("LETZTE AUSWERTUNG", "LAST VERDICT")
        button.disabled = key == mode
    back_button.text = _word("ZURÜCK", "BACK")
    for child in body.get_children():
        body.remove_child(child)
        child.queue_free()
    var profiles := get_node_or_null("/root/ProfileManager")
    if profiles == null or profiles.active_slot == 0:
        _label(body, _word("Kein Profil ausgewählt.", "No profile selected."), 16, MUTED)
        return
    match mode:
        "archive": _render_archive(profiles)
        "stats": _render_stats(profiles)
        "last": _render_last(profiles)


func _render_archive(profiles: Node) -> void:
    var summary: Dictionary = profiles.active_summary()
    _label(body, _word("Entdeckte Anomalien: %d / %d · %.1f %%" \
        % [summary.get("discovered", 0), summary.get("total", 0), summary.get("percent", 0.0)],
        "Discovered anomalies: %d / %d · %.1f %%" \
        % [summary.get("discovered", 0), summary.get("total", 0), summary.get("percent", 0.0)]),
        18, GOLD)
    var saved: Dictionary = profiles.get_records()
    var entries: Array[Dictionary] = Catalog.entries()
    entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var category_a := _field(a, "category")
        var category_b := _field(b, "category")
        if category_a == category_b:
            return _field(a, "title") < _field(b, "title")
        return category_a < category_b
    )
    var current_category := ""
    var encountered := 0
    var unseen := 0
    for entry in entries:
        if not bool(entry.get("discoverable", true)):
            continue
        var record: Dictionary = saved.get(str(entry["id"]), {})
        # A miss does not count as identification. Even the category
        # remains hidden until this anomaly is correctly recognized.
        if not bool(record.get("recognized", false)):
            if record.is_empty():
                unseen += 1
            else:
                encountered += 1
            continue
        var category := _field(entry, "category")
        if category != current_category:
            current_category = category
            _label(body, "— " + category + " —", 17, GOLD)
        _label(body, _field(entry, "title"), 16, GOLD)
        _label(body, _field(entry, "description"), 14, MUTED)
        _label(body, _word("Richtig: %d · Übersehen: %d" % [
            int(record.get("correct", 0)), int(record.get("missed", 0))],
            "Correct: %d · Missed: %d" % [
            int(record.get("correct", 0)), int(record.get("missed", 0))]), 13, MUTED)
    # Aggregate still-locked entries so the category and precise anomaly
    # remain impossible to infer, even in future catalogs with 500+ effects.
    if encountered > 0 or unseen > 0:
        _label(body, _word("— NOCH NICHT IDENTIFIZIERT —",
            "— NOT YET IDENTIFIED —"), 17, GOLD)
        _label(body, _word("Unbestätigte Beobachtungen: %d", "Unconfirmed encounters: %d") \
            % encountered, 15, MUTED)
        _label(body, _word("Unbekannte Anomalien: %d", "Unknown anomalies: %d") \
            % unseen, 15, MUTED)
        _label(body, _word("Namen und Beschreibungen werden erst nach einer richtigen Erkennung sichtbar.",
            "Names and descriptions unlock only after correctly identifying an anomaly."),
            14, MUTED)


func _render_stats(profiles: Node) -> void:
    var stats: Dictionary = profiles.get_stats()
    var summary: Dictionary = profiles.active_summary()
    var rows := [
        [_word("Entdeckte Anomalien", "Discovered anomalies"),
            "%d / %d" % [summary.get("discovered", 0), summary.get("total", 0)]],
        [_word("Abgeschlossene Durchläufe", "Completed runs"),
            str(stats.get("completions", 0))],
        [_word("Untersuchte Räume", "Rooms inspected"), str(stats.get("rooms", 0))],
        [_word("Richtige Entscheidungen", "Correct decisions"), str(stats.get("correct", 0))],
        [_word("Fehlentscheidungen", "Wrong decisions"), str(stats.get("mistakes", 0))],
        [_word("Fehlalarme", "False alarms"), str(stats.get("false_alarms", 0))],
        [_word("Beste Serie", "Best streak"), str(stats.get("best_streak", 0))]
    ]
    for row in rows:
        _label(body, "%s: %s" % [row[0], row[1]], 17)
    _label(body, _word("Durch Entwicklerwerkzeuge erzwungene Räume zählen nicht.",
        "Rooms forced with developer tools are excluded."), 13, MUTED)


func _render_last(profiles: Node) -> void:
    var verdict: Dictionary = profiles.latest_report()
    if verdict.is_empty():
        _label(body, _word("Noch keine Entscheidung gespeichert.",
            "No recorded decisions yet."), 16, MUTED)
        return
    var correct := bool(verdict.get("correct", false))
    var anomaly_present := bool(verdict.get("expected_anomaly",
        not str(verdict.get("anomaly_id", "")).is_empty()))
    var chose := bool(verdict.get("choice_anomaly", false))
    _label(body, _word("BESTÄTIGT", "ACCEPTED") if correct \
        else _word("NICHT BESTÄTIGT", "REJECTED"), 20,
        Color("#8cd4ac") if correct else Color("#f2a3a3"))
    _label(body, _word("Prüfung %d · Deine Wahl: %s" % [
        int(verdict.get("visited", 0)), "ANOMALIE" if chose else "NORMAL"],
        "Review %d · Your choice: %s" % [
        int(verdict.get("visited", 0)), "ANOMALY" if chose else "NORMAL"]), 16)
    _label(body, _word("Befund: Abweichung" if anomaly_present \
        else "Befund: Unauffällig",
        "Finding: Irregular" if anomaly_present else "Finding: Clear"), 16, MUTED)
    if not correct:
        _label(body, _word("Serie: %d → 0" % int(verdict.get("previous_streak", 0)),
            "Streak: %d → 0" % int(verdict.get("previous_streak", 0))), 16, MUTED)
    _label(body, _word("Einzelheiten findest du ausschließlich bei korrekt identifizierten Anomalien im Archiv.",
        "Detailed descriptions are available only for correctly identified anomalies in the archive."),
        14, MUTED)
