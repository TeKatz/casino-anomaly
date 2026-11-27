extends Node3D
## World-space review plaque: a missed effect gets a vague, localized clue.
## Names, exact targets and archive descriptions remain locked.
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
## No HUD, no collision, no VoxelGI rebaking.
const BRASS := Color("#977b58")
const PLATE := Color("#181b20")
const LETTERS := Color("#d8c6a8")
const OK_COLOR := Color("#9eb39b")
const ERROR_COLOR := Color("#b78c7c")

var verdict: Dictionary = {}
var header: Label3D
var result: Label3D
var finding: Label3D
var series: Label3D
var hint: Label3D
var indicator_material: StandardMaterial3D


func place_for_lane(lane: String, bend_x: float, start_z: float,
        half_width: float) -> void:
    # Right-hand wall beyond the blind turn, facing inward. The sign stays
    # on the chosen physical connector across the no-teleport handoff.
    var direction := 1.0 if lane == "left" else -1.0
    var wall_x := bend_x - direction * (half_width + 0.09)
    position = Vector3(wall_x + direction * 0.14, 1.87,
        start_z + direction * 4.0)
    rotation.y = direction * PI * 0.5


func _ready() -> void:
    _construct()
    var settings := get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_setting_changed)
    _render()


func _box(name_value: String, size_value: Vector3, point: Vector3,
        material: Material) -> void:
    var item := MeshInstance3D.new()
    item.name = name_value
    item.position = point
    var shape := BoxMesh.new()
    shape.size = size_value
    item.mesh = shape
    item.material_override = material
    add_child(item)


func _material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metal
    mat.roughness = 0.47
    return mat


func _label(label_name: String, height: float, size_value: int,
        color: Color) -> Label3D:
    var label := Label3D.new()
    label.name = label_name
    label.position = Vector3(0, height, 0.087)
    label.font = ThemeDB.fallback_font
    label.font_size = size_value
    label.pixel_size = 0.0049
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.modulate = color
    label.outline_size = 3
    label.outline_modulate = PLATE
    label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(label)
    return label


func _construct() -> void:
    _box("Backplate", Vector3(1.90, 1.50, 0.085),
        Vector3.ZERO, _material(PLATE, 0.32))
    var trim := _material(BRASS, 0.78)
    for side in [-1.0, 1.0]:
        _box("HorizontalTrim", Vector3(1.91, 0.022, 0.095),
            Vector3(0, side * 0.74, 0.008), trim)
        _box("VerticalTrim", Vector3(0.022, 1.50, 0.095),
            Vector3(side * 0.945, 0, 0.008), trim)
    header = _label("ProtocolHeader", 0.56, 26, LETTERS)
    result = _label("DecisionResult", 0.31, 32, LETTERS)
    finding = _label("NeutralFinding", 0.06, 25, LETTERS)
    hint = _label("MissedHint", -0.22, 21, Color("#efd6aa"))
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.width = 335.0
    hint.visible = false
    series = _label("Streak", -0.57, 25, LETTERS)
    indicator_material = _material(OK_COLOR)
    indicator_material.emission_enabled = true
    indicator_material.emission = OK_COLOR
    indicator_material.emission_energy_multiplier = 0.65
    _box("Indicator", Vector3(0.065, 0.065, 0.017),
        Vector3(-0.81, 0.56, 0.058), indicator_material)


func _de() -> bool:
    var settings := get_node_or_null("/root/GameSettings")
    return settings != null and str(settings.get_option("language")) == "de"


func _on_setting_changed(key: String) -> void:
    if key == "language":
        _render()


func set_result(data: Dictionary) -> void:
    verdict = data.duplicate(true)
    if is_node_ready():
        _render()


func _render() -> void:
    if not is_node_ready() or verdict.is_empty():
        return
    var de := _de()
    var correct := bool(verdict.get("correct", false))
    var anomaly_present := bool(verdict.get("expected_anomaly",
        not str(verdict.get("anomaly_id", "")).is_empty()))
    header.text = ("PRÜFUNG %02d" if de else "REVIEW %02d") \
        % int(verdict.get("visited", 0))
    result.text = ("BESTÄTIGT" if correct else "NICHT BESTÄTIGT") if de \
        else ("ACCEPTED" if correct else "REJECTED")
    finding.text = ("BEFUND: ABWEICHUNG" if anomaly_present \
        else "BEFUND: UNAUFFÄLLIG") if de \
        else ("FINDING: IRREGULAR" if anomaly_present else "FINDING: CLEAR")
    var clue := Catalog.missed_review_hint(verdict, de)
    hint.visible = not clue.is_empty()
    hint.text = (("HINWEIS: " if de else "HINT: ") + clue) if hint.visible else ""
    if hint.visible:
        finding.text = "BEFUND: ÜBERSEHEN" if de else "FINDING: MISSED"
    else:
        # Distribute the four lines naturally when no hint is needed.
        finding.position.y = -0.02
    if hint.visible:
        finding.position.y = 0.06
    var mode := str(verdict.get("mode", "classic"))
    var goal := int(verdict.get("goal", 12))
    var progress := int(verdict.get("progress", verdict.get("streak", 0)))
    var prefix := "RÄUME" if de else "ROOMS"
    if mode in ["classic", "endless", "nightmare"]:
        prefix = "SERIE" if de else "STREAK"
    if mode == "endless" and bool(verdict.get("failed", false)):
        progress = int(verdict.get("previous_streak", 0))
    series.text = "%s %02d / %d" % [prefix, progress, goal] if goal > 0 else "%s %02d" % [prefix, progress]
    var tone := OK_COLOR if correct else ERROR_COLOR
    result.modulate = tone
    indicator_material.albedo_color = tone
    indicator_material.emission = tone
