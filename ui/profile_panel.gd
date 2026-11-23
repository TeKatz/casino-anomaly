extends PanelContainer
## Five profile slots in the middle. Side previews are independent controls,
## so selecting a slot never moves or stretches this central panel.
signal back_pressed
signal launch_requested(scene_path: String)
signal selection_changed(slot: int, occupied: bool)

const MenuStyle = preload("res://ui/menu_style.gd")
const LuminousButton = preload("res://ui/luminous_button.gd")
const GOLD := Color("#dcb477")
const MUTED := Color("#a5b0bb")
const SLOT_COUNT := 5

var selected_slot := 0
var delete_target := 0
var slot_buttons: Array[Button] = []
var slot_delete_buttons: Array[Button] = []
var status: Label
var name_edit: LineEdit
var continue_button: Button
var new_button: Button
var rename_button: Button
var back_button: Button
var title_label: Label
var delete_dialog: ConfirmationDialog
var new_run_dialog: ConfirmationDialog


func _ready() -> void:
    custom_minimum_size = Vector2(615, 540)
    add_theme_stylebox_override("panel", MenuStyle.panel())
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 22)
    margin.add_theme_constant_override("margin_top", 19)
    margin.add_theme_constant_override("margin_bottom", 19)
    add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 10)
    margin.add_child(stack)

    title_label = Label.new()
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 25)
    title_label.add_theme_color_override("font_color", GOLD)
    stack.add_child(title_label)

    var rule := HSeparator.new()
    stack.add_child(rule)
    for slot in range(1, SLOT_COUNT + 1):
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        stack.add_child(row)

        var select_button := LuminousButton.new()
        select_button.name = "ProfileSlot%d" % slot
        select_button.symbol = "profile"
        select_button.custom_minimum_size.y = 47
        select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        select_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        select_button.add_theme_font_size_override("font_size", 14)
        select_button.pressed.connect(_select_slot.bind(slot))
        row.add_child(select_button)
        slot_buttons.append(select_button)

        var delete_icon := LuminousButton.new()
        delete_icon.name = "DeleteSlot%d" % slot
        delete_icon.symbol = "delete"
        delete_icon.accent = "red"
        delete_icon.custom_minimum_size = Vector2(44, 47)
        delete_icon.alignment = HORIZONTAL_ALIGNMENT_CENTER
        delete_icon.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        delete_icon.pressed.connect(_request_delete_slot.bind(slot))
        row.add_child(delete_icon)
        slot_delete_buttons.append(delete_icon)

    var heading := HSeparator.new()
    stack.add_child(heading)
    var name_line := HBoxContainer.new()
    name_line.add_theme_constant_override("separation", 8)
    stack.add_child(name_line)
    name_edit = LineEdit.new()
    name_edit.max_length = 32
    name_edit.custom_minimum_size.y = 43
    name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_line.add_child(name_edit)
    rename_button = _button(name_line, _rename, "edit")

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 9)
    stack.add_child(actions)
    continue_button = _button(actions, _continue, "resume", "green")
    new_button = _button(actions, _request_new_run, "new", "amber")

    back_button = LuminousButton.new()
    back_button.symbol = "back"
    back_button.custom_minimum_size.y = 40
    back_button.pressed.connect(func() -> void: back_pressed.emit())
    stack.add_child(back_button)

    status = Label.new()
    status.add_theme_font_size_override("font_size", 12)
    status.add_theme_color_override("font_color", MUTED)
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.custom_minimum_size.y = 27
    stack.add_child(status)

    delete_dialog = ConfirmationDialog.new()
    delete_dialog.confirmed.connect(_delete_target)
    add_child(delete_dialog)
    new_run_dialog = ConfirmationDialog.new()
    new_run_dialog.confirmed.connect(_new_run)
    add_child(new_run_dialog)

    var profiles := get_node_or_null("/root/ProfileManager")
    if profiles != null and profiles.profile_exists(profiles.active_slot):
        selected_slot = profiles.active_slot
        name_edit.text = str(profiles.get_summary(selected_slot).get("name", ""))
    refresh()


func _button(parent: HBoxContainer, action: Callable, symbol: String,
        accent: String = "gold") -> Button:
    var button := LuminousButton.new()
    button.symbol = symbol
    button.accent = accent
    button.featured = accent != "gold"
    button.custom_minimum_size.y = 43
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(button)
    button.pressed.connect(action)
    return button


func _de() -> bool:
    var settings := get_node_or_null("/root/GameSettings")
    return settings != null and str(settings.get_option("language")) == "de"


func _word(de: String, en: String) -> String:
    return de if _de() else en


func is_selected_occupied() -> bool:
    var profiles := get_node_or_null("/root/ProfileManager")
    return profiles != null and selected_slot > 0 and profiles.profile_exists(selected_slot)


func refresh() -> void:
    if not is_node_ready():
        return
    var profiles := get_node_or_null("/root/ProfileManager")
    if profiles == null:
        return
    title_label.text = _word("SPIELERPROFILE", "PLAYER PROFILES")
    for i in range(SLOT_COUNT):
        var slot := i + 1
        var summary: Dictionary = profiles.get_summary(slot)
        var occupied := bool(summary.get("exists", false))
        var button := slot_buttons[i] as LuminousButton
        var delete_icon := slot_delete_buttons[i] as LuminousButton
        if occupied:
            button.text = "%s · %d / %d (%.0f %%)" % [
                str(summary.get("name", "Profil %d" % slot)),
                int(summary.get("discovered", 0)),
                int(summary.get("total", 0)),
                float(summary.get("percent", 0.0))]
        else:
            button.text = _word("SLOT %d · + Neues Profil erstellen",
                "SLOT %d · + Create new profile") % slot
        button.set_symbol("profile" if occupied else "add_profile")
        button.clip_text = true
        button.tooltip_text = button.text
        button.modulate = Color("#f5dfb5") if slot == selected_slot else Color.WHITE
        delete_icon.visible = occupied
        delete_icon.disabled = not occupied
        delete_icon.tooltip_text = _word("Profil %d löschen", "Delete profile %d") % slot
        delete_icon.text = ""

    name_edit.placeholder_text = _word("Profilname (max. 32 Zeichen)",
        "Profile name (max 32 characters)")
    rename_button.text = _word("UMBENENNEN", "RENAME")
    continue_button.text = _word("FORTSETZEN", "CONTINUE")
    new_button.text = _word("NEUER DURCHLAUF", "NEW RUN") \
        if is_selected_occupied() else _word("PROFIL ERSTELLEN", "CREATE PROFILE")
    back_button.text = _word("ZURÜCK", "BACK")

    var active := is_selected_occupied()
    var summary: Dictionary = profiles.get_summary(selected_slot)
    continue_button.disabled = not active or not bool(summary.get("can_continue", false))
    new_button.disabled = selected_slot == 0
    rename_button.disabled = not active
    name_edit.editable = selected_slot > 0
    if active:
        status.text = _word("Abgeschlossene Durchläufe: %d · Entdeckungen bleiben erhalten.",
            "Completed runs: %d · Discoveries are preserved.") \
            % int(summary.get("completions", 0))
    elif selected_slot > 0:
        status.text = _word("Leerer Platz · Profil erstellen, um einen Durchlauf zu beginnen.",
            "Empty slot · Create a profile to begin a run.")
    else:
        status.text = _word("Wähle ein Profil oder einen freien Speicherplatz.",
            "Select a profile or an empty save slot.")


func _select_slot(slot: int) -> void:
    var profiles := get_node_or_null("/root/ProfileManager")
    if profiles == null:
        return
    var occupied := profiles.profile_exists(slot)
    if occupied and not profiles.select_profile(slot):
        status.text = _word("Profil konnte nicht geöffnet werden.", "Could not open profile.")
        return
    # Selecting an EMPTY slot is NOT creation. This is essential for the
    # side panels to fade away without producing a phantom saved profile.
    selected_slot = slot
    name_edit.text = str(profiles.get_summary(slot).get("name", "")) if occupied else ""
    refresh()
    selection_changed.emit(slot, occupied)


func _rename() -> void:
    var profiles := get_node_or_null("/root/ProfileManager")
    if profiles != null and profiles.rename_profile(selected_slot, name_edit.text):
        refresh()
        selection_changed.emit(selected_slot, true)


func _request_new_run() -> void:
    if selected_slot == 0:
        return
    if not is_selected_occupied():
        _new_run()
        return
    var state := get_node_or_null("/root/LoopState")
    if state != null and state.has_continue():
        new_run_dialog.title = _word("Neuer Durchlauf", "New run")
        new_run_dialog.dialog_text = _word(
            "Aktuellen Durchlauf überschreiben? Das Anomalie-Archiv bleibt erhalten.",
            "Overwrite the current run? Your anomaly archive will be preserved.")
        new_run_dialog.popup_centered()
    else:
        _new_run()


func _new_run() -> void:
    var profiles := get_node_or_null("/root/ProfileManager")
    var state := get_node_or_null("/root/LoopState")
    if profiles == null or state == null or selected_slot == 0:
        return
    if not profiles.profile_exists(selected_slot):
        if not profiles.create_profile(selected_slot, name_edit.text):
            status.text = _word("Profil konnte nicht erstellt werden.", "Could not create profile.")
            return
    elif profiles.active_slot != selected_slot and not profiles.select_profile(selected_slot):
        return
    state.start_new_run()
    launch_requested.emit("res://gameplay/tutorial.tscn")


func _continue() -> void:
    var state := get_node_or_null("/root/LoopState")
    var profiles := get_node_or_null("/root/ProfileManager")
    if state == null or profiles == null or selected_slot == 0 \
            or profiles.active_slot != selected_slot or not state.has_continue():
        return
    launch_requested.emit("res://main.tscn" if state.tutorial_done \
        else "res://gameplay/tutorial.tscn")


func _request_delete_slot(slot: int) -> void:
    var profiles := get_node_or_null("/root/ProfileManager")
    if profiles == null or not profiles.profile_exists(slot):
        return
    delete_target = slot
    delete_dialog.title = _word("Profil löschen", "Delete profile")
    delete_dialog.dialog_text = _word(
        "Speicherplatz %d und sämtliche Entdeckungen unwiderruflich löschen?",
        "Permanently delete slot %d and all discoveries?") % slot
    delete_dialog.popup_centered()


func _delete_target() -> void:
    var profiles := get_node_or_null("/root/ProfileManager")
    if profiles == null or delete_target <= 0:
        return
    var slot := delete_target
    delete_target = 0
    if not profiles.delete_profile(slot):
        status.text = _word("Profil konnte nicht gelöscht werden.", "Could not delete profile.")
        return
    if selected_slot == slot:
        selected_slot = 0
        name_edit.text = ""
        selection_changed.emit(0, false)
    refresh()
