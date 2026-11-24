extends Node3D
## Physical torch with proximity/LOS interaction and a screen-space hint.
## The hint does not depend on the camera facing direction or depth testing.
const Controls = preload("res://gameplay/input_bindings.gd")
var prompt: Label
var prompt_layer: CanvasLayer
var taken := false
var _near := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var rubber := _finish(Color(0.115, 0.12, 0.125), 0.05, 0.86, true)
    var alloy := _finish(Color(0.18, 0.19, 0.20), 0.72, 0.46, true)
    var trim := _finish(Color(0.095, 0.10, 0.105), 0.65, 0.52)
    var switch_mat := _finish(Color(0.26, 0.28, 0.25), 0.0, 0.82)
    var reflector := _finish(Color(0.60, 0.65, 0.67), 0.85, 0.28)
    var lens_mat := _finish(Color(0.33, 0.42, 0.46), 0.35, 0.18)
    lens_mat.emission_enabled = true
    lens_mat.emission = Color(0.22, 0.29, 0.32)
    lens_mat.emission_energy_multiplier = 0.06
    _cylinder("Handle", 0.043, 0.043, 0.24, Vector3(-0.025, 0, 0), rubber)
    for i in range(12):
        _cylinder("GripRing_%02d" % i, 0.046, 0.046, 0.007, Vector3(-0.112 + i * 0.014, 0, 0), trim)
    _cylinder("TailCap", 0.048, 0.048, 0.030, Vector3(-0.155, 0, 0), alloy)
    _cylinder("TailRim", 0.049, 0.049, 0.009, Vector3(-0.169, 0, 0), trim)
    _cylinder("Neck", 0.050, 0.043, 0.045, Vector3(0.105, 0, 0), alloy)
    _cylinder("Head", 0.070, 0.050, 0.085, Vector3(0.165, 0, 0), alloy)
    _cylinder("Bezel", 0.074, 0.074, 0.018, Vector3(0.213, 0, 0), trim)
    _cylinder("Reflector", 0.064, 0.064, 0.008, Vector3(0.224, 0, 0), reflector)
    _cylinder("Lens", 0.057, 0.057, 0.004, Vector3(0.229, 0, 0), lens_mat)
    var switch := MeshInstance3D.new()
    switch.name = "RubberSwitch"
    var button := SphereMesh.new()
    button.radius = 0.022
    button.height = 0.020
    switch.mesh = button
    switch.position = Vector3(0.065, 0.046, 0)
    switch.material_override = switch_mat
    add_child(switch)

    prompt_layer = CanvasLayer.new()
    prompt_layer.name = "PickupHUD"
    prompt_layer.layer = 3
    add_child(prompt_layer)
    var overlay := Control.new()
    overlay.name = "Overlay"
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    prompt_layer.add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    prompt = Label.new()
    prompt.name = "PickupPrompt"
    prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    prompt.add_theme_font_size_override("font_size", 22)
    prompt.add_theme_color_override("font_color", Color(0.9, 0.89, 0.83))
    prompt.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.95))
    prompt.add_theme_constant_override("outline_size", 6)
    overlay.add_child(prompt)
    prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    prompt.offset_top = -100.0
    prompt.offset_bottom = -60.0
    prompt.hide()

func _finish(color: Color, metallic: float, roughness: float, textured: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = roughness
    if textured:
        # Small deterministic surface grain for rubber and anodized metal.
        var noise := FastNoiseLite.new()
        noise.seed = 21
        noise.frequency = 0.23
        var ramp := Gradient.new()
        ramp.set_color(0, Color(0.53, 0.53, 0.53))
        ramp.set_color(1, Color(1.0, 1.0, 1.0))
        var grain := NoiseTexture2D.new()
        grain.width = 128
        grain.height = 128
        grain.seamless = true
        grain.noise = noise
        grain.color_ramp = ramp
        mat.albedo_texture = grain
        mat.uv1_scale = Vector3(3.0, 5.0, 1.0)
    return mat

func _cylinder(label: String, top: float, bottom: float, length: float, at: Vector3, mat: Material) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.position = at
    mesh.rotation.z = -PI * 0.5
    var shape := CylinderMesh.new()
    shape.radial_segments = 32
    shape.rings = 1
    shape.top_radius = top
    shape.bottom_radius = bottom
    shape.height = length
    mesh.mesh = shape
    mesh.material_override = mat
    add_child(mesh)

func can_pick_up(player: CharacterBody3D) -> bool:
    if taken or not is_instance_valid(player):
        return false
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    if camera == null or camera.global_position.distance_to(global_position) > 2.2:
        return false
    # Ray origin is camera position, NOT camera direction. Looking away
    # does not hide the hint; a real intervening wall still blocks pickup.
    var query := PhysicsRayQueryParameters3D.create(camera.global_position, global_position, 1, [player.get_rid()])
    return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func update_prompt(player: CharacterBody3D) -> void:
    if taken or prompt == null:
        return
    _near = can_pick_up(player)
    var settings := get_node_or_null("/root/GameSettings")
    prompt.text = Controls.hint(self) + ("  –  Taschenlampe aufnehmen" if settings != null and str(settings.get_option("language")) == "de" else "  –  Pick up flashlight")
    _sync_prompt()

func _process(_delta: float) -> void:
    _sync_prompt()

func _sync_prompt() -> void:
    if is_instance_valid(prompt):
        prompt.visible = _near and not taken and not get_tree().paused and bool(Controls.pref(self, "hud_visible", true)) and bool(Controls.pref(self, "interaction_hints", true))

func collect(player: CharacterBody3D) -> bool:
    if not can_pick_up(player) or not bool(player.call("equip_backrooms_flashlight")):
        return false
    taken = true
    _near = false
    _sync_prompt()
    hide()
    return true
