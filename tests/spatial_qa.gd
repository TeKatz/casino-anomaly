extends SceneTree

# Regression checks for the seven issues reported after Development 0.1.0-dev.10.
# All checks inspect the actual instantiated Godot scene, not source strings.

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("Spatial QA failure: " + reason)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://gameplay/casino/main.tscn")
    if packed == null:
        _fail("Missing game scene")
        return
    var world: Node3D = packed.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    await process_frame

    var environment: WorldEnvironment = world.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if environment == null or environment.environment == null \
        or int(environment.environment.ambient_light_source) != 2:
        _fail("Ambient light is disabled; floors will be black")
        return

    var architecture: Node3D = world.get_node_or_null("Architecture") as Node3D
    var carpet: Node3D = world.get_node_or_null("RedCarpet") as Node3D
    var lounge: Node3D = world.get_node_or_null("Lounge") as Node3D
    var decor: Node3D = world.get_node_or_null("Decor") as Node3D
    var bar: Node3D = world.get_node_or_null("CornerBar") as Node3D
    var models: Node3D = world.get_node_or_null("ModelInteriors") as Node3D
    if architecture == null or carpet == null or lounge == null \
        or decor == null or bar == null or models == null:
        _fail("Required room section is missing")
        return

    # Procedural surfaces need to render from above under GL Compatibility.
    var oak: MeshInstance3D = architecture.get_node_or_null("OakMainWing") as MeshInstance3D
    var runner: MeshInstance3D = carpet.get_node_or_null("ApproachRunner") as MeshInstance3D
    for floor in [oak, runner]:
        if floor == null:
            _fail("A floor section is missing")
            return
        var material: StandardMaterial3D = floor.get_active_material(0) as StandardMaterial3D
        if material == null or int(material.cull_mode) != 2 or material.albedo_texture == null:
            _fail("Floor is one-sided or missing the original PBR texture: " + floor.name)
            return

    # Every decorative wall post has its own physical collision body.
    var pillar_count := 0
    var colliders := 0
    for child in architecture.get_children():
        if child is MeshInstance3D and child.get_meta("decor_type", "") == "pillar":
            pillar_count += 1
        if child is StaticBody3D and child.get_meta("collision_for", "") == "FlutedPillar":
            colliders += 1
            var collision: CollisionShape3D = child.get_child(0) as CollisionShape3D
            if collision == null or collision.shape == null:
                _fail("Pillar physics body missing a collision shape")
                return
    if pillar_count < 20 or colliders != pillar_count:
        _fail("Pillar collision coverage: %d meshes, %d bodies" % [pillar_count, colliders])
        return

    # The bar and its collision were moved away from the pillar near x=5.65.
    if bar.position.x > -0.90:
        _fail("Bar is still against the wall pillar")
        return

    # Old cylinder stools must not exist anywhere in CornerBar.
    for child in bar.get_children():
        for legacy in ["BarStoolSeat", "BarStoolStem", "SideBarStool", "SideStoolStem"]:
            if child.name.begins_with(legacy):
                _fail("Old bar stool overlaps imported bar stool")
                return

    var stools: Array[Node3D] = []
    var coffee: Node3D = null
    for node in models.get_children():
        var placement: String = str(node.get_meta("placement_group", ""))
        if placement == "CounterStool" or placement == "SideStool":
            stools.append(node as Node3D)
        elif placement == "CoffeeServiceCart":
            coffee = node as Node3D
    if stools.size() != 10:
        _fail("Expected 10 imported bar stools, got " + str(stools.size()))
        return
    for i in range(stools.size()):
        if stools[i].get_node_or_null("ModelSolidBody") == null:
            _fail("Imported bar stool missing collision")
            return
        for j in range(i + 1, stools.size()):
            var a := Vector2(stools[i].position.x, stools[i].position.z)
            var b := Vector2(stools[j].position.x, stools[j].position.z)
            if a.distance_to(b) < 1.05:
                _fail("Two bar stools overlap at bend: %s / %s" % [str(a), str(b)])
                return

    # The service cart belongs to a free wall bay, not a gaming chair.
    if coffee == null or coffee.position.distance_to(Vector3(-15.85, 0.005, -0.54)) > 0.08:
        _fail("Coffee cart is not centered in the free wall bay")
        return
    if coffee.get_node_or_null("ModelSolidBody") == null:
        _fail("Coffee cart lost its solid collision")
        return

    # This table is narrower to keep every seat off the red carpet and
    # away from the wainscoting. Check actual rotated/scaled seat footprints.
    var gaming: Node3D = world.get_node_or_null("GamingTables") as Node3D
    var side_cards: Node3D = gaming.get_node_or_null("Cards7") as Node3D
    if side_cards == null or side_cards.scale.x > 0.70 or side_cards.scale.z > 0.70:
        _fail("North-side game table still blocks the corridor")
        return
    var checked_seats := 0
    for seat in side_cards.get_children():
        if not (seat is Node3D) or not str(seat.name).begins_with("GamingStool_"):
            continue
        # The placeholder seat cylinders were replaced by editable stool
        # instances. Validate their ACTUAL collidable footprint, not the
        # deleted primitive mesh, against the original walkway limits.
        var body := seat.get_node_or_null("StoolBody") as StaticBody3D
        var collision := body.get_node_or_null("StoolCollision") as CollisionShape3D if body != null else null
        if collision == null or collision.disabled or not (collision.shape is CylinderShape3D):
            _fail("A north-side stool has no active collision")
            return
        var seat_radius: float = (collision.shape as CylinderShape3D).radius * side_cards.scale.z
        var absolute_z: float = side_cards.position.z + seat.position.z * side_cards.scale.z
        if absolute_z - seat_radius <= -3.48 or absolute_z + seat_radius >= -0.12:
            _fail("A north-side chair clips into the carpet or back wall")
            return
        checked_seats += 1
    if checked_seats != 5:
        _fail("Expected five safely placed chairs at the north-side table")
        return

    # No obsolete spherical emissive dots remain on any lounge coffee table.
    var sofa_positions: Array[Vector3] = []
    for child in lounge.get_children():
        if child is MeshInstance3D:
            _fail("Primitive whitebox lounge furniture is still present")
            return
    for child in models.get_children():
        if child.get_meta("placement_group", "") == "LoungeSofa":
            sofa_positions.append(child.position)
    if sofa_positions.size() != 5:
        _fail("Unexpected lounge seating layout")
        return

    # Genuine Monstera stands must not overlap lounge sofa seats.
    # Check the imported model's actual offset, not the legacy pot mesh.
    var monstera_count := 0
    for plant in decor.get_children():
        if not (plant is Node3D) or not plant.name.begins_with("Plant_"):
            continue
        var imported := plant.get_node_or_null("GioraMonsteraOriginal") as Node3D
        if imported == null:
            _fail("Original source plant is missing from " + str(plant.name))
            return
        monstera_count += 1
        var placement := imported.global_position
        for sofa_pos in sofa_positions:
            if absf(placement.x - sofa_pos.x) < 1.70 \
                    and absf(placement.z - sofa_pos.z) < 1.20:
                _fail("Real Monstera overlaps lounge sofa at " + str(sofa_pos))
                return
    if monstera_count != 6:
        _fail("Expected six real Monstera plants, not old topiary placeholders")
        return

    world.queue_free()
    print("Casino Anomaly spatial QA PASS: illuminated floors, 22+ solid pillars, bar clearance, 10 separated chairs, safe coffee cart, no orbs or plant collisions")
    root.get_node("AudioDirector").call("request_quit")
