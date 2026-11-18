extends Node3D

# Non-colliding atmosphere, independent of gameplay/anomaly targets.
# Uses only Godot 4.5.1 GL Compatibility features.
@export var active: bool = true

const GOLD = Color("#e8b76f")
const CYAN = Color("#75d5dd")
const WARM = Color("#ffdfb6")

var elapsed := 0.0
var slot_glows: Array[StandardMaterial3D] = []
var slot_phases: Array[float] = []
var slot_spills: Array[OmniLight3D] = []
var signs: Array[StandardMaterial3D] = []

func _ready() -> void:
    call_deferred("_build") # Hall geometry is procedural and assembled in parent _ready.

func _build() -> void:
    if not active:
        return
    set_meta("ambient_fx_only", true)
    _architecture()
    _spot("CatHighlight", Vector3(-9.15, 4.7, -3.25),
        Vector3(-9.15, 1.0, -1.05), 1.05)
    _spot("ChessHighlight", Vector3(-28.6, 4.7, -4.25),
        Vector3(-28.6, 0.65, -2.75), 0.85)
    _spot("HorseHighlight", Vector3(-44.1, 4.8, -3.1),
        Vector3(-44.2, 1.1, -1.35), 1.05)
    _spot("BustHighlight", Vector3(-3.5, 4.8, 10.8),
        Vector3(-2.75, 1.35, 12.15), 0.75)
    _slots()
    _dust()

func _glow(color: Color, power: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color.darkened(0.28)
    mat.roughness = 0.35
    mat.metallic = 0.34
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = power
    return mat

func _bar(label: String, pos: Vector3, size: Vector3, mat: Material) -> void:
    var part := MeshInstance3D.new()
    part.name = label
    var box := BoxMesh.new()
    box.size = size
    part.mesh = box
    part.position = pos
    part.material_override = mat
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(part)

func _frame(label: String, pos: Vector3, width: float, height: float,
        mat: StandardMaterial3D) -> void:
    _bar(label + "Top", pos + Vector3(0, height * 0.5, 0),
        Vector3(width, 0.045, 0.045), mat)
    _bar(label + "Bottom", pos - Vector3(0, height * 0.5, 0),
        Vector3(width, 0.045, 0.045), mat)
    for side in [-1.0, 1.0]:
        _bar(label + ("Left" if side < 0.0 else "Right"),
            pos + Vector3(side * width * 0.5, 0, 0),
            Vector3(0.045, height, 0.045), mat)

func _architecture() -> void:
    # Warm cornice lines sit flush against wall; no light strips in passage.
    var cove := _glow(GOLD, 1.15)
    _bar("EastCove", Vector3(5.88, 5.53, 4.6),
        Vector3(0.035, 0.034, 18.1), cove)
    _bar("EntryCove", Vector3(-5.88, 5.53, 7.0),
        Vector3(0.035, 0.034, 13.1), cove)
    _bar("NorthCove", Vector3(-26.0, 5.53, -12.88),
        Vector3(39.0, 0.034, 0.035), cove)
    _bar("SouthCove", Vector3(-26.0, 5.53, -0.19),
        Vector3(39.0, 0.034, 0.035), cove)
    # Frames light the already existing labels; no duplicate text.
    var front := _glow(GOLD, 1.8)
    var counter := _glow(CYAN, 1.55)
    signs.append(front)
    signs.append(counter)
    _frame("EntrySign", Vector3(0, 4.15, 13.73), 5.6, 0.84, front)
    # hall.gd shifts the bar's container left by 0.95 m.
    _frame("BarSign", Vector3(-2.33, 4.72, -12.30), 4.35, 1.04, counter)

func _spot(label: String, pos: Vector3, target: Vector3, power: float) -> void:
    var lamp := SpotLight3D.new()
    lamp.name = label
    lamp.position = pos
    lamp.light_color = WARM
    lamp.light_energy = power
    lamp.spot_range = 6.2
    lamp.spot_angle = 32.0
    lamp.spot_attenuation = 1.8
    lamp.shadow_enabled = false
    add_child(lamp)
    lamp.look_at(target, Vector3.UP)

func _slots() -> void:
    var slots: Node3D = get_parent().get_node_or_null("SlotMachines") as Node3D
    if slots == null:
        push_warning("Casino atmosphere: slot machines unavailable")
        return
    var i := 0
    for node in slots.get_children():
        var unit: Node3D = node as Node3D
        if unit == null or not unit.name.begins_with("Slot_"):
            continue
        var lip: MeshInstance3D = unit.get_node_or_null("TopGlow") as MeshInstance3D
        if lip == null:
            continue
        var material: StandardMaterial3D = lip.material_override as StandardMaterial3D
        if material == null:
            continue
        slot_glows.append(material)
        slot_phases.append(float(i) * 0.72)
        # One small unshadowed light per two machines; emissive strips do
        # the rest so the room doesn't accumulate heavy per-pixel lights.
        if i % 2 == 0:
            var light := OmniLight3D.new()
            light.name = "SlotSpill%02d" % i
            light.position = unit.position + unit.transform.basis * Vector3(0, 1.55, 0.70)
            light.light_color = material.emission.lerp(WARM, 0.3)
            light.light_energy = 0.24
            light.omni_range = 2.7
            light.shadow_enabled = false
            add_child(light)
            slot_spills.append(light)
        i += 1

func _dust() -> void:
    # Sparse CPU motes near just two chandeliers; no volumetric fog.
    var mesh := SphereMesh.new()
    mesh.radius = 0.012
    mesh.height = 0.024
    mesh.radial_segments = 6
    mesh.rings = 4
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1, 0.86, 0.66, 0.6)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.material = mat
    for pos in [Vector3(-1.4, 3.4, -6.8), Vector3(-30.0, 3.4, -6.5)]:
        var particles := CPUParticles3D.new()
        particles.name = "ChandelierDust"
        particles.position = pos
        particles.amount = 22
        particles.lifetime = 7.5
        particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
        particles.emission_box_extents = Vector3(2.1, 1.2, 2.1)
        particles.direction = Vector3.UP
        particles.spread = 170.0
        particles.gravity = Vector3(0, 0.005, 0)
        particles.initial_velocity_min = 0.01
        particles.initial_velocity_max = 0.05
        particles.mesh = mesh
        particles.emitting = true
        add_child(particles)

func _process(delta: float) -> void:
    if not active:
        return
    elapsed += delta
    # Slow ambient breathing, never an anomaly-like sudden flicker.
    for i in range(slot_glows.size()):
        slot_glows[i].emission_energy_multiplier = 2.0 + (
            0.28 * sin(elapsed * 1.1 + slot_phases[i]))
    for i in range(slot_spills.size()):
        slot_spills[i].light_energy = 0.24 + (
            0.055 * sin(elapsed * 1.1 + float(i) * 1.44))
    for i in range(signs.size()):
        signs[i].emission_energy_multiplier = (
            (1.8 if i == 0 else 1.55) +
            0.12 * sin(elapsed * 0.58 + float(i)))
