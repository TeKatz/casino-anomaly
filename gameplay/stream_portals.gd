extends RefCounted
const Loc = preload("res://gameplay/localization.gd")
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
    var wooden_frame: Material = wall_mat
    var wainscot := architecture.get_node_or_null("WoodWainscoting") as MeshInstance3D
    if wainscot != null and wainscot.material_override != null:
        wooden_frame = wainscot.material_override
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
        if node is Label3D:
            var sign := node as Label3D
            if sign.text == "EXIT":
                # Left = Anomalie (+Z), right = Normal (-Z).
                sign.text = Loc.t("world.anomaly", room) if absf(sign.position.z - EXIT_Z_LEFT) < 0.6 else Loc.t("world.normal", room)
            continue
        if not node is MeshInstance3D:
            continue
        var part := node as MeshInstance3D
        # Replace the original solid decorative panels AND the thin gold
        # placeholder strips with a single wooden 3-piece frame per opening.
        # The old strips were interpenetrating the new corridor wall faces,
        # causing the screenshot's heavily flickering doorway edges.
        if absf(part.position.x + 45.84) < 0.10 \
                and (absf(part.position.y - 1.7) < 0.16 \
                or absf(part.position.y - 3.35) < 0.16) \
                and part.position.z > -12.3 and part.position.z < -2.2:
            part.visible = false
        # The old gold rails on the other side of the stream seam are
        # placeholders too; the new, textured entrance frame replaces them.
        if absf(part.position.z - 13.8) < 0.15 \
                and absf(part.position.y - 1.7) < 0.2 \
                and absf(absf(part.position.x) - 1.64) < 0.16:
            part.visible = false
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
        _build_wood_exit_frame(generated, portal_id, z, wooden_frame)

    for span in [Vector2(-6.20, -1.68), Vector2(1.68, 6.20)]:
        _box(generated, "EntryWallPier",
            Vector3((span.x + span.y) * 0.5, 3.0, ENTRY_Z),
            Vector3(span.y - span.x, HALL_HEIGHT, 0.36), entry_mat)
    _box(generated, "EntryOverdoor", Vector3(0, 4.76, ENTRY_Z),
        Vector3(3.36, 2.48, 0.36), entry_mat)
    _build_entry_sleeve(generated, wooden_frame, floor_mat, trim_mat)

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
    # The connector ends behind the new wooden jambs, not inside their
    # visible front faces. Adjacent meshes no longer share coplanar faces.
    # Butt the connector walls against the OUTSIDE face of the existing
    # portal piers. Their former 10 cm penetration created overlapping
    # patterned wall surfaces on all four inner doorway edges.
    var opening_x := EXIT_X - 0.18
    var horizontal_length := opening_x - inner_x
    var horizontal_mid := (opening_x + inner_x) * 0.5

    # Bridge the full thickness of the original exit wall. The threshold
    # sits slightly below the authored floor so it cannot flicker.
    _box(corridor, "DoorwayFloor",
        Vector3(-46.13, -0.115, start_z),
        Vector3(0.46, 0.23, 2.22), floor_mat, false)

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
    # The entry sleeve starts 0.63 m outside the next room's entrance.
    # Stop wall faces BEFORE its front plane: no wall mesh overlaps the
    # sleeve's side returns, regardless of whether the hall is rotated.
    var wall_end_z := finish_z - turn_dir * 0.63
    # Floors instead extend UNDER the next room's oak floor, bridging the
    # entrance without coplanar polygons or gaps near the threshold.
    var floor_end_z := finish_z + turn_dir * 0.55
    var floor_mid_z := (floor_end_z + bottom_z) * 0.5
    var roof_end_z := finish_z - turn_dir * 0.55
    var roof_mid_z := (roof_end_z + bottom_z) * 0.5
    _box(corridor, "TurnFloor",
        Vector3(BEND_X, -0.115, floor_mid_z),
        Vector3(HALF_WIDTH * 2.0 + 0.18, 0.23, absf(floor_end_z - bottom_z)), floor_mat)
    _box(corridor, "TurnCeiling",
        Vector3(BEND_X, 3.60, roof_mid_z),
        Vector3(HALF_WIDTH * 2.0 + 0.18, 0.18, absf(roof_end_z - bottom_z)), trim_mat)

    # Keep the finished passage's inner faces flush with the sleeve's inner
    # opening (1.22 m); centered 0.09 m outside the nominal floor edges.
    var side_offset := HALF_WIDTH + 0.09
    _wall_along_x(corridor, "StraightOuterWall",
        start_z - turn_dir * side_offset, opening_x, outer_x - 0.09, wall_mat)
    _wall_along_x(corridor, "StraightInnerWall",
        start_z + turn_dir * side_offset, opening_x, inner_x + 0.09, wall_mat)
    _wall_along_z(corridor, "TurnOuterWall",
        outer_x - 0.09, bottom_z, wall_end_z, wall_mat)
    _wall_along_z(corridor, "TurnInnerWall",
        inner_x + 0.09, start_z + turn_dir * side_offset, wall_end_z, wall_mat)

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


func _build_wood_exit_frame(parent: Node3D, label: String,
        z: float, material: Material) -> void:
    var frame := Node3D.new()
    frame.name = "WoodExitFrame_" + label
    parent.add_child(frame)
    # Inboard of the front wall, yet clear of the corridor side-wall
    # termini; oak posts are a unified frame instead of floating trim.
    for side in [-1.0, 1.0]:
        var side_name := "South" if side < 0.0 else "North"
        _box(frame, "Jamb_" + side_name, Vector3(-45.88, 1.74, z + side * 1.13),
            Vector3(0.28, 3.48, 0.20), material, false)
    _box(frame, "Header", Vector3(-45.88, 3.50, z),
        Vector3(0.28, 0.22, 2.48), material, false)
    _box(frame, "Threshold", Vector3(-45.90, 0.04, z),
        Vector3(0.30, 0.07, 2.32), material, false)


func _build_entry_sleeve(parent: Node3D,
        material: Material, floor_mat: Material, ceiling_mat: Material) -> void:
    # The original entry opening is 3.36m wide, while the selected bend is
    # 2.44m wide. Both side gaps formerly opened directly onto the level void
    # after the old hall was deleted. These returns physically tie the
    # preserved arrival connector to the NEW hall's entrance at every angle.
    var collar := Node3D.new()
    collar.name = "EntrySleeve"
    parent.add_child(collar)
    for side in [-1.0, 1.0]:
        var side_name := "South" if side < 0.0 else "North"
        _box(collar, "SideReturn_" + side_name,
            Vector3(side * 1.45, 1.77, 14.32),
            Vector3(0.46, 3.54, 0.98), material)
        _box(collar, "SillWing_" + side_name,
            Vector3(side * 1.45, -0.08, 14.32),
            Vector3(0.47, 0.16, 1.00), floor_mat, false)
        _box(collar, "EntryJamb_" + side_name,
            Vector3(side * 1.67, 1.75, 13.96),
            Vector3(0.20, 3.50, 0.25), material, false)
    _box(collar, "RoofSoffit",
        Vector3(0.0, 3.54, 14.25),
        Vector3(3.34, 0.16, 0.96), ceiling_mat)
    _box(collar, "EntryHeader",
        Vector3(0.0, 3.53, 13.96),
        Vector3(3.48, 0.24, 0.25), material, false)



func seal_initial_entrance(room: Node3D) -> bool:
    # Only the very first hall has no predecessor. Later halls get a real
    # arrival connector instead; sealing those would block seamless travel.
    var generated := room.get_node_or_null("StreamingPortals") as Node3D
    var architecture := room.get_node_or_null("Architecture") as Node3D
    if generated == null or architecture == null:
        return false
    if generated.has_node("InitialEntryCap"):
        return true
    var cap := Node3D.new()
    cap.name = "InitialEntryCap"
    generated.add_child(cap)
    var old_door := architecture.get_node_or_null("EntryDoor") as MeshInstance3D
    var wainscot := architecture.get_node_or_null("WoodWainscoting") as MeshInstance3D
    var oak := architecture.get_node_or_null("OakMainWing") as MeshInstance3D
    var door_mat: Material = old_door.material_override if old_door != null else null
    var timber: Material = wainscot.material_override if wainscot != null else door_mat
    var floor_mat: Material = oak.get_active_material(0) if oak != null else timber

    # A real closed timber door replaces the exposed blank void. The leaf
    # sits inside the entrance collar, and is fully solid.
    _box(cap, "SolidDoor", Vector3(0, 1.77, 14.58),
        Vector3(2.44, 3.54, 0.17), door_mat)
    for side in [-1.0, 1.0]:
        _box(cap, "DoorStile", Vector3(side * 0.99, 1.76, 14.475),
            Vector3(0.14, 3.32, 0.065), timber, false)
        for height in [0.92, 2.45]:
            _box(cap, "InsetPanel", Vector3(side * 0.49, height, 14.474),
                Vector3(0.77, 1.20, 0.05), timber, false)
    for height in [0.18, 1.75, 3.37]:
        _box(cap, "DoorRail", Vector3(0, height, 14.47),
            Vector3(2.16, 0.14, 0.07), timber, false)
    _box(cap, "SolidSill", Vector3(0, -0.115, 14.28),
        Vector3(2.45, 0.23, 0.66), floor_mat, false)
    return true

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
    # Its retained walls, floor, ceiling and locked back end now meet the
    # new scene's permanent-in-runtime EntrySleeve; none of the old corridor
    # is lost when the previous casino root is freed.
    return new_room.has_node("StreamingPortals/EntrySleeve")


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
    collision.name = "Shape"
    var shape := BoxShape3D.new()
    shape.size = dimensions
    collision.shape = shape
    body.add_child(collision)
    parent.add_child(body)
