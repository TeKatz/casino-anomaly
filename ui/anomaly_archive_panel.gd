extends PanelContainer
## Shared player-facing archive/statistics UI (menu and pause).
signal back_pressed

const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const Progress = preload("res://gameplay/progression.gd")
const Modes = preload("res://gameplay/run_modes.gd")
const MenuStyle = preload("res://ui/menu_style.gd")
const LuminousButton = preload("res://ui/luminous_button.gd")
const GOLD := Color("#dcb477")
const MUTED := Color("#a5b0bb")
var mode := "archive"
var heading: Label
var tabs: HBoxContainer
var body: VBoxContainer
var back_button: Button
var body_tween: Tween


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
    for tab in ["archive", "stats", "achievements", "modes", "last"]:
        var button := LuminousButton.new()
        button.symbol = "archive" if tab == "archive" else ("stats" if tab in ["stats", "achievements", "modes"] else "history")
        button.add_theme_font_size_override("font_size", 12)
        button.custom_minimum_size.y = 39
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
    back_button = LuminousButton.new()
    (back_button as LuminousButton).symbol = "back"
    back_button.custom_minimum_size.y = 41
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
    if not is_node_ready():
        return
    refresh_language()
    if body_tween != null and body_tween.is_running():
        body_tween.kill()
    body.modulate.a = 0.0
    body_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    body_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    body_tween.tween_property(body, "modulate:a", 1.0, 0.19)


func refresh_language() -> void:
    if not is_node_ready():
        return
    heading.text = _word("CASINO-ARCHIV", "CASINO ARCHIVE")
    for button in tabs.get_children():
        var key := str(button.get_meta("mode"))
        if key == "archive":
            button.text = _word("ANOMALIEN", "ANOMALIES")
        elif key == "stats":
            button.text = _word("PROFIL", "PROFILE")
        elif key == "achievements":
            button.text = _word("ERFOLGE", "ACHIEVEMENTS")
        elif key == "modes":
            button.text = _word("MODI", "MODES")
        else:
            button.text = _word("AUSWERTUNG", "VERDICT")
        button.disabled = false
        MenuStyle.apply_button(button, key == mode, "amber" if key == mode else "gold")
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
        "achievements": _render_achievements(profiles)
        "modes": _render_modes(profiles)
        "last": _render_last(profiles)


func _card(parent: Node) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#17221e")
    style.border_color = Color("#514b37")
    style.set_border_width_all(1)
    style.set_corner_radius_all(6)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 5)
    panel.add_child(stack)
    return stack


func _progress_bar(parent: Node, current: float, maximum: float) -> void:
    var bar := ProgressBar.new()
    bar.custom_minimum_size.y = 9
    bar.show_percentage = false
    bar.max_value = maxf(1.0, maximum)
    bar.value = current
    var track := StyleBoxFlat.new()
    track.bg_color = Color("#343c35")
    track.set_corner_radius_all(4)
    var fill := StyleBoxFlat.new()
    fill.bg_color = GOLD
    fill.set_corner_radius_all(4)
    bar.add_theme_stylebox_override("background", track)
    bar.add_theme_stylebox_override("fill", fill)
    parent.add_child(bar)


func _render_archive(profiles: Node) -> void:
    var saved: Dictionary = profiles.get_records()
    var count := Progress.counts(saved)
    var total := Catalog.discoverable_ids().size()
    _label(body, _word("Identifiziert: %d / %d · Gemeistert: %d", "Identified: %d / %d · Mastered: %d") % [
        count["discovered"], total, count["mastered"]], 18, GOLD)
    _progress_bar(body, float(count["discovered"]), float(total))
    _label(body, _word("Erscheinungsformen: %d / %d", "Forms identified: %d / %d") % [count["variants"], count["variant_total"]], 14, MUTED)
    var entries: Array[Dictionary] = Catalog.entries()
    entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return (_field(a, "category") + _field(a, "title")) < (_field(b, "category") + _field(b, "title")))
    var current_category := ""
    var encountered := 0
    var unseen := 0
    var grid: GridContainer
    for entry in entries:
        var id := str(entry["id"])
        if not bool(entry.get("discoverable", true)) or Catalog.family(id) != id:
            continue
        var record: Dictionary = saved.get(id, {})
        if not bool(record.get("recognized", false)):
            if record.is_empty(): unseen += 1
            else: encountered += 1
            continue
        var category := _field(entry, "category")
        if category != current_category or grid == null:
            current_category = category
            _label(body, category.to_upper(), 16, GOLD)
            grid = GridContainer.new()
            grid.columns = 2
            grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            grid.add_theme_constant_override("h_separation", 10)
            grid.add_theme_constant_override("v_separation", 10)
            body.add_child(grid)
        var card := _card(grid)
        var rarity := str(entry.get("rarity", "common"))
        var colors := {"common": MUTED, "uncommon": Color("#8fc7a1"), "rare": Color("#91baf0"),
            "exceptional": Color("#bf9bdf"), "singularity": GOLD}
        _label(card, Catalog.rarity_name(rarity, _de()).to_upper(), 12, colors.get(rarity, MUTED))
        _label(card, _field(entry, "title"), 18, GOLD)
        var found: Dictionary = record.get("variants", {})
        # If only a variant was identified, never reveal the unobserved
        # base form's exact clue. The known variant details appear below.
        if bool(found.get(id, false)):
            _label(card, _field(entry, "description"), 14, MUTED)
        var correct := int(record.get("correct", 0))
        _label(card, Progress.mastery(correct, _de()) + " · " + str(correct) + " / 5", 14, GOLD)
        _progress_bar(card, float(mini(correct, 5)), 5)
        _label(card, _word("Richtig: %d · Übersehen: %d", "Correct: %d · Missed: %d") % [correct, int(record.get("missed", 0))], 13, MUTED)
        var variants := Catalog.family_entries(id)
        if variants.size() > 1:
            var known := 0
            for variant in variants:
                if bool(found.get(variant["id"], false)):
                    known += 1
            _label(card, _word("Formen: %d / %d", "Forms: %d / %d") % [known, variants.size()], 13, GOLD)
            for variant in variants:
                if not bool(found.get(variant["id"], false)):
                    continue
                var name := _field(variant, "variant_name")
                if name.is_empty():
                    name = _word("Grundform", "Base form")
                _label(card, "· " + name, 12, MUTED)
    if encountered > 0 or unseen > 0:
        var locked := _card(body)
        _label(locked, _word("— NOCH NICHT IDENTIFIZIERT —", "— NOT YET IDENTIFIED —"), 17, GOLD)
        _label(locked, _word("Unbestätigte Beobachtungen: %d", "Unconfirmed encounters: %d") % encountered, 15, MUTED)
        _label(locked, _word("Unbekannte Anomalien: %d", "Unknown anomalies: %d") % unseen, 15, MUTED)
        _label(locked, _word("Namen und Beschreibungen werden erst nach einer richtigen Erkennung sichtbar.",
            "Names and descriptions unlock only after correctly identifying an anomaly."), 14, MUTED)


func _render_achievements(profiles: Node) -> void:
    var stats: Dictionary = profiles.get_stats()
    var unlocked: Dictionary = stats.get("achievements", {})
    var definitions := Progress.achievement_definitions()
    var metrics := Progress.metrics(stats, profiles.get_records())
    _label(body, _word("Erfolge: %d / %d", "Achievements: %d / %d") % [unlocked.size(), definitions.size()], 18, GOLD)
    _progress_bar(body, float(unlocked.size()), float(definitions.size()))
    var grid := GridContainer.new()
    grid.columns = 2
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    body.add_child(grid)
    for entry in definitions:
        var earned := bool(unlocked.get(entry["id"], false))
        var card := _card(grid)
        var hidden := bool(entry["secret"]) and not earned
        _label(card, _word("FREIGESCHALTET", "UNLOCKED") if earned else _word("GESPERRT", "LOCKED"), 12, GOLD if earned else MUTED)
        _label(card, "???" if hidden else str(entry["de" if _de() else "en"]), 17, GOLD if earned else Color.WHITE)
        _label(card, _word("Geheimer Erfolg", "Secret achievement") if hidden else str(entry["description_de" if _de() else "description_en"]), 13, MUTED)
        if not hidden:
            var goal := int(entry["goal"])
            var value := goal if earned else mini(goal, int(metrics.get(entry["metric"], 0)))
            _progress_bar(card, float(value), float(goal))
            _label(card, "%d / %d" % [value, goal], 12, MUTED)


func _render_modes(profiles: Node) -> void:
    var stats: Dictionary = profiles.get_stats()
    var records: Dictionary = profiles.get_records()
    for id in Modes.IDS:
        var card := _card(body)
        var unlocked := Modes.unlock(id, stats, records)
        _label(card, Modes.title(id, _de()).to_upper(), 18, GOLD)
        if not unlocked:
            _label(card, Modes.unlock_hint(id, _de()), 14, MUTED)
            continue
        _label(card, Modes.description(id, _de()), 14, MUTED)
        var record: Dictionary = stats.get("mode_records", {}).get(id, {})
        var summary: Dictionary = profiles.get_summary(profiles.active_slot, id)
        _label(card, _word("Fortsetzung verfügbar", "Continue available") if bool(summary.get("can_continue", false)) else _word("Kein aktiver Durchlauf", "No active run"), 13)
        if id in ["classic", "endless", "nightmare"]:
            _label(card, _word("Beste Serie: %d", "Best streak: %d") % int(record.get("best", 0)), 15, GOLD)
        if id == "time_trial":
            var seconds := float(record.get("best_time", 0.0))
            _label(card, _word("Bestzeit: ", "Best time: ") + (_format_time(seconds) if seconds > 0.0 else "—"), 15, GOLD)
        if id != "endless":
            _label(card, _word("Abschlüsse: %d", "Completions: %d") % int(record.get("completed", 0)), 14)
        else:
            _label(card, _word("Beendete Läufe: %d", "Finished runs: %d") % int(record.get("runs", 0)), 14)


func _format_time(seconds: float) -> String:
    return "%02d:%05.2f" % [floori(seconds / 60.0), fmod(seconds, 60.0)]


func _render_stats(profiles: Node) -> void:
    var stats: Dictionary = profiles.get_stats()
    var summary: Dictionary = profiles.active_summary()
    var level := Progress.level_info(int(stats.get("xp", 0)))
    var card := _card(body)
    _label(card, Progress.rank(int(level["level"]), _de()).to_upper(), 16, GOLD)
    _label(card, "LEVEL %d · %d XP" % [level["level"], level["xp"]], 28, GOLD)
    if int(level["next"]) > 0:
        _progress_bar(card, float(level["current"]), float(level["next"]))
        _label(card, "%d / %d XP" % [level["current"], level["next"]], 14, MUTED)
    else:
        _label(card, _word("Maximales Level erreicht", "Maximum level reached"), 14, MUTED)
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
    _label(body, Modes.title(str(verdict.get("mode", "classic")), _de()) + " · +" + str(verdict.get("xp_earned", 0)) + " XP", 16, GOLD)
    if str(verdict.get("mode", "classic")) == "time_trial":
        _label(body, _word("Zeit inkl. Strafen: ", "Time including penalties: ") + _format_time(float(verdict.get("score_seconds", 0.0))), 16, GOLD)
    if not correct and str(verdict.get("mode", "classic")) in ["classic", "endless", "nightmare"]:
        _label(body, _word("Serie: %d → 0" % int(verdict.get("previous_streak", 0)),
            "Streak: %d → 0" % int(verdict.get("previous_streak", 0))), 16, MUTED)
    _label(body, _word("Einzelheiten findest du ausschließlich bei korrekt identifizierten Anomalien im Archiv.",
        "Detailed descriptions are available only for correctly identified anomalies in the archive."),
        14, MUTED)
