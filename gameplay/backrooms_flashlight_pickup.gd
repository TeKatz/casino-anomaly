extends Node3D
## A single physical flashlight in the first passage, no battery or forced HUD.
var prompt: Label3D
var taken := false

func _ready() -> void:
    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = Color(0.11, 0.12, 0.13)
    body_mat.metallic = 0.45
    body_mat.roughness = 0.55
    var lens_mat := StandardMaterial3D.new()
    lens_mat.albedo_color = Color(0.74, 0.79, 0.82)
    lens_mat.emission_enabled = true
    lens_mat.emission = Color(0.55, 0.63, 0.70)
    lens_mat.emission_energy_multiplier = 0.18
    _cylinder("Handle", 0.045, 0.045, 0.24, Vector3.ZERO, body_mat)
    _cylinder("Head", 0.075, 0.05, 0.10, Vector3(0.15, 0, 0), body_mat)
    _cylinder("Lens", 0.065, 0.065, 0.012, Vector3(0.207, 0, 0), lens_mat)
    prompt = Label3D.new()
    prompt.name = "PickupPrompt"
    prompt.position = Vector3(0, 0.30, 0)
    prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    prompt.font_size = 36
    prompt.pixel_size = 0.004
    prompt.outline_size = 6
    prompt.modulate = Color(0.85, 0.85, 0.78)
    prompt.visible = false
    add_child(prompt)

func _cylinder(label: String, top: float, bottom: float, length: float, at: Vector3, mat: Material) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.position = at
    mesh.rotation.z = -PI * 0.5
    var shape := CylinderMesh.new()
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
    var query := PhysicsRayQueryParameters3D.create(camera.global_position, global_position, 1, [player.get_rid()])
    return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func update_prompt(player: CharacterBody3D) -> void:
    if taken or prompt == null:
        return
    prompt.visible = can_pick_up(player)
    var settings := get_node_or_null("/root/GameSettings")
    prompt.text = "E  Taschenlampe aufnehmen" if settings != null and str(settings.get_option("language")) == "de" else "E  Pick up flashlight"

func collect(player: CharacterBody3D) -> bool:
    if not can_pick_up(player) or not bool(player.call("equip_backrooms_flashlight")):
        return false
    taken = true
    hide()
    return true
