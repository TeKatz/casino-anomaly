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

    # Do not confuse the artist's nested bottle instances with missing
    # furniture: each saved bottle remains a separate editable scene even
    # when it has another signature bottle as its scene-tree parent.
    for child in bar.find_children("Signature_*", "Node3D", true, false):
        if not child.name.begins_with("Signature_") or child.scene_file_path == "":
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
        var label := child.get_node_or_null("ConformalPaperLabel") as MeshInstance3D
        if shell == null or liquid == null or label == null:
            _fail("A signature bottle is missing its shell, liquid or surface-wrap label")
            return
        if not (shell.mesh is ArrayMesh) or not (liquid.mesh is ArrayMesh) \
                or not (label.mesh is ArrayMesh) or shell.get_aabb().size.z < 0.10:
            _fail("Bottle or its curved paper label is not real 3D geometry")
            return
        var label_mat := label.material_override as StandardMaterial3D
        if label_mat == null or label_mat.albedo_texture == null:
            _fail("Conformal bottle label has no printed texture")
            return
        # Author-edited bottles use pre-saved mesh resources instead of
        # regenerating shared templates during every room load. Every piece
        # must survive as a genuine child owned by the authored main scene.
        if shell.owner != world or liquid.owner != world or label.owner != world:
            _fail("Saved signature bottle geometry lost its editable scene ownership")
            return
        var uv: PackedVector2Array = label.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
        if uv.size() < 400:
            _fail("Bottle label is not a densely UV-unwrapped curved surface")
            return
        if label.get_aabb().end.z > shell.get_aabb().end.z + 0.006:
            _fail("Bottle label floats in front of the glass instead of touching it")
            return
        for obsolete in ["EmbossedMetalLabelFrame", "DieCutPaperLabel",
                "RaisedSignatureLettering", "SpiritType", "InnerGoldRule",
                "LowerGoldRule"]:
            if child.get_node_or_null(obsolete) != null:
                _fail("Detached 3D plaque survived on bottle: " + obsolete)
                return
        if cap == null and medallion == null and crown == null and wood == null:
            _fail("Bottle has no sculpted stopper or closure")
            return
    # The procedural fallback is still cached for any *new*, non-authored
    # bottles spawned at runtime. Check the cache separately from saved meshes,
    # whose individual artist overrides must remain independent.
    var template := load("res://models/signature_bar/montevale.tscn") as PackedScene
    if template == null:
        _fail("Runtime bottle design template missing")
        return
    var generated_a := template.instantiate() as Node3D
    var generated_b := template.instantiate() as Node3D
    root.add_child(generated_a)
    root.add_child(generated_b)
    var generated_shell_a := generated_a.get_node_or_null("HandCutGlassShell") as MeshInstance3D
    var generated_shell_b := generated_b.get_node_or_null("HandCutGlassShell") as MeshInstance3D
    var generated_label_a := generated_a.get_node_or_null("ConformalPaperLabel") as MeshInstance3D
    var generated_label_b := generated_b.get_node_or_null("ConformalPaperLabel") as MeshInstance3D
    if generated_shell_a == null or generated_shell_b == null \
            or generated_label_a == null or generated_label_b == null \
            or generated_shell_a.mesh != generated_shell_b.mesh \
            or generated_label_a.mesh != generated_label_b.mesh \
            or generated_label_a.material_override != generated_label_b.material_override:
        _fail("Newly generated runtime bottle instances no longer reuse cached geometry")
        return
    generated_a.queue_free()
    generated_b.queue_free()

    if signature_count < 6 or families.size() != 6:
        _fail("Bar must retain editable signature bottles from all six designs")
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
        # The hidden Sketchfab hero still has its original staging seat.
        # Visible reworked machines use the upholstered, collidable prefab.
        var stool_group := machine.get_node_or_null("PlayerStool") as Node3D
        if stool_group == null:
            _fail("Slot stool group missing")
            return
        if machine.has_meta("slot_cabinet_revision"):
            var stool := stool_group.get_node_or_null("GamingStool") as Node3D
            var stool_body := stool.get_node_or_null("StoolBody") as StaticBody3D if stool != null else null
            var stool_shape := stool_body.get_node_or_null("StoolCollision") as CollisionShape3D if stool_body != null else null
            if stool_shape == null or not (stool_shape.shape is CylinderShape3D):
                _fail("Finished slot stool lacks real collision geometry")
                return
            for new_part in ["BackCover", "CabinetContour_L", "CabinetContour_R",
                    "ReelInset", "MachineTitle", "Console_Collision", "CoinSlot"]:
                if machine.get_node_or_null(new_part) == null:
                    _fail("Reworked slot lost integrated cabinet detail: " + new_part)
                    return
        else:
            if stool_group.get_node_or_null("StoolSeat") == null:
                _fail("Legacy hidden slot stool missing")
                return
            for part in ["StoolSeat_Collision", "StoolStem_Collision", "StoolFoot_Collision"]:
                var physics: StaticBody3D = stool_group.get_node_or_null(part) as StaticBody3D
                if physics == null or physics.get_child_count() == 0:
                    _fail("Legacy slot stool has no physics: %s" % part)
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

    var source_models := 0
    for plant in decor.get_children():
        if not (plant is Node3D) or not plant.name.begins_with("Plant_"):
            continue
        var original := plant.get_node_or_null("GioraMonsteraOriginal") as Node3D
        if original == null or not original.is_visible_in_tree():
            _fail("Original Giora Monstera not visible on " + str(plant.name))
            return
        var meshes := original.find_children("*", "MeshInstance3D", true, false)
        if meshes.size() < 4:
            _fail("Imported Monstera must include original leaves, stalks, pot and stand")
            return
        if original.find_children("Leaves", "Node3D", true, false).is_empty():
            _fail("Imported Monstera lacks foliage node for ambient movement")
            return
        var suffix := str(plant.name).trim_prefix("Plant_")
        if plant.get_node_or_null("PlantPot_" + suffix) != null \
                or plant.get_node_or_null("PlantFoliage_" + suffix) != null:
            _fail("Old plant placeholder geometry still exists")
            return
        if plant.get_node_or_null("PlantPot_" + suffix + "_Collision") == null:
            _fail("Plant collision must remain under the movable anomaly root")
            return
        source_models += 1
    if source_models != 6:
        _fail("Expected all six fully modeled Monstera scene instances")
        return
    var animated: Array = atmosphere.get("plant_crowns")
    if animated.size() != 6:
        _fail("Subtle foliage animation is not connected")
        return

    world.queue_free()
    print("Casino Anomaly prop visuals and orientations QA PASS")
    quit(0)
