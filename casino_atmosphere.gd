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
    _ensure_bar_fill_lights()
    _ensure_practical_lights()
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


func _ensure_practical_lights() -> void:
    # Emissive materials and SSIL alone do not emit dependable realtime
    # light into nearby meshes. These actual lights connect the glowing
    # architecture with the surrounding wood, tables and floor.
    _ensure_table_key_lights()
    _ensure_neon_wall_washes()
    _ensure_neon_sign_spills()


func _ensure_table_key_lights() -> void:
    var tables := get_parent().get_node_or_null("GamingTables") as Node3D
    if tables == null:
        return
    for table_node in tables.get_children():
        var table := table_node as Node3D
        if table == null:
            continue
        if not (table.name.begins_with("Roulette") or
                table.name.begins_with("Blackjack") or
                table.name.begins_with("Cards")):
            continue
        # The small ceiling downlights are placed above the six existing
        # tables, with the light source INSIDE the room, below the ceiling.
        var name := "TableKey_" + str(table.name)
        if not has_node(name):
            var lamp := SpotLight3D.new()
            lamp.name = name
            lamp.position = table.position + Vector3(0.52, 5.72, 0.34)
            lamp.light_color = Color("#ffdda8")
            lamp.light_energy = 2.1
            lamp.spot_range = 6.25
            lamp.spot_angle = 33.0
            lamp.spot_attenuation = 1.30
            lamp.light_specular = 0.88
            lamp.light_size = 0.15
            lamp.shadow_enabled = true
            lamp.shadow_opacity = 0.90
            lamp.shadow_bias = 0.025
            lamp.shadow_normal_bias = 0.40
            lamp.shadow_blur = 1.1
            lamp.light_volumetric_fog_energy = 0.12
            # Expensive shadows are relevant to the nearby player, not to
            # tables forty meters down the long corridor.
            lamp.distance_fade_enabled = true
            lamp.distance_fade_begin = 18.0
            lamp.distance_fade_length = 10.0
            lamp.distance_fade_shadow = 16.0
            add_child(lamp)
            lamp.look_at(table.position + Vector3(0.0, 1.03, 0.0), Vector3.UP)
            _create_recessed_fixture(name, lamp.position)
        # Ensure the same rendered meshes that form the actual tables and
        # stools also cast light-dependent shadows on the PBR oak floor.
        for obj in table.get_children():
            if obj is MeshInstance3D:
                (obj as MeshInstance3D).cast_shadow = (
                    GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


func _create_recessed_fixture(light_name: String, light_pos: Vector3) -> void:
    var label := "Fixture_" + light_name
    if has_node(label):
        return
    # Thin recessed brass bezel, not a floating white lamp.
    var ring := MeshInstance3D.new()
    ring.name = label
    var ring_mesh := CylinderMesh.new()
    ring_mesh.top_radius = 0.135
    ring_mesh.bottom_radius = 0.135
    ring_mesh.height = 0.018
    ring_mesh.radial_segments = 16
    ring.mesh = ring_mesh
    ring.position = Vector3(light_pos.x, 5.936, light_pos.z)
    var ring_mat := StandardMaterial3D.new()
    ring_mat.albedo_color = Color("#654b34")
    ring_mat.metallic = 0.70
    ring_mat.roughness = 0.43
    ring.material_override = ring_mat
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ring)
    var diode := MeshInstance3D.new()
    diode.name = "Diode"
    var face := CylinderMesh.new()
    face.top_radius = 0.092
    face.bottom_radius = 0.092
    face.height = 0.01
    face.radial_segments = 16
    diode.mesh = face
    diode.position = Vector3(0, -0.013, 0)
    var glow := StandardMaterial3D.new()
    glow.albedo_color = Color("#c19b68")
    glow.emission_enabled = true
    glow.emission = Color("#ffdba6")
    glow.emission_energy_multiplier = 1.4
    diode.material_override = glow
    diode.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ring.add_child(diode)


func _ensure_neon_wall_washes() -> void:
    # Cove strips follow the two wings. Downward-directed spots produce
    # a warm gradient on wall panels and nearby floor, not broad ambient fill.
    # Their low cost and camera-distance fade preserve streaming performance.
    for z in [11.0, 5.0, -1.0, -7.0]:
        _wall_wash("East_%d" % int(z), Vector3(5.58, 5.34, z),
            Vector3(5.96, 3.45, z))
    for z in [11.0, 6.0, 1.0]:
        _wall_wash("Entry_%d" % int(z), Vector3(-5.58, 5.34, z),
            Vector3(-5.96, 3.45, z))
    for x in [-10.0, -16.0, -22.0, -28.0, -34.0, -40.0]:
        _wall_wash("North_%d" % int(x), Vector3(x, 5.34, -12.55),
            Vector3(x, 3.45, -12.96))
        _wall_wash("South_%d" % int(x), Vector3(x, 5.34, -0.48),
            Vector3(x, 3.45, -0.07))


func _wall_wash(label: String, origin: Vector3, target: Vector3) -> void:
    var node_name := "NeonWallWash_" + label
    if has_node(node_name):
        return
    var lamp := SpotLight3D.new()
    lamp.name = node_name
    lamp.position = origin
    lamp.light_color = Color("#ffce7d")
    lamp.light_energy = 0.66
    lamp.spot_range = 4.9
    lamp.spot_angle = 48.0
    lamp.spot_attenuation = 1.55
    lamp.light_specular = 0.62
    lamp.light_volumetric_fog_energy = 0.0
    lamp.shadow_enabled = false
    lamp.distance_fade_enabled = true
    lamp.distance_fade_begin = 19.0
    lamp.distance_fade_length = 9.0
    add_child(lamp)
    lamp.look_at(target, Vector3.UP)


func _ensure_neon_sign_spills() -> void:
    # Cyan sign bleeds onto the bottle wall; warm entrance sign projects
    # matching gold light. Neither introduces extra shadow-map passes.
    _neon_sign_light("BarSignSpill", Vector3(-2.33, 4.45, -11.94),
        CYAN, 0.70, 3.25)
    _neon_sign_light("EntrySignSpill", Vector3(0, 4.02, 13.32),
        GOLD, 0.55, 3.15)


func _neon_sign_light(label: String, at: Vector3, tint: Color,
        energy: float, reach: float) -> void:
    if has_node(label):
        return
    var lamp := OmniLight3D.new()
    lamp.name = label
    lamp.position = at
    lamp.light_color = tint
    lamp.light_energy = energy
    lamp.omni_range = reach
    lamp.omni_attenuation = 1.7
    lamp.light_specular = 0.7
    lamp.light_volumetric_fog_energy = 0.0
    lamp.shadow_enabled = false
    add_child(lamp)


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


func _ensure_bar_fill_lights() -> void:
    # The authored scene owns these two accents; only reconstruct missing
    # lights for legacy/editor-generated variants. Both are deliberately cheap.
    _ensure_bar_light("BarShelfFill", Vector3(-1.7, 2.85, -11.66),
        Color(1.0, 0.78, 0.55), 0.43, 3.9, 1.55, 0.55)
    _ensure_bar_light("BarCounterFill", Vector3(2.2, 2.2, -9.75),
        Color(1.0, 0.81, 0.61), 0.34, 4.1, 1.6, 0.5)


func _ensure_bar_light(label: String, location: Vector3, tint: Color,
        energy: float, reach: float, attenuation: float, specular: float) -> void:
    if has_node(label):
        return
    var lamp := OmniLight3D.new()
    lamp.name = label
    lamp.position = location
    lamp.light_color = tint
    lamp.light_energy = energy
    lamp.omni_range = reach
    lamp.omni_attenuation = attenuation
    lamp.light_specular = specular
    lamp.light_volumetric_fog_energy = 0.0
    lamp.shadow_enabled = false
    add_child(lamp)


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
            light.light_energy = 0.29
            light.omni_range = 2.60
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
        slot_spills[i].light_energy = 0.29 + (
            0.04 * sin(elapsed * 1.1 + float(i) * 1.44))
    for i in range(signs.size()):
        signs[i].emission_energy_multiplier = (
            (1.6 if i == 0 else 1.32) +
            0.08 * sin(elapsed * 0.58 + float(i)))
    for i in range(plant_crowns.size()):
        # Slow <1-degree sway, deliberately subtle for an indoor casino.
        plant_crowns[i].rotation.z = 0.009 * sin(elapsed * 0.47 + float(i) * 1.7)
        plant_crowns[i].rotation.x = 0.007 * sin(elapsed * 0.39 + float(i) * 2.1)

