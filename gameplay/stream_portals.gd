extends RefCounted
## Runtime-only apertures and walkable connectors for the author's L-shaped hall.
## Do not save StreamingPortals to main.tscn. Every generated collider has
## the same transform as its visible mesh (no invisible obstructing walls).

const EXIT_X := -46.18
const ENTRY_Z := 14.18
const ENTRY_PORTAL_X := -54.50
const EXIT_Z_LEFT := -3.70
const EXIT_Z_RIGHT := -9.65
const EXIT_OPENING_HEIGHT := 3.52
const HALL_HEIGHT := 6.0
const CORRIDOR_WIDTH := 2.18


func prepare_room(room: Node3D) -> bool:
    if room.has_node("StreamingPortals"):
        return true
    var architecture := room.get_node_or_null("Architecture") as Node3D
    if architecture == null:
        return false
    var far_wall := architecture.get_node_or_null("FarExitWall") as MeshInstance3D
    var entry_wall := architecture.get_node_or_null("EntryBackWall") as MeshInstance3D
    if far_wall == null or entry_wall == null:
        push_error("Room streaming requires the existing far and entry walls")
        return false

    var generated := Node3D.new()
    generated.name = "StreamingPortals"
    room.add_child(generated)
    var wall_mat: Material = far_wall.material_override
    var entry_mat: Material = entry_wall.material_override
    var trim_mat: Material = null
    var floor_mat: Material = null
    var trim := architecture.get_node_or_null("ExitFrameTop") as MeshInstance3D
    var floor := architecture.get_node_or_null("OakWestWing") as MeshInstance3D
    if trim != null:
        trim_mat = trim.material_override
    if floor != null:
        floor_mat = floor.get_active_material(0)
    if trim_mat == null:
        trim_mat = wall_mat
    if floor_mat == null:
        floor_mat = wall_mat

    # The original designer's wall remains in main.tscn untouched. It is
    # replaced *only while a run is active* by segments around open portals.
    far_wall.visible = false
    _disable_collision(architecture.get_node_or_null("FarExitWall_Collision"))
    entry_wall.visible = false
    _disable_collision(architecture.get_node_or_null("EntryBackWall_Collision"))
    for node in architecture.get_children():
        if not node is MeshInstance3D:
            continue
        var part := node as MeshInstance3D
        # The originally decorative EXIT panels had no actual door opening.
        # Retain the gold frames and EXIT labels, but remove their panels.
        if absf(part.position.x + 45.94) < 0.15                 and absf(part.position.y - 1.62) < 0.2                 and (absf(part.position.z - EXIT_Z_LEFT) < 0.25                 or absf(part.position.z - EXIT_Z_RIGHT) < 0.25):
            part.visible = false
        if part.name == "EntryDoor":
            part.visible = false
        # The existing continuous wooden wall-panel band would still seal
        # both portals visually. Split it at the same apertures.
        if absf(part.position.y - 1.02) < 0.15                 and (absf(part.position.x + 45.99) < 0.10                 and absf(part.position.z + 6.5) < 0.20):
            part.visible = false
            _far_wood_panels(generated, part.material_override)
        if absf(part.position.y - 1.02) < 0.15                 and absf(part.position.z - 14.0) < 0.15                 and absf(part.position.x) < 0.20:
            part.visible = false
            _entry_wood_panels(generated, part.material_override)

    # Three solid end-wall piers, two overhead transoms: two genuine archways.
    for span in [
        Vector2(-13.20, -10.77),
        Vector2(-8.53, -4.82),
        Vector2(-2.58, 0.20)
    ]:
        _box(generated, "ExitWallPier", Vector3(EXIT_X, 3.0, (span.x + span.y) * 0.5),
            Vector3(0.36, HALL_HEIGHT, span.y - span.x), wall_mat)
    for z in [EXIT_Z_LEFT, EXIT_Z_RIGHT]:
        _box(generated, "ExitOverdoor", Vector3(EXIT_X, 4.76, z),
            Vector3(0.36, 2.48, 2.24), wall_mat)

    # Open the previously closed starting wall for the subsequent instance.
    # Existing entry gold trims continue to frame the actual opening.
    for span in [Vector2(-6.20, -1.68), Vector2(1.68, 6.20)]:
        _box(generated, "EntryWallPier", Vector3((span.x + span.y) * 0.5, 3.0, ENTRY_Z),
            Vector3(span.y - span.x, HALL_HEIGHT, 0.36), entry_mat)
    _box(generated, "EntryOverdoor", Vector3(0, 4.76, ENTRY_Z),
        Vector3(3.36, 2.48, 0.36), entry_mat)

    # Two separate *open* connector passages, no intermediate doors/fades.
    # At the far end the next hall's doorway aligns with the connector.
    for z in [EXIT_Z_LEFT, EXIT_Z_RIGHT]:
        var center_x := (EXIT_X + ENTRY_PORTAL_X) * 0.5
        var length := EXIT_X - ENTRY_PORTAL_X + 0.24
        _box(generated, "ConnectorFloor", Vector3(center_x, -0.11, z),
            Vector3(length, 0.22, CORRIDOR_WIDTH + 0.24), floor_mat)
        _box(generated, "ConnectorCeiling", Vector3(center_x, 3.64, z),
            Vector3(length, 0.18, CORRIDOR_WIDTH + 0.24), trim_mat)
        for side in [-1.0, 1.0]:
            _box(generated, "ConnectorWall", Vector3(center_x, 1.79, z + side * 1.21),
                Vector3(length, 3.58, 0.18), wall_mat)
        var lighting := OmniLight3D.new()
        lighting.name = "ConnectorWarmLight"
        lighting.position = Vector3(center_x, 3.04, z)
        lighting.light_color = Color(1.0, 0.78, 0.51)
        lighting.light_energy = 0.8
        lighting.omni_range = 6.8
        generated.add_child(lighting)

    return true


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
        _box(parent, "ExitWainscoting", Vector3(-45.99, 1.02, (span.x + span.y) * 0.5),
            Vector3(0.12, 2.0, span.y - span.x), mat, false)


func _entry_wood_panels(parent: Node3D, mat: Material) -> void:
    for span in [Vector2(-6.0, -1.68), Vector2(1.68, 6.0)]:
        _box(parent, "EntryWainscoting", Vector3((span.x + span.y) * 0.5, 1.02, 14.0),
            Vector3(span.y - span.x, 2.0, 0.12), mat, false)


func _box(parent: Node3D, label: String, center: Vector3,
        dimensions: Vector3, material: Material, collidable: bool = true) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.position = center
    var box := BoxMesh.new()
    box.size = dimensions
    mesh.mesh = box
    if material != null:
        mesh.material_override = material
    parent.add_child(mesh)
    if not collidable:
        return
    var body := StaticBody3D.new()
    body.name = label + "Collision"
    body.position = center
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = dimensions
    collision.shape = shape
    body.add_child(collision)
    parent.add_child(body)
