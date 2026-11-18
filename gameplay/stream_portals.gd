extends RefCounted
## Runtime geometry for two physically separated L-shaped exit passages.
## The next hall remains out of sight behind a solid corner. All geometry,
## including one-way locking gates, exists only in the running game.

const EXIT_X := -46.18
const ENTRY_Z := 14.18
const EXIT_Z_LEFT := -3.70
const EXIT_Z_RIGHT := -9.65
const BEND_X := -52.0
const TURN_LENGTH := 8.6
const HALF_WIDTH := 1.22
const HALL_HEIGHT := 6.0
const GATE_X := -47.7
const GATE_HEIGHT := 3.54


func lane_z(lane: String) -> float:
    return EXIT_Z_LEFT if lane == "left" else EXIT_Z_RIGHT


func lane_sign(lane: String) -> float:
    return 1.0 if lane == "left" else -1.0


func end_z(lane: String) -> float:
    return lane_z(lane) + TURN_LENGTH * lane_sign(lane)


func get_connector(room: Node3D, lane: String) -> Node3D:
    return room.get_node_or_null(
        "StreamingPortals/Connector_Left" if lane == "left"         else "StreamingPortals/Connector_Right"
    ) as Node3D


func prepare_room(room: Node3D) -> bool:
    if room.has_node("StreamingPortals"):
        return true
    var architecture := room.get_node_or_null("Architecture") as Node3D
    if architecture == null:
        return false
    var far_wall := architecture.get_node_or_null("FarExitWall") as MeshInstance3D
    var entry_wall := architecture.get_node_or_null("EntryBackWall") as MeshInstance3D
    if far_wall == null or entry_wall == null:
        push_error("Room streaming needs the authored EXIT and entry walls")
        return false

    var generated := Node3D.new()
    generated.name = "StreamingPortals"
    room.add_child(generated)

    var wall_mat: Material = far_wall.material_override
    var entry_mat: Material = entry_wall.material_override
    var trim_mat: Material = wall_mat
    var floor_mat: Material = wall_mat
    var trim := architecture.get_node_or_null("ExitFrameTop") as MeshInstance3D
    var floor := architecture.get_node_or_null("OakWestWing") as MeshInstance3D
    if trim != null and trim.material_override != null:
        trim_mat = trim.material_override
    if floor != null and floor.get_active_material(0) != null:
        floor_mat = floor.get_active_material(0)

    # Open the two end-wall portals and the following room's entrance only
    # at runtime. The player's saved main.tscn is never modified.
    far_wall.visible = false
    _disable_collision(architecture.get_node_or_null("FarExitWall_Collision"))
    entry_wall.visible = false
    _disable_collision(architecture.get_node_or_null("EntryBackWall_Collision"))

    for node in architecture.get_children():
        if not node is MeshInstance3D:
            continue
        var part := node as MeshInstance3D
        # Remove the original decorative door panels but retain EXIT labels
        # and the gold surrounding frames.
        if absf(part.position.x + 45.94) < 0.15                 and absf(part.position.y - 1.62) < 0.2                 and (absf(part.position.z - EXIT_Z_LEFT) < 0.25                 or absf(part.position.z - EXIT_Z_RIGHT) < 0.25):
            part.visible = false
        if part.name == "EntryDoor":
            part.visible = false
        if absf(part.position.y - 1.02) < 0.15                 and absf(part.position.x + 45.99) < 0.10                 and absf(part.position.z + 6.5) < 0.20:
            part.visible = false
            _far_wood_panels(generated, part.material_override)
        if absf(part.position.y - 1.02) < 0.15                 and absf(part.position.z - 14.0) < 0.15                 and absf(part.position.x) < 0.20:
            part.visible = false
            _entry_wood_panels(generated, part.material_override)

    for span in [
        Vector2(-13.20, -10.77),
        Vector2(-8.53, -4.82),
        Vector2(-2.58, 0.20)
    ]:
        _box(generated, "ExitWallPier",
            Vector3(EXIT_X, 3.0, (span.x + span.y) * 0.5),
            Vector3(0.36, HALL_HEIGHT, span.y - span.x), wall_mat)
    for z in [EXIT_Z_LEFT, EXIT_Z_RIGHT]:
        var portal_id := "Left" if is_equal_approx(z, EXIT_Z_LEFT) else "Right"
        _box(generated, "ExitOverdoor_" + portal_id,
            Vector3(EXIT_X, 4.76, z),
            Vector3(0.36, 2.48, 2.24), wall_mat)

    for span in [Vector2(-6.20, -1.68), Vector2(1.68, 6.20)]:
        _box(generated, "EntryWallPier",
            Vector3((span.x + span.y) * 0.5, 3.0, ENTRY_Z),
            Vector3(span.y - span.x, HALL_HEIGHT, 0.36), entry_mat)
    _box(generated, "EntryOverdoor", Vector3(0, 4.76, ENTRY_Z),
        Vector3(3.36, 2.48, 0.36), entry_mat)

    # Solid corner walls hide everything beyond the bend from someone
    # looking straight through either of the casino EXIT signs.
    for lane in ["left", "right"]:
        _build_bent_connector(generated, lane, wall_mat, trim_mat, floor_mat)
    return true


func _build_bent_connector(parent: Node3D, lane: String,
        wall_mat: Material, trim_mat: Material, floor_mat: Material) -> void:
    var corridor := Node3D.new()
    corridor.name = "Connector_Left" if lane == "left" else "Connector_Right"
    parent.add_child(corridor)

    var start_z := lane_z(lane)
    var turn_dir := lane_sign(lane)
    var finish_z := end_z(lane)
    var inner_x := BEND_X + HALF_WIDTH
    var outer_x := BEND_X - HALF_WIDTH
    var opening_x := EXIT_X + 0.12
    var horizontal_length := opening_x - inner_x
    var horizontal_mid := (opening_x + inner_x) * 0.5

    # Straight first leg, ending flush at the corner's inner edge.
    _box(corridor, "StraightFloor",
        Vector3(horizontal_mid, -0.11, start_z),
        Vector3(horizontal_length, 0.22, HALF_WIDTH * 2.0), floor_mat)
    _box(corridor, "StraightCeiling",
        Vector3(horizontal_mid, 3.60, start_z),
        Vector3(horizontal_length, 0.18, HALF_WIDTH * 2.0), trim_mat)

    # Second leg turns LEFT (+Z) or RIGHT (-Z) and meets the next hall's
    # entrance at z=finish_z. The outer wall forms an opaque blind corner.
    var bottom_z := start_z - turn_dir * HALF_WIDTH
    var top_z := finish_z + turn_dir * 0.15
    var vertical_length := absf(top_z - bottom_z)
    var vertical_mid := (top_z + bottom_z) * 0.5
    _box(corridor, "TurnFloor",
        Vector3(BEND_X, -0.11, vertical_mid),
        Vector3(HALF_WIDTH * 2.0, 0.22, vertical_length), floor_mat)
    _box(corridor, "TurnCeiling",
        Vector3(BEND_X, 3.60, vertical_mid),
        Vector3(HALF_WIDTH * 2.0, 0.18, vertical_length), trim_mat)

    # Outer wall on the first leg continues all the way into the corner.
    _wall_along_x(corridor, "StraightOuterWall",
        start_z - turn_dir * HALF_WIDTH, opening_x, outer_x, wall_mat)
    # Inner wall must END at the bend, otherwise it blocks the turn.
    _wall_along_x(corridor, "StraightInnerWall",
        start_z + turn_dir * HALF_WIDTH, opening_x, inner_x, wall_mat)
    _wall_along_z(corridor, "TurnOuterWall",
        outer_x, bottom_z, top_z, wall_mat)
    _wall_along_z(corridor, "TurnInnerWall",
        inner_x, start_z + turn_dir * HALF_WIDTH, top_z, wall_mat)

    var light := OmniLight3D.new()
    light.name = "PassageLight"
    light.position = Vector3(BEND_X, 3.04, start_z + turn_dir * 1.4)
    light.light_color = Color(1.0, 0.78, 0.51)
    light.light_energy = 0.75
    light.omni_range = 7.0
    corridor.add_child(light)

    # A short side-facing light makes the corner leg readable without
    # revealing the next room while the player is still in the main hall.
    var second_light := OmniLight3D.new()
    second_light.name = "TurnLight"
    second_light.position = Vector3(BEND_X, 3.04,
        start_z + turn_dir * (TURN_LENGTH - 2.2))
    second_light.light_color = Color(1.0, 0.76, 0.48)
    second_light.light_energy = 0.58
    second_light.omni_range = 5.8
    corridor.add_child(second_light)


func lock_departure(room: Node3D, chosen_lane: String) -> bool:
    # Place both barriers BEHIND the committed player. They physically block
    # returning to the decision area or slipping through the other passage.
    var architecture := room.get_node_or_null("Architecture") as Node3D
    var source := architecture.get_node_or_null("FarExitWall") as MeshInstance3D         if architecture != null else null
    var material: Material = source.material_override if source != null else null
    for lane in ["left", "right"]:
        var connector := get_connector(room, lane)
        if connector == null:
            return false
        if not connector.has_node("OneWayGate"):
            _box(connector, "OneWayGate",
                Vector3(GATE_X, GATE_HEIGHT * 0.5, lane_z(lane)),
                Vector3(0.28, GATE_HEIGHT, HALF_WIDTH * 2.0 + 0.12),
                material)
    return chosen_lane == "left" or chosen_lane == "right"


func adopt_arrival_connector(old_room: Node3D, new_room: Node3D,
        chosen_lane: String) -> bool:
    var connector := get_connector(old_room, chosen_lane)
    if connector == null or not connector.has_node("OneWayGate_Collision"):
        return false
    # Keep the path behind the player even after deleting the old room:
    # without this, looking back through the new entrance reveals the void.
    connector.reparent(new_room, true)
    connector.name = "ArrivalConnector"
    return true


func _wall_along_x(parent: Node3D, name: String, z: float,
        x1: float, x2: float, material: Material) -> void:
    _box(parent, name, Vector3((x1 + x2) * 0.5, 1.76, z),
        Vector3(absf(x2 - x1), 3.52, 0.18), material)


func _wall_along_z(parent: Node3D, name: String, x: float,
        z1: float, z2: float, material: Material) -> void:
    _box(parent, name, Vector3(x, 1.76, (z1 + z2) * 0.5),
        Vector3(0.18, 3.52, absf(z2 - z1)), material)


func _disable_collision(collider: Node) -> void:
    if collider == null:
        return
    for child in collider.get_children():
        if child is CollisionShape3D:
            (child as CollisionShape3D).set_deferred("disabled", true)


func _far_wood_panels(parent: Node3D, mat: Material) -> void:
    for span in [
        Vector2(-13.0, -10.77),
        Vector2(-8.53, -4.82),
        Vector2(-2.58, 0.0)
    ]:
        _box(parent, "ExitWainscoting",
            Vector3(-45.99, 1.02, (span.x + span.y) * 0.5),
            Vector3(0.12, 2.0, span.y - span.x), mat, false)


func _entry_wood_panels(parent: Node3D, mat: Material) -> void:
    for span in [Vector2(-6.0, -1.68), Vector2(1.68, 6.0)]:
        _box(parent, "EntryWainscoting",
            Vector3((span.x + span.y) * 0.5, 1.02, 14.0),
            Vector3(span.y - span.x, 2.0, 0.12), mat, false)


func _box(parent: Node3D, label: String, center: Vector3,
        dimensions: Vector3, material: Material, collidable: bool = true) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.position = center
    var shape_mesh := BoxMesh.new()
    shape_mesh.size = dimensions
    mesh.mesh = shape_mesh
    if material != null:
        mesh.material_override = material
    parent.add_child(mesh)
    if not collidable:
        return
    var body := StaticBody3D.new()
    body.name = label + "_Collision"
    body.position = center
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = dimensions
    collision.shape = shape
    body.add_child(collision)
    parent.add_child(body)
