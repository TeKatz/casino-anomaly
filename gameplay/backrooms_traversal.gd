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
const OPENING_HALF := 0.64
const HALF_WIDTH := 1.22

static func entrance_transform(casino: Node3D, portals: RefCounted, lane: String) -> Transform3D:
    var direction: float = portals.lane_sign(lane)
    var basis := Basis(Vector3.UP, -direction * PI * 0.5)
    var seam := Vector3(portals.BEND_X, 0, portals.end_z(lane) + direction * 0.55)
    return casino.global_transform * Transform3D(basis, seam - basis * Vector3(ENTRY_X, 0, ENTRY_Z))

static func return_transform(maze: Node3D, casino_entry_z: float) -> Transform3D:
    var basis := Basis(Vector3.UP, -PI * 0.5)
    var seam := Vector3(EXIT_X + EXIT_LENGTH, 0, EXIT_Z)
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
            Vector3(1.22, 3.52, 0.18), WALL)
        box(collar, "Jamb_" + suffix, Vector3(ENTRY_X - 0.25, 1.5, ENTRY_Z + side * (HALF_WIDTH + OPENING_HALF) * 0.5),
            Vector3(0.20, 3.0, HALF_WIDTH - OPENING_HALF), WALL)
    box(collar, "Soffit", Vector3(ENTRY_X - 0.68, 3.25, ENTRY_Z), Vector3(1.22, 0.5, 2.62), CEILING)
    box(collar, "Threshold", Vector3(ENTRY_X - 0.5, -0.13, ENTRY_Z), Vector3(1.24, 0.24, 2.44), FLOOR)

static func build_exit(maze: Node3D) -> Node3D:
    var corridor := Node3D.new()
    corridor.name = "BackroomsExitConnector"
    maze.add_child(corridor)
    var end := EXIT_X + EXIT_LENGTH
    var wall_end := end - 0.63
    var start := EXIT_X + 0.18
    for side in [-1.0, 1.0]:
        var suffix := "N" if side < 0 else "S"
        box(corridor, "Wall_" + suffix, Vector3((start + wall_end) * 0.5, 1.76, EXIT_Z + side * 1.31),
            Vector3(wall_end - start, 3.52, 0.18), WALL)
        box(corridor, "Jamb_" + suffix, Vector3(EXIT_X + 0.28, 1.5, EXIT_Z + side * (HALF_WIDTH + OPENING_HALF) * 0.5),
            Vector3(0.22, 3.0, HALF_WIDTH - OPENING_HALF), WALL)
    box(corridor, "Floor", Vector3((EXIT_X + end + 0.55) * 0.5, -0.115, EXIT_Z),
        Vector3(EXIT_LENGTH + 0.55, 0.23, 2.44), FLOOR)
    box(corridor, "Ceiling", Vector3((start + wall_end) * 0.5, 3.60, EXIT_Z),
        Vector3(wall_end - start, 0.18, 2.62), CEILING)
    box(corridor, "Soffit", Vector3(EXIT_X + 0.25, 3.25, EXIT_Z), Vector3(0.50, 0.5, 2.62), CEILING)
    var light := OmniLight3D.new()
    light.name = "ReturnLight"
    light.position = Vector3(end - 2.2, 2.7, EXIT_Z)
    light.light_color = Color(1.0, 0.85, 0.60)
    light.light_energy = 0.35
    light.omni_range = 3.0
    corridor.add_child(light)
    return corridor

static func seal_exit(corridor: Node3D) -> void:
    if not corridor.has_node("ExitGate"):
        box(corridor, "ExitGate", Vector3(EXIT_X + 0.45, 1.76, EXIT_Z), Vector3(0.20, 3.52, 2.62), WALL)
