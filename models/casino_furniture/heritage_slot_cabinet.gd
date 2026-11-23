@tool
extends Node3D
## Authored heritage slot cabinet. All meshes/colliders are part of its
## shared PackedScene; this script only personalizes typography and light.
const ACCENTS = [
    Color("#eeac68"), Color("#6ec8d5"), Color("#be9ee1"), Color("#ed9187")
]
@export_range(0, 3, 1) var accent_variant: int = 0
@export var cabinet_title: String = "MIDNIGHT"
@export_range(0, 4, 1) var reel_seed: int = 0


func _ready() -> void:
    set_meta("slot_cabinet_revision", 2)
    var color: Color = ACCENTS[clampi(accent_variant, 0, ACCENTS.size() - 1)]
    var heading := get_node_or_null("MachineTitle") as Label3D
    if heading != null:
        heading.text = cabinet_title
        heading.modulate = color.lightened(0.26)
    # Separate materials are important: CasinoAtmosphere animates TopGlow
    # independently on every machine; shared materials synchronized the
    # lights and made the scene feel artificial.
    _colorize("TopGlow", color, 1.82)
    _colorize("FrontStatus", color.darkened(0.36), 0.73)
    _colorize("TopperMedallion", color, 1.05)
    for index in range(3):
        _colorize("ControlLamp_%d" % index,
                color if index == 1 else color.darkened(0.57),
                1.5 if index == 1 else 0.32)
    var symbols: Array[String] = ["7", "BAR", "★", "♦", "♣"]
    for i in range(3):
        var reel := get_node_or_null("ReelGlyph_%d" % i) as Label3D
        if reel != null:
            var symbol: String = symbols[(reel_seed + i * 2) % symbols.size()]
            reel.text = symbol
            reel.font_size = 18 if symbol == "BAR" else 35


func _colorize(path: String, color: Color, energy: float) -> void:
    var node := get_node_or_null(path) as MeshInstance3D
    if node == null:
        return
    var base := node.material_override as StandardMaterial3D
    if base == null:
        return
    var material := base.duplicate() as StandardMaterial3D
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    node.material_override = material
