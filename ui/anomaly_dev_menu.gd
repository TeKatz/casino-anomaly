extends CanvasLayer
## Secret G-key developer picker, not part of the normal gameplay HUD or
## settings. Its rows are generated from the central anomaly catalog.
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const GOLD := Color("#dcb477")
const WORDS := {
    "de": {
        "title": "ENTWICKLERWERKZEUGE", "subtitle": "ANOMALIEN · NÄCHSTER RAUM",
        "help": "Auswahl gilt einmalig für den nächsten Raum.",
        "staged": "Nächster Raum bereits vorbereitet: Auswahl greift sofort.",
        "queued": "Vorgemerkt: %s", "current": "Vorbereiteter Raum: %s",
        "random": "Zufall", "normal": "Normal (keine Anomalie)",
        "search": "Anomalien suchen (Name, ID, Kategorie) …",
        "count": "%d von %d Anomalien", "missing": " · Nicht verfügbar",
        "none": "Keine passenden Anomalien gefunden.",
        "force_normal": "NORMALEN RAUM ERZWINGEN",
        "restore_random": "ZUFALL WIEDERHERSTELLEN",
        "close": "SCHLIESSEN · G / ESC",
        "error": "Diese Anomalie ist im nächsten Raum nicht verfügbar."
    },
    "en": {
        "title": "DEVELOPER TOOLS", "subtitle": "ANOMALIES · NEXT ROOM",
        "help": "Your choice is forced once in the next room.",
        "staged": "Next room already prepared: changes apply immediately.",
        "queued": "Queued: %s", "current": "Prepared room: %s",
        "random": "Random", "normal": "Normal (no anomaly)",
        "search": "Search anomalies (name, ID, category) …",
        "count": "%d of %d anomalies", "missing": " · Unavailable",
        "none": "No matching anomalies found.",
        "force_normal": "FORCE NORMAL ROOM",
        "restore_random": "RESTORE RANDOM",
        "close": "CLOSE · G / ESC",
        "error": "That anomaly is not available in the next room."
    }
}

var open := false
var title_label: Label
var subtitle_label: Label
var help_label: Label
var status_label: Label
var count_label: Label
var search: LineEdit
var listing: VBoxContainer
var normal_button: Button
var random_button: Button
var close_button: Button
var collision_toggle: CheckButton


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 85
    _build_ui()
    visible = false


func _lang() -> String:
    var settings = get_node_or_null("/root/GameSettings")
    return "de" if settings != null and str(settings.get_option("language")) == "de" else "en"


func _word(key: String) -> String:
    var words: Dictionary = WORDS[_lang()]
    return str(words.get(key, key))


func _field(entry: Dictionary, key: String) -> String:
    return str(entry.get(key + "_" + _lang(), entry.get("id", "")))


func _loop() -> Node:
    var owner_player := get_parent()
    if owner_player == null or owner_player.get_parent() == null:
        return null
    return owner_player.get_parent().get_node_or_null("LoopController")


func _build_ui() -> void:
    var overlay := Control.new()
    overlay.name = "DevToolsOverlay"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)

    var dim := ColorRect.new()
    dim.color = Color(0.01, 0.014, 0.022, 0.86)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.name = "AnomalyPanel"
    panel.custom_minimum_size = Vector2(700, 540)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#151c26")
    style.border_color = GOLD
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.shadow_size = 24
    style.shadow_color = Color(0, 0, 0, 0.7)
    panel.add_theme_stylebox_override("panel", style)
    center.add_child(panel)

    var margins := MarginContainer.new()
    margins.add_theme_constant_override("margin_left", 26)
    margins.add_theme_constant_override("margin_right", 26)
    margins.add_theme_constant_override("margin_top", 20)
    margins.add_theme_constant_override("margin_bottom", 20)
    panel.add_child(margins)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 9)
    margins.add_child(stack)

    title_label = _label(stack, 26, GOLD)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle_label = _label(stack, 17, Color("#d4dce6"))
    subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    help_label = _label(stack, 14, Color("#9babb9"))
    status_label = _label(stack, 14, Color("#f1d39d"))

    search = LineEdit.new()
    search.name = "AnomalySearch"
    search.custom_minimum_size.y = 39
    search.clear_button_enabled = true
    search.text_changed.connect(_on_search_changed)
    stack.add_child(search)
    count_label = _label(stack, 13, Color("#95a3b5"))

    var scroller := ScrollContainer.new()
    scroller.name = "CatalogScroll"
    scroller.custom_minimum_size.y = 275
    scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    stack.add_child(scroller)
    listing = VBoxContainer.new()
    listing.name = "CatalogEntries"
    listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    listing.add_theme_constant_override("separation", 5)
    scroller.add_child(listing)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 12)
    stack.add_child(actions)
    normal_button = _action(actions, _force_normal)
    random_button = _action(actions, _restore_random)
    collision_toggle = CheckButton.new()
    collision_toggle.name = "CollisionDiagnostics"
    collision_toggle.toggled.connect(_toggle_collision_diagnostics)
    stack.add_child(collision_toggle)
    close_button = Button.new()
    close_button.custom_minimum_size.y = 37
    close_button.pressed.connect(_close_menu)
    stack.add_child(close_button)


func _label(parent: VBoxContainer, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label


func _action(parent: HBoxContainer, callback: Callable) -> Button:
    var button := Button.new()
    button.custom_minimum_size.y = 44
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.pressed.connect(callback)
    parent.add_child(button)
    return button


func _input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if event.keycode == KEY_G or event.physical_keycode == KEY_G:
        # Typing "G" into the search field must not close the window.
        if open and search.has_focus():
            return
        if open:
            _close_menu()
        else:
            _open_menu()
        if open or not get_tree().paused:
            get_viewport().set_input_as_handled()
    elif event.keycode == KEY_ESCAPE and open:
        _close_menu()
        get_viewport().set_input_as_handled()


func _open_menu() -> void:
    if open or get_tree().paused:
        return
    var loop := _loop()
    if loop == null or bool(loop.get("won")) or bool(loop.get("finishing")):
        return
    open = true
    search.text = ""
    _refresh()
    visible = true
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_menu() -> void:
    if not open:
        return
    open = false
    visible = false
    search.release_focus()
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
    if open and get_tree() != null:
        get_tree().paused = false


func _toggle_collision_diagnostics(enabled: bool) -> void:
    var player := get_parent()
    if player != null and player.has_method("set_collision_diagnostics"):
        player.call("set_collision_diagnostics", enabled)


func _refresh() -> void:
    title_label.text = _word("title")
    subtitle_label.text = _word("subtitle")
    help_label.text = _word("staged") if bool(_loop().get("choice_taken")) else _word("help")
    search.placeholder_text = _word("search")
    normal_button.text = _word("force_normal")
    random_button.text = _word("restore_random")
    close_button.text = _word("close")
    collision_toggle.text = "Kollisionsdiagnose (Godot-Konsole)" if _lang() == "de" else "Collision diagnostics (Godot console)"
    collision_toggle.set_pressed_no_signal(bool(get_parent().get("collision_diagnostics")))
    _refresh_status()
    _rebuild_catalog()


func _display_id(id: String) -> String:
    if id.is_empty():
        return _word("normal")
    var entry := Catalog.get_entry(id)
    return _field(entry, "title") if not entry.is_empty() else id


func _refresh_status() -> void:
    var loop := _loop()
    var state = get_node_or_null("/root/LoopState")
    if loop == null or state == null:
        return
    if bool(loop.get("choice_taken")):
        status_label.text = _word("current") % _display_id(str(state.anomaly_id))
    elif bool(state.debug_next_round_requested):
        status_label.text = _word("queued") % _display_id(str(state.debug_next_anomaly_id))
    else:
        status_label.text = _word("queued") % _word("random")


func _on_search_changed(_value: String) -> void:
    if open:
        _rebuild_catalog()


func _rebuild_catalog() -> void:
    for child in listing.get_children():
        listing.remove_child(child)
        child.queue_free()
    var loop := _loop()
    if loop == null:
        return
    var available: Array[String] = loop.call("debug_available_ids")
    var entries: Array[Dictionary] = Catalog.entries()
    entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var cat_a := _field(a, "category")
        var cat_b := _field(b, "category")
        if cat_a == cat_b:
            return _field(a, "title").nocasecmp_to(_field(b, "title")) < 0
        return cat_a.nocasecmp_to(cat_b) < 0
    )
    var query := search.text.strip_edges().to_lower()
    var previous_category := ""
    var count := 0
    for entry in entries:
        var id := str(entry["id"])
        var title := _field(entry, "title")
        var category := _field(entry, "category")
        var description := _field(entry, "description")
        var searchable := (id + " " + title + " " + category + " " + description).to_lower()
        if not query.is_empty() and not searchable.contains(query):
            continue
        if previous_category != category:
            var category_label := _label(listing, 15, GOLD)
            category_label.text = category
            previous_category = category
        var button := Button.new()
        button.name = "Anomaly_" + id
        button.custom_minimum_size.y = 52
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.clip_text = true
        button.text = "%s  [%s]\n%s" % [title, id, description]
        button.tooltip_text = description
        if not available.has(id):
            button.disabled = true
            button.text += _word("missing")
        else:
            button.pressed.connect(_choose_anomaly.bind(id))
        listing.add_child(button)
        count += 1
    if count == 0:
        var none := _label(listing, 15, Color("#9babb9"))
        none.text = _word("none")
    count_label.text = _word("count") % [count, entries.size()]


func _choose_anomaly(id: String) -> void:
    var loop := _loop()
    if loop != null and bool(loop.call("debug_select_next_anomaly", id)):
        _close_menu()
    else:
        status_label.text = _word("error")


func _force_normal() -> void:
    _choose_anomaly("")


func _restore_random() -> void:
    var loop := _loop()
    if loop != null and bool(loop.call("debug_restore_random")):
        _close_menu()
    else:
        status_label.text = _word("error")
