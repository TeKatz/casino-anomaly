extends Control
## Two independent world-of-menu companion panels. They flank the CENTERED
## ProfilePanel and never alter its position. Only known anomaly counts/names
## of correctly unlocked entries are displayed; unknowns stay unnamed.
signal open_requested(mode: String)
const Controls = preload("res://gameplay/input_bindings.gd")
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
# Animate only an offset relative to the current layout, never an absolute
# destination captured before CenterContainer has finished sorting.
var slide_inset := 0.0
var cards_requested := false
var layout_valid := false


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    statistics_card = _build_card("stats", "stats")
    archive_card = _build_card("archive", "archive")
    statistics_card.visible = false
    archive_card.visible = false
    resized.connect(_layout_cards)
    visibility_changed.connect(_on_visibility_changed)
    set_process(false)
    var settings := get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_settings_changed)


func bind_panel(panel: Control) -> void:
    main_panel = panel
    main_panel.item_rect_changed.connect(_layout_cards)
    call_deferred("_layout_cards")


func _build_card(mode: String, symbol: String) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.name = "StatisticsCard" if mode == "stats" else "ArchiveCard"
    # The preview card has a bounded viewport-controlled height. Its text
    # may grow, but must never raise the PanelContainer minimum height.
    panel.custom_minimum_size = Vector2(160, 0)
    panel.add_theme_stylebox_override("panel", MenuStyle.panel())
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(panel)
    var pad := MarginContainer.new()
    pad.name = "MarginContainer"
    pad.add_theme_constant_override("margin_left", 16)
    pad.add_theme_constant_override("margin_right", 16)
    pad.add_theme_constant_override("margin_top", 19)
    pad.add_theme_constant_override("margin_bottom", 18)
    panel.add_child(pad)
    var stack := VBoxContainer.new()
    stack.name = "VBoxContainer"
    stack.add_theme_constant_override("separation", 10)
    pad.add_child(stack)
    var kicker := _label(stack, "", 11, MUTED)
    kicker.name = "Kicker"
    var heading := _label(stack, "", 21, GOLD)
    heading.name = "Heading"
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var rule := HSeparator.new()
    stack.add_child(rule)
    # Unbounded dynamic labels used to enlarge the entire side panel after
    # a repeated profile selection. A scrolling *content viewport* keeps the
    # card geometry stable and the bottom action reachable at every size.
    var preview_scroll := ScrollContainer.new()
    preview_scroll.name = "PreviewScroll"
    preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    preview_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    stack.add_child(preview_scroll)
    var content := VBoxContainer.new()
    content.name = "PreviewContent"
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 9)
    preview_scroll.add_child(content)
    var button := LuminousButton.new()
    button.symbol = symbol
    button.clip_text = true
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


func _on_visibility_changed() -> void:
    set_process(is_visible_in_tree())
    if not is_visible_in_tree():
        _stop_motion()
        shown = false
        displayed_slot = 0
        cards_requested = false
        slide_inset = 0.0
        statistics_card.hide()
        archive_card.hide()
    else:
        _layout_cards()


func _process(_delta: float) -> void:
    # CenterContainer may sort after the resize notification, particularly
    # on a fresh menu instance. Reconcile while the overlay is on screen.
    _layout_cards()


func _stop_motion() -> void:
    if motion != null and motion.is_running():
        motion.kill()
    motion = null


func _set_slide(value: float) -> void:
    slide_inset = value
    _layout_cards()


func _layout_cards() -> void:
    if not is_instance_valid(main_panel) or not is_instance_valid(statistics_card):
        return
    var center_bounds: Rect2 = main_panel.get_global_rect()
    var origin := get_global_rect().position
    var center_local := Rect2(center_bounds.position - origin, center_bounds.size)
    # Do not display an unfinished container layout. The next frame will
    # re-evaluate even if the container moves without changing its size.
    layout_valid = size.x > 0.0 and size.y > 0.0 and center_local.size.x > 0.0 \
        and center_local.size.y > 0.0 and center_local.get_center().distance_to(size * 0.5) <= 3.0
    if not layout_valid or not cards_requested:
        statistics_card.hide()
        archive_card.hide()
        return
    var gap := 14.0
    var available := minf(center_local.position.x, size.x - center_local.end.x) - gap - 12.0
    var width := clampf(available, 160.0, 268.0)
    var panel_height := minf(365.0, maxf(255.0, size.y - 64.0))
    # On unusually narrow windows scale the previews rather than overlap
    # the center panel. The ordinary 1280x720 layout is unchanged.
    var fit := minf(1.0, maxf(0.0, available) / width)
    if fit < 0.45:
        statistics_card.hide()
        archive_card.hide()
        return
    for card in [statistics_card, archive_card]:
        card.size = Vector2(width, panel_height)
        card.scale = Vector2.ONE * fit
    var actual_width := maxf(statistics_card.size.x, archive_card.size.x) * fit
    var actual_height := maxf(statistics_card.size.y, archive_card.size.y) * fit
    target_left = Vector2(center_local.position.x - gap - actual_width,
        center_local.get_center().y - actual_height * 0.5)
    target_right = Vector2(center_local.end.x + gap,
        center_local.get_center().y - actual_height * 0.5)
    # The fade/slide is relative to the live position. Never let a slide
    # cover the central profile controls (including on a narrow viewport).
    var inset := minf(slide_inset, gap - 2.0)
    statistics_card.position = target_left + Vector2(inset, 0)
    archive_card.position = target_right - Vector2(inset, 0)
    statistics_card.show()
    archive_card.show()


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
    _label(stats_body, _word("PERMANENTES LEVEL", "PERMANENT LEVEL"), 11, MUTED)
    _label(stats_body, str(summary.get("player_level", 1)), 34, GOLD)
    _label(stats_body, _word("Erfahrung: %d XP", "Experience: %d XP") \
        % int(summary.get("xp", 0)), 14)
    _label(stats_body, _word("Beste Serie: %d / 12", "Best streak: %d / 12") \
        % int(stats.get("best_streak", 0)), 14)
    _label(stats_body, _word("Abschlüsse: %d", "Completions: %d") \
        % int(summary.get("completions", 0)), 14)
    _label(stats_body, _word("Erfolge: %d", "Achievements: %d") \
        % int(summary.get("achievements", 0)), 13, MUTED)

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
    _stop_motion()
    animated = animated and not bool(Controls.pref(self, "reduced_menu_motion", false))
    if not occupied or slot <= 0:
        displayed_slot = 0
        shown = false
        if not cards_requested or not animated:
            cards_requested = false
            slide_inset = 0.0
            _layout_cards()
            return
        motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
        motion.tween_property(statistics_card, "modulate:a", 0.0, 0.19)
        motion.parallel().tween_property(archive_card, "modulate:a", 0.0, 0.19)
        motion.parallel().tween_method(_set_slide, slide_inset, 12.0, 0.19)
        motion.tween_callback(func() -> void:
            cards_requested = false
            slide_inset = 0.0
            _layout_cards()
        )
        return

    var switching := shown and displayed_slot != slot
    var entering := not shown
    displayed_slot = slot
    shown = true
    cards_requested = true
    if not animated or (not switching and not entering):
        _fill(slot)
        slide_inset = 0.0
        statistics_card.modulate.a = 1.0
        archive_card.modulate.a = 1.0
        _layout_cards()
        return
    if switching:
        slide_inset = 0.0
        _layout_cards()
        motion = create_tween().set_trans(Tween.TRANS_CUBIC)
        motion.tween_property(statistics_card, "modulate:a", 0.0, 0.12)
        motion.parallel().tween_property(archive_card, "modulate:a", 0.0, 0.12)
        motion.tween_callback(_fill.bind(slot))
        motion.tween_property(statistics_card, "modulate:a", 1.0, 0.18)
        motion.parallel().tween_property(archive_card, "modulate:a", 1.0, 0.18)
    else:
        _fill(slot)
        slide_inset = 12.0
        statistics_card.modulate.a = 0.0
        archive_card.modulate.a = 0.0
        _layout_cards()
        motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        motion.tween_method(_set_slide, 12.0, 0.0, 0.34)
        motion.parallel().tween_property(statistics_card, "modulate:a", 1.0, 0.30)
        motion.parallel().tween_property(archive_card, "modulate:a", 1.0, 0.30)
    motion.tween_callback(_layout_cards)
