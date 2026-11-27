extends RefCounted
const RuntimeCache = preload("res://gameplay/runtime_asset_cache.gd")
## Only actual opaque structural boxes are eligible. Never approximate a
## door opening, transparent surface, furniture, or the full room AABB.
static func add_box(mesh: MeshInstance3D) -> void:
    if mesh == null or not mesh.visible or not mesh.mesh is BoxMesh or mesh.has_node("StreamingOccluder"):
        return
    var size: Vector3 = (mesh.mesh as BoxMesh).size
    # Inset all faces to avoid falsely hiding geometry at seams.
    if minf(size.x, minf(size.y, size.z)) <= 0.04:
        return
    var shape := RuntimeCache.box_occluder(size - Vector3(0.04, 0.04, 0.04))
    var node := OccluderInstance3D.new()
    node.name = "StreamingOccluder"
    node.occluder = shape
    mesh.add_child(node)

static func casino_walls(room: Node3D) -> void:
    for label in ["RightMainWall", "NorthWestWall", "SouthWestWall", "LeftMainWall", "MainCeiling", "WestCeiling"]:
        add_box(room.get_node_or_null("Architecture/" + label) as MeshInstance3D)

static func maze_walls(maze: Node3D) -> void:
    var walls := maze.get_node_or_null("Architecture/Walls")
    if walls == null:
        return
    for body in walls.get_children():
        var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
        if mesh != null and mesh.mesh is BoxMesh:
            var size: Vector3 = (mesh.mesh as BoxMesh).size
            if maxf(size.x, size.z) >= 2.0:
                add_box(mesh)
