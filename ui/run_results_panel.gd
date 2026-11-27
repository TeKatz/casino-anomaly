extends PanelContainer
## Summary of the actual run, never inferred from lifetime statistics.
signal back_pressed
const Style = preload("res://ui/menu_style.gd")
const Progress = preload("res://gameplay/progression.gd")
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const Modes = preload("res://gameplay/run_modes.gd")
const Controls = preload("res://gameplay/input_bindings.gd")
var report: Dictionary = {}
var de := false

func set_report(data: Dictionary) -> void:
    report = data.duplicate(true)

func _word(en: String, german: String) -> String:
    return german if de else en

func _label(parent: Container, value: String, font_size: int = 16, tint: Color = Style.PALE) -> Label:
    var label: Label = Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",tint)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(label)
    return label

func _section(parent: VBoxContainer, heading: String) -> void:
    parent.add_child(HSeparator.new())
    _label(parent,heading,19,Style.GOLD)

func _metric(parent: GridContainer, caption: String, value: String) -> void:
    var card: PanelContainer = PanelContainer.new()
    var background: StyleBoxFlat = Style.flat_surface(Color("#202127"),Color("#655639"),8)
    background.content_margin_left = 14.0
    background.content_margin_right = 14.0
    background.content_margin_top = 9.0
    background.content_margin_bottom = 9.0
    card.add_theme_stylebox_override("panel",background)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(card)
    var stack: VBoxContainer = VBoxContainer.new()
    card.add_child(stack)
    _label(stack,caption,14,Color("#abb4c0"))
    _label(stack,value,26,Style.GOLD)

func _ready() -> void:
    de = str(Controls.pref(self,"language","en")) == "de"
    custom_minimum_size = Vector2(740,650)
    add_theme_stylebox_override("panel",Style.panel())
    var margins: MarginContainer = MarginContainer.new()
    for side in ["left","right","top","bottom"]:
        margins.add_theme_constant_override("margin_"+str(side),24)
    add_child(margins)
    var layout: VBoxContainer = VBoxContainer.new()
    layout.add_theme_constant_override("separation",12)
    margins.add_child(layout)
    _label(layout,_word("CASINO ANOMALY  /  RUN REVIEW","CASINO ANOMALY  /  DURCHLAUFBERICHT"),13,Color("#abb4c0"))
    var failed: bool = bool(report.get("failed",false))
    _label(layout,_word("RUN ENDED","DURCHLAUF BEENDET") if failed else _word("RUN COMPLETE","DURCHLAUF ABGESCHLOSSEN"),31,Style.GOLD)
    var mode_id: String = str(report.get("mode","classic"))
    _label(layout,Modes.title(mode_id,de),17)
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(680,420)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    layout.add_child(scroll)
    var body: VBoxContainer = VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation",9)
    scroll.add_child(body)
    var grid: GridContainer = GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation",8)
    grid.add_theme_constant_override("v_separation",8)
    body.add_child(grid)
    _metric(grid,_word("Rooms","Räume"),str(report.get("rooms",0)))
    _metric(grid,_word("Correct","Richtig"),str(report.get("correct",0)))
    _metric(grid,_word("Resets","Resets") if mode_id=="classic" else _word("Mistakes","Fehler"),str(report.get("resets" if mode_id=="classic" else "mistakes",0)))
    var identified: Dictionary = report.get("identified",{})
    var count: int = 0
    for id in identified:
        count += int(identified[id])
    _metric(grid,_word("Anomalies identified","Anomalien erkannt"),str(count))
    _metric(grid,_word("Missed anomalies","Übersehene Anomalien"),str(report.get("missed_anomalies",0)))
    _metric(grid,_word("XP earned","Erhaltene XP"),"+%d" % int(report.get("xp_earned",0)))
    if report.has("xp_before") and report.has("xp_after"):
        var before: Dictionary = Progress.level_info(int(report["xp_before"]))
        var after: Dictionary = Progress.level_info(int(report["xp_after"]))
        _section(body,_word("Profile progression","Profilfortschritt"))
        _label(body,"LEVEL %d  →  %d  •  %s" % [int(before["level"]),int(after["level"]),Progress.rank(int(after["level"]),de)],22,Style.GOLD)
        var bar: ProgressBar = ProgressBar.new()
        bar.max_value = maxf(1.0,float(after["next"]))
        bar.custom_minimum_size.y = 12
        bar.show_percentage = false
        body.add_child(bar)
        Style.apply_progress(bar,float(after["current"]) if int(after["next"])>0 else 1.0)
    if mode_id=="time_trial":
        _label(body,_word("Time including penalties: %.1f s","Zeit inklusive Strafzeit: %.1f s") % float(report.get("score_seconds",0.0)))
    if bool(report.get("assisted",false)):
        _label(body,_word("Developer-assisted run — forced rooms do not award progression.","Entwicklerunterstützter Durchlauf — erzwungene Räume zählen nicht zum Fortschritt."),14,Style.AMBER)
    if int(report.get("tracked_rooms",0))<int(report.get("rooms",0)):
        _label(body,_word("Continued from an older save. Detailed discoveries and XP cover only rooms played after the update.","Aus einem älteren Spielstand fortgesetzt. Entdeckungen und XP umfassen nur Räume seit dem Update."),14,Style.AMBER)
    var modes: Dictionary = report.get("new_modes",{})
    if not modes.is_empty():
        _section(body,_word("NEW MODES UNLOCKED","NEUE SPIELMODI FREIGESCHALTET"))
        for id in modes:
            _label(body,"★  "+Modes.title(str(id),de),21,Style.GREEN)
    _section(body,_word("Achievements unlocked","Freigeschaltete Achievements"))
    var achievements: Dictionary = report.get("new_achievements",{})
    if achievements.is_empty():
        _label(body,_word("No new achievements in this run.","Keine neuen Achievements in diesem Durchlauf."),15,Color("#abb4c0"))
    for entry in Progress.achievement_definitions():
        if bool(achievements.get(entry["id"],false)):
            _label(body,"★  "+str(entry["de" if de else "en"]),18,Style.GOLD)
            _label(body,str(entry["description_de" if de else "description_en"]),14,Color("#abb4c0"))
    _section(body,_word("Identified anomalies","Erkannte Anomalien"))
    var discoveries: Dictionary = report.get("new_discoveries",{})
    if identified.is_empty():
        _label(body,_word("No recorded discoveries.","Keine aufgezeichneten Entdeckungen."),15,Color("#abb4c0"))
    for id in identified:
        var entry: Dictionary = Catalog.get_entry(str(id))
        var title: String = str(entry.get("title_de" if de else "title_en",str(id)))
        var is_new: bool = bool(discoveries.get(Catalog.family(str(id)),false))
        _label(body,("%s  ×%d" % [title,int(identified[id])])+("  •  "+_word("NEW","NEU") if is_new else ""),16,Style.GREEN if is_new else Style.PALE)
    var button: Button = Button.new()
    button.name = "RunResultsContinue"
    button.text = _word("RETURN TO MAIN MENU","ZURÜCK ZUM HAUPTMENÜ")
    button.custom_minimum_size.y = 48
    Style.apply_button(button,true,"green")
    button.pressed.connect(func(): back_pressed.emit())
    layout.add_child(button)
    button.grab_focus()
