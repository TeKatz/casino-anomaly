extends CanvasLayer
const Controls = preload("res://gameplay/input_bindings.gd")
var crosshair: Control
var captions: PanelContainer
var caption: Label
var until := 0
var current_cue := ""
var player: CharacterBody3D
var _crosshair_enabled := false
var _captions_enabled := false
var _german := false

func _ready() -> void:
    layer = 44
    player = get_parent() as CharacterBody3D
    var root := Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    crosshair = Control.new()
    crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(crosshair)
    crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    crosshair.draw.connect(_draw_crosshair)
    captions = PanelContainer.new()
    captions.set_meta("_independent_caption", true)
    captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(captions)
    captions.anchor_left = 0.5
    captions.anchor_right = 0.5
    captions.anchor_top = 1.0
    captions.anchor_bottom = 1.0
    captions.offset_left = -200
    captions.offset_right = 200
    captions.offset_top = -58
    captions.offset_bottom = -12
    caption = Label.new()
    caption.set_meta("_independent_caption", true)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    captions.add_child(caption)
    var options := get_node_or_null("/root/GameSettings")
    if options != null:
        options.connect("options_changed", _on_option)
    _on_option("")

func _on_option(key: String) -> void:
    if key not in ["", "crosshair", "crosshair_size", "crosshair_color", "hud_visible", "sound_captions", "caption_size", "caption_background", "language"]:
        return
    var card := StyleBoxFlat.new()
    card.bg_color = Color(0, 0, 0, float(Controls.pref(self, "caption_background", 0.7)))
    card.set_corner_radius_all(6)
    card.content_margin_top = 5
    card.content_margin_bottom = 5
    captions.add_theme_stylebox_override("panel", card)
    var scale: float = {"small": 0.85, "normal": 1.0, "large": 1.25, "very_large": 1.5}[Controls.pref(self, "caption_size", "normal")]
    caption.add_theme_font_size_override("font_size", roundi(18 * scale))
    caption.add_theme_color_override("font_color", Color.WHITE)
    caption.add_theme_constant_override("outline_size", 4)
    caption.add_theme_color_override("font_outline_color", Color.BLACK)
    _crosshair_enabled = bool(Controls.pref(self, "hud_visible", true)) and Controls.pref(self, "crosshair", "off") != "off"
    _captions_enabled = bool(Controls.pref(self, "sound_captions", false))
    _german = Controls.pref(self, "language", "en") == "de"
    crosshair.queue_redraw()
    _sync()
    # Player/loop state can change directly during a handoff. Keep immediate
    # state tracking only while at least one accessibility feature is active.
    set_process(_crosshair_enabled or _captions_enabled)

func _draw_crosshair() -> void:
    var style := str(Controls.pref(self, "crosshair", "off"))
    var width := float(Controls.pref(self, "crosshair_size", 1.0))
    var color: Color = {"white": Color.WHITE, "yellow": Color.YELLOW, "cyan": Color.CYAN, "green": Color.GREEN, "black": Color.BLACK}[Controls.pref(self, "crosshair_color", "white")]
    var edge := Color.WHITE if color == Color.BLACK else Color.BLACK
    if style == "dot":
        crosshair.draw_circle(Vector2.ZERO, 3.2 * width, edge)
        crosshair.draw_circle(Vector2.ZERO, 2.0 * width, color)
    elif style == "cross":
        for axis in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
            crosshair.draw_line(axis * 3 * width, axis * 10 * width, edge, 4 * width, true)
            crosshair.draw_line(axis * 3 * width, axis * 10 * width, color, 2 * width, true)

func announce(cue: String) -> void:
    current_cue = cue
    until = Time.get_ticks_msec() + 1600
    _sync()

func _process(_delta: float) -> void:
    _sync()

func _sync() -> void:
    var available := is_instance_valid(player) and not bool(player.get("interaction_locked")) and not get_tree().paused
    var show_crosshair := available and _crosshair_enabled
    if crosshair.visible != show_crosshair:
        crosshair.visible = show_crosshair
    if not available or not _captions_enabled:
        if captions.visible:
            captions.hide()
        return
    var cue := current_cue if Time.get_ticks_msec() < until else ""
    if cue.is_empty() and is_instance_valid(player) and bool(player.get("backrooms_mode")):
        var controller := player.get_parent().get_node_or_null("LoopController")
        if controller != null and not bool(controller.get("backrooms_scored")):
            cue = "hum"
    var show_caption := not cue.is_empty()
    if captions.visible != show_caption:
        captions.visible = show_caption
    if show_caption:
        var message := ("[Schritte]" if _german else "[Footsteps]") if cue == "steps" else ("[Elektrisches Brummen]" if _german else "[Electrical hum]")
        if caption.text != message:
            caption.text = message
