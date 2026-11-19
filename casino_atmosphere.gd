extends Node3D

# Non-colliding atmosphere, independent of gameplay/anomaly targets.
# Uses Godot 4.5.1 Forward+ for volumetric lighting and screen-space occlusion.
@export var active: bool = true

const GOLD = Color("#e8b76f")
const CYAN = Color("#75d5dd")
const WARM = Color("#ffdfb6")

var elapsed := 0.0
var slot_glows: Array[StandardMaterial3D] = []
var slot_phases: Array[float] = []
var slot_spills: Array[OmniLight3D] = []
var signs: Array[StandardMaterial3D] = []
var plant_crowns: Array[Node3D] = []

func _ready() -> void:
    # The one-time scene baker captures static neon frames and spotlights.
    # Do not build transient particle/spill effects during that process.
    if get_parent().has_meta("_baking_room"):
        return
    call_deferred("_build")

func _build() -> void:
    if not active:
        return
    set_meta("ambient_fx_only", true)
    _ensure_reflection_probes()
    if not has_node("EntrySignTop"):
        _architecture()
        _spot("CatHighlight", Vector3(-8.45, 4.7, -3.25),
            Vector3(-8.45, 1.0, -1.04), 1.05)
        _spot("ChessHighlight", Vector3(-28.6, 4.7, -4.25),
            Vector3(-28.6, 0.65, -2.75), 0.85)
        _spot("HorseHighlight", Vector3(-44.1, 4.8, -3.1),
            Vector3(-44.2, 1.1, -1.35), 1.05)
        _spot("BustHighlight", Vector3(-3.5, 4.8, 10.8),
            Vector3(-2.75, 1.35, 12.15), 0.75)
    else:
        # Animate the saved materials rather than creating a second neon layer.
        for label in ["EntrySignTop", "BarSignTop"]:
            var neon := get_node_or_null(label) as MeshInstance3D
            if neon != null and neon.material_override is StandardMaterial3D:
                signs.append(neon.material_override as StandardMaterial3D)
    _slots()
    _plants()
    _dust()

func _ensure_reflection_probes() -> void:
    # Some PackedScene imports skip a hand-added first probe. Re-create only
    # missing ones; never duplicate a designer-authored probe. Crucially,
    # newly built standby halls must NOT issue GPU reflection captures.
    var enabled := not get_parent().has_meta("_streaming_standby")
    _ensure_probe("MainWingReflection", Vector3(0, 3, 0.5),
        Vector3(11.8, 5.7, 26.6), 0.72, enabled)
    _ensure_probe("WestWingReflection", Vector3(-26, 3, -6.5),
        Vector3(39.2, 5.7, 12.5), 0.68, enabled)


func _ensure_probe(label: String, center: Vector3, extents: Vector3,
        power: float, enabled: bool) -> void:
    var probe := get_node_or_null(label) as ReflectionProbe
    if probe == null:
        probe = ReflectionProbe.new()
        probe.name = label
        probe.position = center
        probe.size = extents
        probe.blend_distance = 0.6
        probe.box_projection = true
        probe.interior = true
        probe.intensity = power
        probe.max_distance = 25.0
        probe.enable_shadows = false
        probe.update_mode = ReflectionProbe.UPDATE_ONCE
        add_child(probe)
    probe.visible = enabled


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
    var cove := _glow(GOLD, 0.92)
    _bar("EastCove", Vector3(5.88, 5.53, 4.6),
        Vector3(0.035, 0.034, 18.1), cove)
    _bar("EntryCove", Vector3(-5.88, 5.53, 7.0),
        Vector3(0.035, 0.034, 13.1), cove)
    _bar("NorthCove", Vector3(-26.0, 5.53, -12.88),
        Vector3(39.0, 0.034, 0.035), cove)
    _bar("SouthCove", Vector3(-26.0, 5.53, -0.19),
        Vector3(39.0, 0.034, 0.035), cove)
    # Frames light the already existing labels; no duplicate text.
    var front := _glow(GOLD, 1.60)
    var counter := _glow(CYAN, 1.32)
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
    lamp.spot_range = 4.9
    lamp.spot_angle = 25.0
    lamp.spot_attenuation = 1.8
    # Controlled cones of light become visible in the Forward+ fog.
    lamp.light_volumetric_fog_energy = 0.38
    # Only the cat's display spot casts additional shadows; the other
    # spotlights remain shadowless to limit rendering cost.
    lamp.shadow_enabled = label == "CatHighlight" or label == "HorseHighlight"
    if lamp.shadow_enabled:
        lamp.shadow_bias = 0.06
        lamp.shadow_blur = 1.30
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
            light.light_energy = 0.18
            light.omni_range = 2.25
            # Animated slot washes should not smear through fog reprojection.
            light.light_volumetric_fog_energy = 0.0
            light.shadow_enabled = false
            add_child(light)
            slot_spills.append(light)
        i += 1

func _plants() -> void:
    # Almost imperceptible indoor-air motion, independent of their solid pots.
    # Never move collision bodies or the stable anomaly landmarks.
    var decoration: Node3D = get_parent().get_node_or_null("Decor") as Node3D
    if decoration == null:
        return
    for plant in decoration.get_children():
        if plant is Node3D and plant.name.begins_with("Plant_"):
            for crown in plant.get_children():
                if crown is Node3D and crown.name.begins_with("PlantFoliage_"):
                    plant_crowns.append(crown as Node3D)


func _dust() -> void:
    # Fine atmospheric dust is distributed throughout both wings rather
    # than clustering under the five chandelier positions. Deliberately
    # non-emissive, tiny and slow: it must never resemble falling snow.
    var mesh := SphereMesh.new()
    mesh.radius = 0.007
    mesh.height = 0.014
    mesh.radial_segments = 6
    mesh.rings = 4
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.96, 0.86, 0.74, 0.22)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.material = mat
    # Broad, overlapping volumes cover the walkable hall at several heights.
    # Keep boxes below the ceiling and outside the floor.
    var dust_index := 0
    for pos in [
        Vector3(-1.9, 2.9, 10.5),
        Vector3(2.1, 2.7, 6.5),
        Vector3(-1.6, 2.8, 2.5),
        Vector3(1.7, 2.9, -2.0),
        Vector3(-4.8, 2.8, -6.3),
        Vector3(-10.2, 2.7, -7.6),
        Vector3(-15.7, 2.8, -4.4),
        Vector3(-21.2, 2.7, -7.5),
        Vector3(-26.8, 2.9, -4.6),
        Vector3(-32.3, 2.8, -7.4),
        Vector3(-37.8, 2.7, -4.6),
        Vector3(-43.0, 2.8, -7.2)
    ]:
        var particles := CPUParticles3D.new()
        particles.name = "AmbientDust_%02d" % dust_index
        dust_index += 1
        particles.position = pos
        particles.amount = 22
        particles.lifetime = 11.0
        particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
        particles.emission_box_extents = Vector3(3.1, 1.85, 3.15)
        particles.direction = Vector3.UP
        particles.spread = 180.0
        particles.gravity = Vector3.ZERO
        particles.initial_velocity_min = 0.006
        particles.initial_velocity_max = 0.020
        particles.mesh = mesh
        particles.emitting = true
        add_child(particles)

func _process(delta: float) -> void:
    if not active:
        return
    elapsed += delta
    # Slow ambient breathing, never an anomaly-like sudden flicker.
    for i in range(slot_glows.size()):
        slot_glows[i].emission_energy_multiplier = 1.85 + (
            0.20 * sin(elapsed * 1.1 + slot_phases[i]))
    for i in range(slot_spills.size()):
        slot_spills[i].light_energy = 0.18 + (
            0.035 * sin(elapsed * 1.1 + float(i) * 1.44))
    for i in range(signs.size()):
        signs[i].emission_energy_multiplier = (
            (1.6 if i == 0 else 1.32) +
            0.08 * sin(elapsed * 0.58 + float(i)))
    for i in range(plant_crowns.size()):
        # Slow <1-degree sway, deliberately subtle for an indoor casino.
        plant_crowns[i].rotation.z = 0.009 * sin(elapsed * 0.47 + float(i) * 1.7)
        plant_crowns[i].rotation.x = 0.007 * sin(elapsed * 0.39 + float(i) * 2.1)

