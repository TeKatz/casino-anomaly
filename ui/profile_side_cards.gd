extends Control
## Two independent world-of-menu companion panels. They flank the CENTERED
## ProfilePanel and never alter its position. Only known anomaly counts/names
## of correctly unlocked entries are displayed; unknowns stay unnamed.
signal open_requested(mode: String)
const MenuStyle = preload("res://ui/menu_style.gd")
const LuminousButton = preload("res://ui/luminous_button.gd")
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const GOLD := Color("#dcb477")
const MUTED := Color("#a5b0bb")

var main_panel: Control
var statistics_card: PanelContainer
var archive_card: PanelContainer
var stats_body: VBoxContainer
var archive_body: VBoxContainer
var stats_button: Button
var archive_button: Button
var motion: Tween
var shown := false
var displayed_slot := 0
var target_left := Vector2.ZERO
var target_right := Vector2.ZERO


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    statistics_card = _build_card("stats", "stats")
    archive_card = _build_card("archive", "archive")
    statistics_card.visible = false
    archive_card.visible = false
    resized.connect(_layout_cards)
    var settings := get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_settings_changed)


func bind_panel(panel: Control) -> void:
    main_panel = panel
    main_panel.resized.connect(_layout_cards)
    call_deferred("_layout_cards")


func _build_card(mode: String, symbol: String) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.name = "StatisticsCard" if mode == "stats" else "ArchiveCard"
    panel.custom_minimum_size = Vector2(160, 342)
    panel.add_theme_stylebox_override("panel", MenuStyle.panel())
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(panel)
    var pad := MarginContainer.new()
    pad.add_theme_constant_override("margin_left", 16)
    pad.add_theme_constant_override("margin_right", 16)
    pad.add_theme_constant_override("margin_top", 19)
    pad.add_theme_constant_override("margin_bottom", 18)
    panel.add_child(pad)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 10)
    pad.add_child(stack)
    var kicker := _label(stack, "", 11, MUTED)
    kicker.name = "Kicker"
    var heading := _label(stack, "", 21, GOLD)
    heading.name = "Heading"
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var rule := HSeparator.new()
    stack.add_child(rule)
    var content := VBoxContainer.new()
    content.name = "PreviewContent"
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 9)
    stack.add_child(content)
    var button := LuminousButton.new()
    button.symbol = symbol
    button.custom_minimum_size.y = 44
    button.add_theme_font_size_override("font_size", 13)
    button.pressed.connect(func() -> void: open_requested.emit(mode))
    stack.add_child(button)
    if mode == "stats":
        stats_body = content
        stats_button = button
    else:
        archive_body = content
        archive_button = button
    return panel


func _label(parent: Node, value: String, font_size: int,
        tint: Color = Color.WHITE) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", tint)
    parent.add_child(label)
    return label


func _de() -> bool:
    var settings := get_node_or_null("/root/GameSettings")
    return settings != null and str(settings.get_option("language")) == "de"


func _word(de: String, en: String) -> String:
    return de if _de() else en


func _on_settings_changed(key: String) -> void:
    if key == "language" and displayed_slot > 0:
        _fill(displayed_slot)


func _layout_cards() -> void:
    if main_panel == null or not is_instance_valid(main_panel) or size.x <= 0.0:
        return
    var center_bounds: Rect2 = main_panel.get_global_rect()
    var origin := get_global_rect().position
    var gap := 14.0
    var free_side := (size.x - center_bounds.size.x - 76.0) * 0.5
    var width := clampf(free_side, 150.0, 268.0)
    # On small screens preserve the central profile controls. The cards
    # become shorter and narrower rather than forcing the whole menu to
    # recenter or run outside the viewport.
    var panel_height := minf(365.0, maxf(255.0, size.y - 64.0))
    statistics_card.size = Vector2(width, panel_height)
    archive_card.size = Vector2(width, panel_height)
    target_left = Vector2(center_bounds.position.x - origin.x - gap - width,
        center_bounds.get_center().y - origin.y - panel_height * 0.5)
    target_right = Vector2(center_bounds.end.x - origin.x + gap,
        center_bounds.get_center().y - origin.y - panel_height * 0.5)
    # Do not reset tweened positions while sliding.
    if motion == null or not motion.is_running():
        statistics_card.position = target_left
        archive_card.position = target_right


func _clear_body(body: VBoxContainer) -> void:
    for child in body.get_children():
        body.remove_child(child)
        child.queue_free()


func _fill(slot: int) -> void:
    var profiles := get_node_or_null("/root/ProfileManager")
    if profiles == null or not profiles.profile_exists(slot):
        return
    var summary: Dictionary = profiles.get_summary(slot)
    var stats: Dictionary = profiles.get_stats()
    (statistics_card.get_node("MarginContainer/VBoxContainer/Kicker") as Label).text = \
        _word("PROFIL %d / AUSWERTUNG", "PROFILE %d / REVIEW") % slot
    (statistics_card.get_node("MarginContainer/VBoxContainer/Heading") as Label).text = \
        _word("STATISTIKEN", "STATISTICS")
    (archive_card.get_node("MarginContainer/VBoxContainer/Kicker") as Label).text = \
        _word("SAMMLUNG / FORTSCHRITT", "COLLECTION / PROGRESS")
    (archive_card.get_node("MarginContainer/VBoxContainer/Heading") as Label).text = \
        _word("ANOMALIE-ARCHIV", "ANOMALY ARCHIVE")
    stats_button.text = _word("STATISTIK ÖFFNEN", "VIEW STATISTICS")
    archive_button.text = _word("ARCHIV ÖFFNEN", "VIEW ARCHIVE")
    _clear_body(stats_body)
    _clear_body(archive_body)
    _label(stats_body, _word("RICHTIGE ENTSCHEIDUNGEN", "CORRECT DECISIONS"), 11, MUTED)
    _label(stats_body, str(stats.get("correct", 0)), 34, GOLD)
    _label(stats_body, _word("Untersuchte Räume: %d", "Rooms inspected: %d") \
        % int(stats.get("rooms", 0)), 14)
    _label(stats_body, _word("Beste Serie: %d / 12", "Best streak: %d / 12") \
        % int(stats.get("best_streak", 0)), 14)
    _label(stats_body, _word("Abschlüsse: %d", "Completions: %d") \
        % int(summary.get("completions", 0)), 14)
    _label(stats_body, _word("Fehlentscheidungen: %d", "Wrong decisions: %d") \
        % int(stats.get("mistakes", 0)), 13, MUTED)

    _label(archive_body, _word("ENTDECKTE ANOMALIEN", "DISCOVERED ANOMALIES"), 11, MUTED)
    _label(archive_body, "%d / %d" % [int(summary.get("discovered", 0)),
        int(summary.get("total", 0))], 34, GOLD)
    var progress := ProgressBar.new()
    progress.custom_minimum_size.y = 11
    progress.show_percentage = false
    progress.min_value = 0.0
    progress.max_value = 100.0
    progress.value = float(summary.get("percent", 0.0))
    var back := StyleBoxFlat.new()
    back.bg_color = Color("#101f2c")
    back.set_corner_radius_all(5)
    progress.add_theme_stylebox_override("background", back)
    var fill := StyleBoxFlat.new()
    fill.bg_color = GOLD
    fill.set_corner_radius_all(5)
    progress.add_theme_stylebox_override("fill", fill)
    archive_body.add_child(progress)
    _label(archive_body, _word("%.0f %% der Sammlung", "%.0f %% of the collection") \
        % float(summary.get("percent", 0.0)), 14)

    # Only names already unlocked through CORRECT identification are shown.
    var records: Dictionary = profiles.get_records()
    var unlocked: Array[String] = []
    for entry in Catalog.entries():
        var record: Dictionary = records.get(str(entry.get("id", "")), {})
        if bool(record.get("recognized", false)):
            var key := "title_de" if _de() else "title_en"
            unlocked.append(str(entry.get(key, "")))
    unlocked.sort()
    if unlocked.is_empty():
        _label(archive_body, _word("Noch keine Anomalien entschlüsselt.",
            "No anomalies identified yet."), 13, MUTED)
    else:
        _label(archive_body, _word("Zuletzt freigeschaltet:", "Unlocked entries:"),
            12, MUTED)
        for name in unlocked.slice(0, 2):
            _label(archive_body, "· " + name, 13, MUTED)


func sync_selection(slot: int, occupied: bool, animated: bool = true) -> void:
    _layout_cards()
    if motion != null and motion.is_running():
        motion.kill()
    if not occupied or slot <= 0:
        displayed_slot = 0
        if not shown:
            statistics_card.visible = false
            archive_card.visible = false
            return
        shown = false
        if not animated:
            statistics_card.visible = false
            archive_card.visible = false
            return
        motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
        motion.tween_property(statistics_card, "modulate:a", 0.0, 0.19)
        motion.parallel().tween_property(archive_card, "modulate:a", 0.0, 0.19)
        motion.parallel().tween_property(statistics_card, "position:x", target_left.x + 28.0, 0.19)
        motion.parallel().tween_property(archive_card, "position:x", target_right.x - 28.0, 0.19)
        motion.tween_callback(func() -> void:
            statistics_card.visible = false
            archive_card.visible = false
        )
        return

    var switching := shown and displayed_slot != slot
    displayed_slot = slot
    statistics_card.visible = true
    archive_card.visible = true
    if not animated:
        _fill(slot)
        statistics_card.position = target_left
        archive_card.position = target_right
        statistics_card.modulate.a = 1.0
        archive_card.modulate.a = 1.0
        shown = true
        return
    if switching:
        # Keep the cards anchored. Fade old data out, swap both previews
        # atomically, then fade the new profile's numbers back in.
        motion = create_tween().set_trans(Tween.TRANS_CUBIC)
        motion.tween_property(statistics_card, "modulate:a", 0.0, 0.12)
        motion.parallel().tween_property(archive_card, "modulate:a", 0.0, 0.12)
        motion.tween_callback(_fill.bind(slot))
        motion.tween_property(statistics_card, "modulate:a", 1.0, 0.18)
        motion.parallel().tween_property(archive_card, "modulate:a", 1.0, 0.18)
    elif not shown:
        _fill(slot)
        shown = true
        statistics_card.position = target_left + Vector2(52, 0)
        archive_card.position = target_right - Vector2(52, 0)
        statistics_card.modulate.a = 0.0
        archive_card.modulate.a = 0.0
        motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        motion.tween_property(statistics_card, "position", target_left, 0.34)
        motion.parallel().tween_property(archive_card, "position", target_right, 0.34)
        motion.parallel().tween_property(statistics_card, "modulate:a", 1.0, 0.30)
        motion.parallel().tween_property(archive_card, "modulate:a", 1.0, 0.30)
    else:
        _fill(slot)
        statistics_card.position = target_left
        archive_card.position = target_right
        statistics_card.modulate.a = 1.0
        archive_card.modulate.a = 1.0
