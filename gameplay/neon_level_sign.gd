@tool
extends Node3D
## A physical, wall-mounted progress display. No CanvasLayer or screen-space
## text: the mesh uses actual emissive geometry and a local accent light.
## Room-local transform keeps it in the same authored spot after streaming.

# Central solid pier on the western far wall, between the two exits.
# The player approaches it looking west, so the front must face +X.
const WALL_POSITION := Vector3(-45.94, 4.45, -6.68)
const ACTIVE_COLOR := Color("#ff735c")
const FINISH_COLOR := Color("#ffe1a0")

var number_mesh: TextMesh
var caption_mesh: TextMesh
var tubes: StandardMaterial3D
var accent: OmniLight3D


func _ready() -> void:
    position = WALL_POSITION
    rotation.y = PI # Turn the mesh/front light from -X to +X, into the hall.

    var backing := StandardMaterial3D.new()
    backing.albedo_color = Color("#141012")
    backing.metallic = 0.60
    backing.roughness = 0.30
    _box("EnamelBackplate", Vector3.ZERO, Vector3(0.12, 1.86, 2.92), backing)

    var trim := StandardMaterial3D.new()
    trim.albedo_color = Color("#9c754c")
    trim.metallic = 0.80
    trim.roughness = 0.26
    for h in [-0.89, 0.89]:
        _box("BrassTopBottom", Vector3(-0.012, h, 0), Vector3(0.14, 0.045, 2.96), trim)
    for z in [-1.46, 1.46]:
        _box("BrassEnds", Vector3(-0.012, 0, z), Vector3(0.14, 1.82, 0.045), trim)

    tubes = StandardMaterial3D.new()
    tubes.albedo_color = ACTIVE_COLOR
    tubes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    tubes.emission_enabled = true
    tubes.emission = ACTIVE_COLOR
    tubes.emission_energy_multiplier = 3.2

    number_mesh = TextMesh.new()
    number_mesh.font = ThemeDB.fallback_font
    number_mesh.text = "0"
    number_mesh.font_size = 190
    number_mesh.pixel_size = 0.0058
    number_mesh.depth = 0.028
    number_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    number_mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var number_node := MeshInstance3D.new()
    number_node.name = "Number"
    number_node.mesh = number_mesh
    number_node.material_override = tubes
    number_node.rotation.y = -PI / 2.0
    number_node.position = Vector3(-0.105, 0.14, 0)
    add_child(number_node)

    caption_mesh = TextMesh.new()
    caption_mesh.font = ThemeDB.fallback_font
    caption_mesh.font_size = 38
    caption_mesh.pixel_size = 0.0046
    caption_mesh.depth = 0.014
    caption_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption_mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var caption := MeshInstance3D.new()
    caption.name = "CompletionText"
    caption.mesh = caption_mesh
    caption.material_override = tubes
    caption.rotation.y = -PI / 2.0
    caption.position = Vector3(-0.11, -0.65, 0)
    add_child(caption)

    accent = OmniLight3D.new()
    accent.name = "NeonGlow"
    accent.position = Vector3(-0.40, 0, 0)
    accent.light_color = ACTIVE_COLOR
    accent.light_energy = 0.72
    accent.omni_range = 3.25
    accent.shadow_enabled = false
    # Do not alter the established pre-baked casino GI when artists rebake.
    accent.light_bake_mode = Light3D.BAKE_DISABLED
    add_child(accent)


func _box(part_name: String, local_position: Vector3, size: Vector3,
        material: Material) -> void:
    var part := MeshInstance3D.new()
    part.name = part_name
    part.position = local_position
    var box := BoxMesh.new()
    box.size = size
    part.mesh = box
    part.material_override = material
    add_child(part)


func set_progress(level: int, completed: bool, victory_text: String = "") -> void:
    number_mesh.text = str(level)
    number_mesh.font_size = 190 if level < 100 else (135 if level < 1000 else 100)
    caption_mesh.text = victory_text if completed else ""
    var color := FINISH_COLOR if completed else ACTIVE_COLOR
    tubes.albedo_color = color
    tubes.emission = color
    accent.light_color = color
