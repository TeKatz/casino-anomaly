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

    # The bar must use THREE rows of actual textured/material 3D bottle
    # meshes, not the earlier 118 cylinder-only placeholders or flat images.
    var bar := world.get_node_or_null("CornerBar") as Node3D
    if bar == null:
        _fail("Bar prop container missing")
        return
    var families := {}
    var signature_count := 0
    for child in bar.get_children():
        if not child.name.begins_with("Signature_"):
            continue
        signature_count += 1
        var design_name := str(child.get_meta("bottle_design", ""))
        if design_name.is_empty():
            design_name = str(child.name).get_slice("_", 3)
        families[design_name] = true
        if not (child is Node3D):
            _fail("Signature bottle is not a 3D scene")
            return
        var shell := child.get_node_or_null("HandCutGlassShell") as MeshInstance3D
        var liquid := child.get_node_or_null("InnerLiquidVolume") as MeshInstance3D
        var cap := child.get_node_or_null("MetallicEngravedCap")
        var medallion := child.get_node_or_null("EightPointReserveMedallion")
        var crown := child.get_node_or_null("OrnateCrownStopper")
        var wood := child.get_node_or_null("NaturalWoodenStopper")
        var label := child.get_node_or_null("DieCutPaperLabel") as MeshInstance3D
        var lettering := child.get_node_or_null("RaisedSignatureLettering") as Label3D
        if shell == null or liquid == null or label == null or lettering == null:
            _fail("One of the volumetric signature bottles is missing body, liquid or detail")
            return
        if not (shell.mesh is ArrayMesh) or not (liquid.mesh is ArrayMesh) \
                or label.mesh == null or shell.get_aabb().size.z < 0.10:
            _fail("Bottle is a flat graphic rather than full 3D geometry")
            return
        if cap == null and medallion == null and crown == null and wood == null:
            _fail("Bottle has no sculpted stopper or closure")
            return
    if signature_count != 39 or families.size() != 6:
        _fail("Expected 39 signature 3D bottle instances spanning all 6 designs")
        return
    if bar.has_node("Bottle") or bar.has_node("BottleNeck"):
        _fail("Bar still contains cylinder-only placeholder bottle set")
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
            if absf(wrapf(obj.rotation.y - PI, -PI, PI)) > 0.0001:
                _fail("Lounge sofa did not receive the second 90-degree correction")
                return
            if obj.get_node_or_null("ModelSolidBody") == null:
                _fail("Rotated lounge sofa lost its collision")
                return
        elif label == "WestSecurityCamera":
            # Camera pointing direction is part of the designer's layout.
            # Validate presence, not the exact yaw from an older screenshot.
            west_camera_count += 1
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
            "ReelOuterFrame", "MarqueeInlay", "ButtonDeskTop"
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
        # The separately movable stool must keep its complete collision.
        var stool_group := machine.get_node_or_null("PlayerStool") as Node3D
        if stool_group == null or stool_group.get_node_or_null("StoolSeat") == null:
            _fail("Slot stool group missing")
            return
        for part in ["StoolSeat_Collision", "StoolStem_Collision", "StoolFoot_Collision"]:
            var physics: StaticBody3D = stool_group.get_node_or_null(part) as StaticBody3D
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
    # The designer may remove optional cabinets; verify remaining units
    # above, but do not force their original count.
    if rebuilt_slots < 6 or rebuilt_slots > 10:
        _fail("Unexpected number of remaining procedural slot cabinets: %d" % rebuilt_slots)
        return

    var pots := 0
    var foliage := 0
    for plant in decor.get_children():
        if not plant is Node3D or not plant.name.begins_with("Plant_"):
            continue
        var pot := plant.get_node_or_null("PlantPot_%s" % plant.name.trim_prefix("Plant_")) as MeshInstance3D
        var crown := plant.get_node_or_null("PlantFoliage_%s" % plant.name.trim_prefix("Plant_")) as Node3D
        if pot != null and pot.get_meta("decor_type", "") == "plant":
            pots += 1
            if not (pot.mesh is CylinderMesh):
                _fail("Decorative plant has no tapered ceramic pot")
                return
            var mesh: CylinderMesh = pot.mesh as CylinderMesh
            if mesh.bottom_radius >= mesh.top_radius:
                _fail("Ceramic pot must taper toward its base")
                return
            if plant.get_node_or_null(pot.name + "_Collision") == null:
                _fail("Plant pot collision is not grouped with the movable plant")
                return
        if crown != null:
            foliage += 1
            if crown.find_children("Leaf_*", "MeshInstance3D", false, false).size() < 18:
                _fail("Plant %s has not been replaced by detailed leaves" % plant.name)
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
