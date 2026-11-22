extends PanelContainer
## Profile picker with five persistent slots and contextual actions.
signal back_pressed
signal launch_requested(scene_path: String)
signal archive_requested(mode: String)

const MenuStyle = preload("res://ui/menu_style.gd")
const GOLD := Color("#dcb477")
const MUTED := Color("#a5b0bb")
const SLOT_COUNT := 5
var selected_slot := 0
var slot_buttons: Array[Button] = []
var status: Label
var name_edit: LineEdit
var continue_button: Button
var new_button: Button
var rename_button: Button
var delete_button: Button
var archive_button: Button
var stats_button: Button
var back_button: Button
var title_label: Label
var delete_dialog: ConfirmationDialog


func _ready() -> void:
    custom_minimum_size = Vector2(710, 635)
    add_theme_stylebox_override("panel", MenuStyle.panel())
    var margin := MarginContainer.new()
    for side in ["left", "right"]:
        margin.add_theme_constant_override("margin_" + side, 24)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 7)
    margin.add_child(stack)
    title_label = Label.new()
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 26)
    title_label.add_theme_color_override("font_color", GOLD)
    stack.add_child(title_label)
    for slot in range(1, SLOT_COUNT + 1):
        var button := Button.new()
        button.custom_minimum_size.y = 52
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_font_size_override("font_size", 15)
        button.pressed.connect(_select_slot.bind(slot))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        slot_buttons.append(button)
        stack.add_child(button)
    var name_line := HBoxContainer.new()
    name_line.add_theme_constant_override("separation", 7)
    stack.add_child(name_line)
    name_edit = LineEdit.new()
    name_edit.max_length = 32
    name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_line.add_child(name_edit)
    rename_button = _button(name_line, _rename)
    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 7)
    stack.add_child(actions)
    continue_button = _button(actions, _continue)
    new_button = _button(actions, _new_run)
    var collection_actions := HBoxContainer.new()
    collection_actions.add_theme_constant_override("separation", 7)
    stack.add_child(collection_actions)
    archive_button = _button(collection_actions,
        func() -> void: archive_requested.emit("archive"))
    stats_button = _button(collection_actions,
        func() -> void: archive_requested.emit("stats"))
    var last_actions := HBoxContainer.new()
    last_actions.add_theme_constant_override("separation", 7)
    stack.add_child(last_actions)
    delete_button = _button(last_actions, _request_delete)
    back_button = _button(last_actions, func() -> void: back_pressed.emit())
    status = Label.new()
    status.add_theme_font_size_override("font_size", 13)
    status.add_theme_color_override("font_color", MUTED)
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(status)
    delete_dialog = ConfirmationDialog.new()
    delete_dialog.confirmed.connect(_delete_selected)
    add_child(delete_dialog)
    refresh()


func _button(parent: HBoxContainer, action: Callable) -> Button:
    var button := Button.new()
    button.custom_minimum_size.y = 38
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(button)
    button.pressed.connect(action)
    return button


func _de() -> bool:
    var settings = get_node_or_null("/root/GameSettings")
    return settings != null and str(settings.get_option("language")) == "de"


func _word(de: String, en: String) -> String:
    return de if _de() else en


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
        var button := slot_buttons[i]
        button.disabled = false
        if bool(summary.get("exists", false)):
            button.text = "%s  ·  %d / %d (%.0f %%)    |    %s: %d / 12    |    %s: %d" % [
                str(summary.get("name", "Profil %d" % slot)),
                int(summary.get("discovered", 0)), int(summary.get("total", 0)),
                float(summary.get("percent", 0.0)),
                _word("Serie", "Streak"), int(summary.get("level", 0)),
                _word("Abschlüsse", "Wins"), int(summary.get("completions", 0))]
        else:
            button.text = _word("SLOT %d · + Neues Profil erstellen",
                "SLOT %d · + Create new profile") % slot
        button.modulate = Color("#f5dfb5") if slot == selected_slot else Color.WHITE
    name_edit.placeholder_text = _word("Profilname (max. 32 Zeichen)",
        "Profile name (max 32 characters)")
    rename_button.text = _word("UMBENENNEN", "RENAME")
    continue_button.text = _word("FORTSETZEN", "CONTINUE")
    new_button.text = _word("NEUER DURCHLAUF", "NEW RUN")
    archive_button.text = _word("ANOMALIE-ARCHIV", "ANOMALY ARCHIVE")
    stats_button.text = _word("STATISTIKEN", "STATISTICS")
    delete_button.text = _word("PROFIL LÖSCHEN", "DELETE PROFILE")
    back_button.text = _word("ZURÜCK", "BACK")
    var active: bool = selected_slot > 0 and profiles.profile_exists(selected_slot)
    var summary: Dictionary = profiles.get_summary(selected_slot)
    continue_button.disabled = not active or not bool(summary.get("can_continue", false))
    for button in [new_button, archive_button, stats_button, delete_button, rename_button]:
        button.disabled = not active
    name_edit.editable = active
    status.text = _word("Wähle einen Slot. Neue Durchläufe behalten deine Entdeckungen.",
        "Choose a slot. New runs keep your discoveries.")


func _select_slot(slot: int) -> void:
    var profiles := get_node_or_null("/root/ProfileManager")
    if profiles == null:
        return
    if not profiles.profile_exists(slot) and not profiles.create_profile(slot):
        status.text = _word("Speicherplatz konnte nicht erstellt werden.",
            "Could not create save slot.")
        return
    if not profiles.select_profile(slot):
        status.text = _word("Profil konnte nicht geöffnet werden.", "Could not open profile.")
        return
    selected_slot = slot
    name_edit.text = str(profiles.get_summary(slot).get("name", ""))
    refresh()


func _rename() -> void:
    var profiles := get_node_or_null("/root/ProfileManager")
    if profiles != null and profiles.rename_profile(selected_slot, name_edit.text):
        refresh()


func _new_run() -> void:
    var profiles := get_node_or_null("/root/ProfileManager")
    var state := get_node_or_null("/root/LoopState")
    if profiles == null or state == null or selected_slot == 0 \
            or profiles.active_slot != selected_slot:
        return
    state.start_new_run()
    launch_requested.emit("res://gameplay/tutorial.tscn")


func _continue() -> void:
    var state := get_node_or_null("/root/LoopState")
    if state == null or selected_slot == 0 or not state.has_continue():
        return
    launch_requested.emit("res://main.tscn" if state.tutorial_done \
        else "res://gameplay/tutorial.tscn")


func _request_delete() -> void:
    if selected_slot == 0:
        return
    delete_dialog.title = _word("Profil löschen", "Delete profile")
    delete_dialog.dialog_text = _word(
        "Dieses Profil mit allen Durchläufen und Entdeckungen unwiderruflich löschen?",
        "Permanently delete this profile, all runs and discoveries?")
    delete_dialog.popup_centered()


func _delete_selected() -> void:
    var profiles := get_node_or_null("/root/ProfileManager")
    if profiles != null and profiles.delete_profile(selected_slot):
        selected_slot = 0
        name_edit.text = ""
        refresh()
