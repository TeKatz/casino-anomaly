extends RefCounted
## Runtime-only joins around the saved Backrooms layout. No authored wall,
## fixture, transform, or baked resource is rewritten.
const MAZE = preload("res://backrooms/backrooms_labyrinth.tscn")
const WALL = preload("res://backrooms/materials/wall.tres")
const FLOOR = preload("res://backrooms/materials/floor.tres")
const CEILING = preload("res://backrooms/materials/ceiling.tres")
const ENTRY_X := -16.53125
const EXIT_X := 16.53125
const ENTRY_Z := 0.375
const EXIT_Z := 3.21875
const EXIT_LENGTH := 7.0
const RETURN_TURN_LENGTH := 7.0
const RETURN_BEND_X := EXIT_X + EXIT_LENGTH
const RETURN_SEAM_Z := EXIT_Z + RETURN_TURN_LENGTH
# The player capsule has cleared the entrance sleeve at this depth.
const RETURN_ENTRY_CLEARANCE := 0.75
# Finish the environment blend before the inner edge of the blind corner.
const LIGHT_BLEND_START := EXIT_X + 1.3
const LIGHT_BLEND_END := RETURN_BEND_X - 2.2
const OPENING_HALF := 0.64
const HALF_WIDTH := 1.22

static func entrance_transform(casino: Node3D, portals: RefCounted, lane: String) -> Transform3D:
    var direction: float = portals.lane_sign(lane)
    var basis := Basis(Vector3.UP, -direction * PI * 0.5)
    var seam := Vector3(portals.BEND_X, 0, portals.end_z(lane) + direction * 0.55)
    return casino.global_transform * Transform3D(basis, seam - basis * Vector3(ENTRY_X, 0, ENTRY_Z))

static func return_transform(maze: Node3D, casino_entry_z: float) -> Transform3D:
    # Casino local -Z points along maze +Z, and its west wing extends
    # away from the maze (+X). The first sightline is behind the L bend.
    var basis := Basis(Vector3.UP, PI)
    var seam := Vector3(RETURN_BEND_X, 0, RETURN_SEAM_Z)
    return maze.global_transform * Transform3D(basis, seam - basis * Vector3(0, 0, casino_entry_z))

static func box(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material, solid: bool = true) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.position = at
    var geometry := BoxMesh.new()
    geometry.size = size
    mesh.mesh = geometry
    mesh.material_override = mat
    parent.add_child(mesh)
    if solid:
        var body := StaticBody3D.new()
        body.name = label + "_Collision"
        body.position = at
        var shape := BoxShape3D.new()
        shape.size = size
        var collision := CollisionShape3D.new()
        collision.shape = shape
        body.add_child(collision)
        parent.add_child(body)

static func build_entrance(maze: Node3D) -> void:
    var collar := Node3D.new()
    collar.name = "EntranceJoin"
    maze.add_child(collar)
    # Meet the casino's existing connector where its walls stop for the
    # usual entry sleeve. Narrow only at the actual Backrooms threshold.
    for side in [-1.0, 1.0]:
        var suffix := "N" if side < 0 else "S"
        box(collar, "Return_" + suffix, Vector3(ENTRY_X - 0.68, 1.76, ENTRY_Z + side * 1.31),
            Vector3(1.0, 3.52, 0.18), WALL)
        box(collar, "Jamb_" + suffix, Vector3(ENTRY_X - 0.25, 1.5, ENTRY_Z + side * (HALF_WIDTH + OPENING_HALF) * 0.5),
            Vector3(0.20, 3.0, HALF_WIDTH - OPENING_HALF), WALL)
    box(collar, "Soffit", Vector3(ENTRY_X - 0.68, 3.25, ENTRY_Z), Vector3(1.22, 0.5, 2.62), CEILING)
    # The existing TurnFloor bridges the entrance. No extra coplanar
    # carpet threshold is needed; its end is fitted at reveal.

static func fit_entrance_floor(connector: Node3D, maze: Node3D, direction: float) -> void:
    var timber := connector.get_node_or_null("TurnFloor") as MeshInstance3D
    var body := connector.get_node_or_null("TurnFloor_Collision") as StaticBody3D
    var carpet := maze.get_node_or_null("Architecture/Floor/Mesh") as MeshInstance3D
    if timber == null or body == null or carpet == null:
        push_error("Backrooms entrance floor nodes missing")
        return
    var mesh := timber.mesh as BoxMesh
    var collision := body.get_node_or_null("Shape") as CollisionShape3D
    if mesh == null or collision == null or not collision.shape is BoxShape3D:
        push_error("Backrooms entrance floor must use a box mesh and collider")
        return
    # Use the actual editable carpet mesh edge, not a second hardcoded
    # threshold. Both lanes (and rotated halls) use the same local math.
    var edge := carpet.to_global(Vector3(carpet.get_aabb().position.x, 0.0, ENTRY_Z))
    var end_z := connector.to_local(edge).z
    var start_z := timber.position.z - direction * mesh.size.z * 0.5
    var length := (end_z - start_z) * direction
    if length <= 0.0:
        push_error("Invalid Backrooms entrance floor span")
        return
    var size := Vector3(mesh.size.x, mesh.size.y, length)
    timber.position.z = (start_z + end_z) * 0.5
    mesh.size = size
    body.position = timber.position
    (collision.shape as BoxShape3D).size = size

static func add_pickup_light(maze: Node3D, at: Vector3) -> void:
    # A weak local pool, not a player light. The first few steps must stay
    # navigable even on a fresh checkout without baked VoxelGI data.
    var light := OmniLight3D.new()
    light.name = "FlashlightPickupLight"
    light.position = Vector3(at.x, 2.45, at.z + 0.40)
    light.light_color = Color(0.87, 0.84, 0.68)
    light.light_energy = 0.16
    light.omni_range = 3.6
    light.omni_attenuation = 1.2
    light.shadow_enabled = true
    light.light_bake_mode = Light3D.BAKE_DISABLED
    maze.add_child(light)

static func build_exit(maze: Node3D) -> Node3D:
    var corridor := Node3D.new()
    corridor.name = "BackroomsExitConnector"
    maze.add_child(corridor)
    var start := EXIT_X + 0.20
    var bend := RETURN_BEND_X
    var seam := RETURN_SEAM_Z
    var inner_x := bend - HALF_WIDTH
    var outer_x := bend + HALF_WIDTH
    var inner_z := EXIT_Z + HALF_WIDTH
    var outer_z := EXIT_Z - HALF_WIDTH
    var wall_end_z := seam - 0.63
    # First leg stops at the inner edge; the turn floor covers the corner
    # and second leg. Top surfaces meet without coplanar overlap.
    box(corridor, "Floor", Vector3((start + inner_x) * 0.5, -0.125, EXIT_Z),
        Vector3(inner_x - start, 0.25, HALF_WIDTH * 2.0), FLOOR)
    box(corridor, "TurnFloor", Vector3(bend, -0.125, (outer_z + seam + 0.55) * 0.5),
        Vector3(HALF_WIDTH * 2.0, 0.25, seam + 0.55 - outer_z), FLOOR)
    box(corridor, "Ceiling", Vector3((start + inner_x) * 0.5, 3.60, EXIT_Z),
        Vector3(inner_x - start, 0.18, HALF_WIDTH * 2.0), CEILING)
    box(corridor, "TurnCeiling", Vector3(bend, 3.60, (outer_z + seam - 0.55) * 0.5),
        Vector3(HALF_WIDTH * 2.0, 0.18, seam - 0.55 - outer_z), CEILING)
    # The full-height outer corner blocks the view of the casino until
    # the player turns. The inner wall blocks diagonal lines of sight.
    box(corridor, "StraightOuterWall", Vector3((start + outer_x + 0.18) * 0.5, 1.76, outer_z - 0.09),
        Vector3(outer_x + 0.18 - start, 3.52, 0.18), WALL)
    box(corridor, "StraightInnerWall", Vector3((start + inner_x) * 0.5, 1.76, inner_z + 0.09),
        Vector3(inner_x - start, 3.52, 0.18), WALL)
    box(corridor, "TurnOuterWall", Vector3(outer_x + 0.09, 1.76, (outer_z + wall_end_z) * 0.5),
        Vector3(0.18, 3.52, wall_end_z - outer_z), WALL)
    box(corridor, "TurnInnerWall", Vector3(inner_x - 0.09, 1.76, (inner_z + wall_end_z) * 0.5),
        Vector3(0.18, 3.52, wall_end_z - inner_z), WALL)
    for side in [-1.0, 1.0]:
        var suffix := "N" if side < 0 else "S"
        box(corridor, "Jamb_" + suffix, Vector3(EXIT_X + 0.28, 1.5, EXIT_Z + side * (HALF_WIDTH + OPENING_HALF) * 0.5),
            Vector3(0.22, 3.0, HALF_WIDTH - OPENING_HALF), WALL)
    box(corridor, "Soffit", Vector3(EXIT_X + 0.25, 3.25, EXIT_Z), Vector3(0.50, 0.5, 2.62), CEILING)
    var light := OmniLight3D.new()
    light.name = "ReturnLight"
    light.position = Vector3(bend - 1.6, 2.7, EXIT_Z)
    light.light_color = Color(1.0, 0.85, 0.60)
    light.light_energy = 0.16
    light.omni_range = 3.0
    corridor.add_child(light)
    _add_exit_direction_sign(corridor, outer_x)
    var turn_light := OmniLight3D.new()
    turn_light.name = "CasinoApproachLight"
    turn_light.position = Vector3(bend, 2.7, seam - 2.2)
    turn_light.light_color = Color(1.0, 0.78, 0.51)
    turn_light.light_energy = 0.34
    turn_light.omni_range = 4.0
    corridor.add_child(turn_light)
    # The cap is removed only when the real next entrance is attached.
    box(corridor, "ReturnStandbyCap", Vector3(bend, 1.76, seam - 0.85), Vector3(2.62, 3.52, 0.22), WALL)
    return corridor

static func _add_exit_direction_sign(corridor: Node3D, wall_x: float) -> void:
    # Fixed on the end wall facing the maze, with the arrow pointing
    # along +Z (right when approaching the wall along +X).
    # It is not a billboard, HUD marker or extra collision surface.
    var board := StandardMaterial3D.new()
    board.albedo_color = Color(0.09, 0.12, 0.075)
    board.roughness = 0.9
    box(corridor, "ExitDirectionBoard", Vector3(wall_x - 0.018, 1.90, EXIT_Z),
        Vector3(0.028, 0.45, 1.55), board, false)
    var sign := Label3D.new()
    sign.name = "ExitDirectionSign"
    sign.position = Vector3(wall_x - 0.038, 1.90, EXIT_Z)
    sign.rotation.y = -PI * 0.5
    sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    sign.no_depth_test = false
    sign.shaded = false
    sign.modulate = Color(0.72, 0.79, 0.55)
    sign.font_size = 64
    sign.pixel_size = 0.005
    sign.outline_size = 0
    sign.text = "EXIT  →"
    corridor.add_child(sign)

static func crossed_return_entrance(local: Vector3) -> bool:
    # Once past the sleeve, the entire casino is valid, not just the
    # narrow centerline of the corridor. The maze is on the other side
    # of EXIT_X, and the one-way exit gate has already sealed it.
    return local.x > EXIT_X and local.z >= RETURN_SEAM_Z + RETURN_ENTRY_CLEARANCE

static func return_light_weight(local_x: float) -> float:
    return smoothstep(LIGHT_BLEND_START, LIGHT_BLEND_END, local_x)

## Only runtime copies are modified. Enable the destination fog/effects at
## zero influence and interpolate their strength rather than toggling them
## at the visible handoff. The final exact authored Environment is installed
## behind the bend, so unblendable modes never change in the visible casino.
static func blend_return_environment(source: Environment, target: Environment, working: Environment, weight: float) -> void:
    working.ambient_light_color = source.ambient_light_color.lerp(target.ambient_light_color, weight)
    working.ambient_light_energy = lerpf(source.ambient_light_energy, target.ambient_light_energy, weight)
    working.ambient_light_sky_contribution = lerpf(source.ambient_light_sky_contribution, target.ambient_light_sky_contribution, weight)
    working.background_color = source.background_color.lerp(target.background_color, weight)
    working.tonemap_exposure = lerpf(source.tonemap_exposure, target.tonemap_exposure, weight)
    working.fog_enabled = source.fog_enabled or target.fog_enabled
    working.fog_density = lerpf(source.fog_density if source.fog_enabled else 0.0, target.fog_density if target.fog_enabled else 0.0, weight)
    working.fog_light_color = source.fog_light_color.lerp(target.fog_light_color, weight)
    working.volumetric_fog_enabled = source.volumetric_fog_enabled or target.volumetric_fog_enabled
    working.volumetric_fog_density = lerpf(source.volumetric_fog_density if source.volumetric_fog_enabled else 0.0, target.volumetric_fog_density if target.volumetric_fog_enabled else 0.0, weight)
    working.volumetric_fog_albedo = source.volumetric_fog_albedo.lerp(target.volumetric_fog_albedo, weight)
    working.volumetric_fog_emission_energy = lerpf(source.volumetric_fog_emission_energy if source.volumetric_fog_enabled else 0.0, target.volumetric_fog_emission_energy if target.volumetric_fog_enabled else 0.0, weight)
    working.ssao_enabled = source.ssao_enabled or target.ssao_enabled
    working.ssao_intensity = lerpf(source.ssao_intensity if source.ssao_enabled else 0.0, target.ssao_intensity if target.ssao_enabled else 0.0, weight)
    working.ssil_enabled = source.ssil_enabled or target.ssil_enabled
    working.ssil_intensity = lerpf(source.ssil_intensity if source.ssil_enabled else 0.0, target.ssil_intensity if target.ssil_enabled else 0.0, weight)
    working.glow_enabled = source.glow_enabled or target.glow_enabled
    working.glow_intensity = lerpf(source.glow_intensity if source.glow_enabled else 0.0, target.glow_intensity if target.glow_enabled else 0.0, weight)
    working.adjustment_enabled = source.adjustment_enabled or target.adjustment_enabled
    working.adjustment_brightness = lerpf(source.adjustment_brightness if source.adjustment_enabled else 1.0, target.adjustment_brightness if target.adjustment_enabled else 1.0, weight)
    working.adjustment_contrast = lerpf(source.adjustment_contrast if source.adjustment_enabled else 1.0, target.adjustment_contrast if target.adjustment_enabled else 1.0, weight)
    working.adjustment_saturation = lerpf(source.adjustment_saturation if source.adjustment_enabled else 1.0, target.adjustment_saturation if target.adjustment_enabled else 1.0, weight)

static func open_return(corridor: Node3D) -> void:
    for name in ["ReturnStandbyCap", "ReturnStandbyCap_Collision"]:
        var node := corridor.get_node_or_null(name)
        if node != null:
            node.free()

static func seal_exit(corridor: Node3D) -> void:
    if not corridor.has_node("ExitGate"):
        box(corridor, "ExitGate", Vector3(EXIT_X + 0.45, 1.76, EXIT_Z), Vector3(0.20, 3.52, 2.62), WALL)
