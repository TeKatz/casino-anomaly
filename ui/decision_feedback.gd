extends CanvasLayer
## Small, timed verdict in the NEXT room; no teleport or modal interruption.
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
var panel: PanelContainer
var message: Label
var fade: Tween


func _ready() -> void:
    layer = 60
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    panel = PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.offset_left = -310
    panel.offset_right = 310
    panel.offset_top = 32
    panel.offset_bottom = 142
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#101a29", 0.94)
    style.border_color = Color("#b99a65", 0.85)
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.shadow_size = 10
    style.shadow_color = Color(0, 0, 0, 0.55)
    panel.add_theme_stylebox_override("panel", style)
    root.add_child(panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    panel.add_child(margin)
    message = Label.new()
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    message.add_theme_font_size_override("font_size", 17)
    message.add_theme_color_override("font_color", Color("#f5f1e9"))
    margin.add_child(message)
    panel.visible = false


func _de() -> bool:
    var settings := get_node_or_null("/root/GameSettings")
    return settings != null and str(settings.get_option("language")) == "de"


func show_verdict(result: Dictionary) -> void:
    if not bool(result.get("valid", false)):
        return
    if fade != null and fade.is_running():
        fade.kill()
    var right := bool(result.get("correct", false))
    var id := str(result.get("anomaly_id", ""))
    var room_no := int(result.get("visited", 0))
    if right:
        message.text = ("RICHTIG · RAUM %d" if _de() else "CORRECT · ROOM %d") % room_no
    elif id.is_empty():
        message.text = ("FALSCHE ENTSCHEIDUNG · RAUM %d\n"
            + "Der vorherige Raum war unverändert. Serie: %d → 0" \
            if _de() else "WRONG DECISION · ROOM %d\n"
            + "The previous room was normal. Streak: %d → 0") \
            % [room_no, int(result.get("previous_streak", 0))]
    else:
        var definition := Catalog.get_entry(id)
        var title := str(definition.get("title_de" if _de() else "title_en", id))
        var description := str(definition.get("description_de" if _de() \
            else "description_en", ""))
        message.text = (("ANOMALIE ÜBERSEHEN · RAUM %d\n%s — %s" if _de() \
            else "MISSED ANOMALY · ROOM %d\n%s — %s") \
            % [room_no, title, description])
    panel.visible = true
    panel.modulate.a = 0.0
    fade = create_tween()
    fade.tween_property(panel, "modulate:a", 1.0, 0.25)
    fade.tween_interval(2.0 if right else 6.5)
    fade.tween_property(panel, "modulate:a", 0.0, 0.35)
    fade.tween_callback(func() -> void: panel.visible = false)
