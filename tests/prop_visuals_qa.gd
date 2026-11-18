extends SceneTree

# Regression coverage for the showroom prop rework and lounge orientation.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("Casino props QA: " + message)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://main.tscn")
    if packed == null:
        _fail("Main casino scene is missing")
        return
    var world: Node3D = packed.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    await process_frame

    var models: Node3D = world.get_node_or_null("ModelInteriors") as Node3D
    var slots: Node3D = world.get_node_or_null("SlotMachines") as Node3D
    var decor: Node3D = world.get_node_or_null("Decor") as Node3D
    var atmosphere: Node3D = world.get_node_or_null("CasinoAtmosphere") as Node3D
    if models == null or slots == null or decor == null or atmosphere == null:
        _fail("Required visual prop section is missing")
        return

    var sofa_count := 0
    var west_camera_count := 0
    for item in models.get_children():
        if not (item is Node3D):
            continue
        var obj: Node3D = item as Node3D
        var label: String = str(obj.get_meta("placement_group", ""))
        if label == "LoungeSofa":
            sofa_count += 1
            if absf(obj.rotation.y - PI) > 0.0001:
                _fail("Lounge sofa did not receive the second 90-degree correction")
                return
            if obj.get_node_or_null("ModelSolidBody") == null:
                _fail("Rotated lounge sofa lost its collision")
                return
        elif label == "WestSecurityCamera":
            west_camera_count += 1
            if absf(obj.rotation.y - 1.25) > 0.0001:
                _fail("West security camera yaw does not match its mounted model axis")
                return
            # Lens of security_camera_01 points along local +Z, unlike
            # Camera3D's conventional -Z. Require an inward diagonal.
            var forward: Vector3 = obj.global_transform.basis.z
            if forward.dot(Vector3.RIGHT) < 0.92 or forward.dot(Vector3.BACK) < 0.20:
                _fail("West camera is not aimed diagonally into the hall")
                return
    if sofa_count != 5 or west_camera_count != 1:
        _fail("Expected five sofas and one west camera")
        return

    var rebuilt_slots := 0
    for child in slots.get_children():
        if not child.name.begins_with("Slot_"):
            continue
        var machine: Node3D = child as Node3D
        rebuilt_slots += 1
        for part in [
            "Body", "RoundedMarqueeTop", "TopGlow", "ReelGlass",
            "ReelOuterFrame", "MarqueeInlay", "ButtonDeskTop", "StoolSeat"
        ]:
            if machine.get_node_or_null(part) == null:
                _fail("Slot %s is missing %s" % [machine.name, part])
                return
        for i in range(3):
            if machine.get_node_or_null("ReelWell_%d" % i) == null:
                _fail("Slot %s is missing its three mechanical reel wells" % machine.name)
                return
        if machine.get_node_or_null("Body_Collision") == null:
            _fail("Slot %s lost its existing body collision" % machine.name)
            return
        # Seat, foot and stem are no longer only decorative.
        for part in ["StoolSeat_Collision", "StoolStem_Collision", "StoolFoot_Collision"]:
            var physics: StaticBody3D = machine.get_node_or_null(part) as StaticBody3D
            if physics == null or physics.get_child_count() == 0:
                _fail("Slot stool has no physics: %s" % part)
                return
        for reel in range(3):
            var glyph: Label3D = machine.get_node_or_null("ReelGlyph_%d" % reel) as Label3D
            if glyph == null or glyph.pixel_size > 0.003 or glyph.font_size > 35:
                _fail("A reel glyph can overrun its 0.20 m window")
                return
        var glow: MeshInstance3D = machine.get_node_or_null("TopGlow") as MeshInstance3D
        var material: StandardMaterial3D = glow.material_override as StandardMaterial3D
        if material == null or not material.emission_enabled:
            _fail("Slot marquee is missing animated emissive material")
            return
    # The detailed Sketchfab hero replaces one of the original ten slots.
    if rebuilt_slots != 9:
        _fail("Expected nine detailed procedural slots plus the imported hero, found %d" % rebuilt_slots)
        return

    var pots := 0
    var foliage := 0
    for child in decor.get_children():
        if child is MeshInstance3D and child.get_meta("decor_type", "") == "plant":
            pots += 1
            if not (child.mesh is CylinderMesh):
                _fail("Decorative plant has no tapered ceramic pot")
                return
            var mesh: CylinderMesh = child.mesh as CylinderMesh
            if mesh.bottom_radius >= mesh.top_radius:
                _fail("Ceramic pot must taper toward its base")
                return
        elif child is Node3D and child.name.begins_with("PlantFoliage_"):
            foliage += 1
            if child.find_children("Leaf_*", "MeshInstance3D", false, false).size() < 18:
                _fail("Plant %s has not been replaced by detailed leaves" % child.name)
                return
    if pots != 6 or foliage != 6:
        _fail("Expected six potted plants and six detailed foliage crowns")
        return
    var animated: Array = atmosphere.get("plant_crowns")
    if animated.size() != 6:
        _fail("Subtle foliage animation is not connected")
        return

    world.queue_free()
    print("Casino Anomaly prop visuals and orientations QA PASS")
    quit(0)
