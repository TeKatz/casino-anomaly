extends SceneTree
## Authorable card tables must use fully modeled furniture and actual stool
## physics. Guard the player's original stool locations and the playing-card
## contact height when adjusting the visual detailing later.

const EXPECTED_STOOLS := [
    Vector2(0.31867263, 1.7512418),
    Vector2(1.7640052, 0.23808777),
    Vector2(0.7715425, -1.6040955),
    Vector2(-1.2871656, -1.2294732),
    Vector2(-1.5670546, 0.8442392)
]


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("Casino table furniture QA: " + message)
    quit(1)


func _run() -> void:
    var scene := load("res://gameplay/casino/main.tscn") as PackedScene
    if scene == null:
        _fail("Authored main scene missing")
        return
    var world := scene.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    await process_frame

    for table_name in ["Cards5", "Cards7"]:
        var group := world.get_node_or_null("GamingTables/" + table_name) as Node3D
        if group == null or not group.is_visible_in_tree():
            _fail("Visible authored card table missing: " + table_name)
            return
        var detail := group.get_node_or_null("DetailedTableSurface") as Node3D
        if detail == null:
            _fail("Missing high-detail authored tabletop: " + table_name)
            return
        for visual in ["TurnedWalnutTabletop", "RecessedWovenFelt",
                "OuterGildedEdge", "PaddedArmrest", "InsetBrassPiping"]:
            if detail.get_node_or_null(visual) == null:
                _fail("Missing finished table part: " + table_name + "/" + visual)
                return
        var felt := detail.get_node("RecessedWovenFelt") as MeshInstance3D
        var material := felt.material_override as StandardMaterial3D
        var legacy := group.get_node_or_null("FeltSurface") as MeshInstance3D
        if material == null or material.albedo_texture == null or material.normal_texture == null:
            _fail("Woven tabletop has no physical PBR fabric")
            return
        if legacy == null or legacy.visible or not (legacy.mesh is CylinderMesh)                 or not (felt.mesh is CylinderMesh):
            _fail("Original felt surface must remain an invisible collision/QA reference")
            return
        var old_top: float = legacy.position.y + (legacy.mesh as CylinderMesh).height * 0.5
        var new_top: float = felt.position.y + (felt.mesh as CylinderMesh).height * 0.5
        if absf(new_top - old_top) > 0.0001:
            _fail("Detailed felt height moved the original imported playing cards")
            return
        if not group.has_node("GoldTableRim_Collision"):
            _fail("Tabletop collision was lost")
            return
        for i in range(5):
            var stool := group.get_node_or_null("GamingStool_%02d" % (i + 1)) as Node3D
            var expected: Vector2 = EXPECTED_STOOLS[i]
            if stool == null or Vector2(stool.position.x, stool.position.z).distance_to(expected) > 0.0001                     or absf(stool.position.y) > 0.0001:
                _fail("Original stool position changed: %s/%d" % [table_name, i + 1])
                return
            for part_name in ["WeightedFoot", "TaperedPedestal", "FootrestRing",
                    "WalnutSeatShell", "UpholsteredSeat", "SoftSeatCrown"]:
                if stool.get_node_or_null(part_name) == null:
                    _fail("Stool lost finished 3D part: " + part_name)
                    return
            var body := stool.get_node_or_null("StoolBody") as StaticBody3D
            var collider := body.get_node_or_null("StoolCollision") as CollisionShape3D if body != null else null
            if body == null or collider == null or collider.disabled                     or not (collider.shape is CylinderShape3D) or body.collision_layer == 0:
                _fail("Visible gaming stool has no blocking physics: " + table_name)
                return
        if group.get_node_or_null("ChairSeat") != null or group.get_node_or_null("ChairLeg") != null:
            _fail("Old placeholder stool meshes survived")
            return

    world.queue_free()
    await process_frame
    print("Casino Anomaly authored table furniture QA PASS")
    quit(0)
