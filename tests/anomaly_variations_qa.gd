extends SceneTree
## Validate all new, understated anomalies against real casino nodes:
## registration, visibility, exact restoration, room isolation, and adapter.
const ROOM = preload("res://gameplay/casino/main.tscn")
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const Adapter = preload("res://gameplay/demo_anomalies.gd")
const StreamPortals = preload("res://gameplay/stream_portals.gd")

const NEW_IDS := [
    "stool_out_of_line",
    "plant_forward",
    "plant_forward__other",
    "crooked_painting",
    "candleholder_shifted",
    "bust_turned__reverse",
    "west_chandelier_dim",
    "cool_ceiling_light",
    "amber_ceiling_light",
    "horse_spotlight_off"
]


func _initialize() -> void:
    create_timer(240.0, true, false, true).timeout.connect(_on_watchdog)
    call_deferred("_run")

func _on_watchdog() -> void:
    _fail("QA watchdog expired")


func _fail(reason: String) -> void:
    push_error("Casino anomaly variations QA: " + reason)
    quit(1)


func _snapshot(node: Node) -> Dictionary:
    if node is Light3D:
        var light := node as Light3D
        return {
            "transform": light.transform,
            "color": light.light_color,
            "energy": light.light_energy,
            "visible": light.visible
        }
    if node is Node3D:
        return {"transform": (node as Node3D).transform}
    return {}


func _same(a: Dictionary, b: Dictionary) -> bool:
    if a.has("transform") != b.has("transform"):
        return false
    if a.has("transform") and not (a["transform"] as Transform3D).is_equal_approx(
            b["transform"] as Transform3D):
        return false
    if a.has("color") != b.has("color"):
        return false
    if a.has("color"):
        return (a["color"] as Color).is_equal_approx(b["color"] as Color) \
            and is_equal_approx(float(a["energy"]), float(b["energy"])) \
            and bool(a["visible"]) == bool(b["visible"])
    return true


func _verify_adjusted_definitions() -> bool:
    # These are explicit tuning requirements from visual review. Protect
    # against slipping back to clipped furniture or barely visible lighting.
    var expect := {
        "crooked_painting": {
            "target_path": "ModelInteriors/FramedPainting_02",
            "position_offset": Vector3(0.0, 0.22, 0.0),
            "rotation_degrees": Vector3(0.0, 0.0, 7.0)
        },
        "candleholder_shifted": {
            "target_path": "ModelInteriors/SingleBrassCandleholder_02",
            "position_offset": Vector3(0.26, 0.0, 0.12)
        },
        "west_chandelier_dim": {
            "target_path": "Lighting/WarmCasinoLamp_05"
        },
        "cool_ceiling_light": {
            "target_path": "ModelInteriors/ChandelierWarmLight_02",
            "energy_reference_path": "Lighting/WarmCasinoLamp_06",
            "light_anchor_path": "ModelInteriors/CeilingChandelier_01",
            "color": Color("#72bfff"),
            "energy_scale": 1.90,
            "difficulty": 2
        },
        "amber_ceiling_light": {
            "target_path": "Lighting/WarmCasinoLamp_03",
            "color": Color("#ff641e"),
            "energy_scale": 3.40
        },
        "horse_spotlight_off": {
            "color": Color("#ff7777"),
            "energy_scale": 5.60,
            "visible": true
        }
    }
    for id in expect:
        var entry: Dictionary = Catalog.get_entry(str(id))
        for key in expect[id]:
            if not entry.has(key) or entry[key] != expect[id][key]:
                _fail("Visual-review tuning regressed: %s / %s" % [id, key])
                return false
    return true


func _verify_cool_fixture_lights(room: Node3D) -> bool:
    # Preserve the accepted main effect and ensure the former variant's
    # fixture and both original room-fill lights remain untouched.
    var entry := Catalog.get_entry("cool_ceiling_light")
    var target := room.get_node_or_null(str(entry["target_path"])) as Light3D
    var reference := room.get_node_or_null(str(entry["energy_reference_path"])) as Light3D
    var fixture := room.get_node_or_null(str(entry["light_anchor_path"])) as Node3D
    var unrelated: Array[Light3D] = [
        room.get_node_or_null("ModelInteriors/ChandelierWarmLight_01/ChandelierWarmLight_01") as Light3D,
        room.get_node_or_null("Lighting/WarmCasinoLamp_03") as Light3D,
        reference
    ]
    if target == null or fixture == null or unrelated.has(null):
        _fail("Accepted cool fixture or reference lights are missing")
        return false
    var before := _snapshot(target)
    var unrelated_before: Array[Dictionary] = []
    for light in unrelated:
        unrelated_before.append(_snapshot(light))
    var adapter := Adapter.new()
    if not adapter.apply(room, str(entry["id"])):
        _fail("Accepted cool fixture unavailable")
        return false
    var offset := target.global_position - fixture.global_position
    if not offset.is_equal_approx(Vector3.UP * 0.12):
        _fail("Cool light is detached from its physical chandelier: " + str(offset))
        return false
    var original_transform: Transform3D = before["transform"]
    if not target.light_color.is_equal_approx(entry["color"]) or not is_equal_approx(target.light_energy, float(unrelated_before[2]["energy"]) * float(entry["energy_scale"])) or not target.transform.basis.is_equal_approx(original_transform.basis) or target.visible != before["visible"]:
        _fail("Cool fixture color, absolute energy, orientation or visibility regressed")
        return false
    for i in range(unrelated.size()):
        if not _same(unrelated_before[i], _snapshot(unrelated[i])):
            _fail("Cool fixture altered an unrelated room light")
            return false
    adapter.clear()
    if not _same(before, _snapshot(target)):
        _fail("Cool fixture light failed to restore its original state")
        return false
    return true


func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var suite := "all" if args.is_empty() else args[0]
    if suite not in ["all", "baseline", "flood", "other_side"]:
        _fail("Unknown QA suite: " + suite)
        return
    print("QA suite: ", suite)
    if not _verify_adjusted_definitions():
        return
    var room := ROOM.instantiate() as Node3D
    if room == null:
        _fail("Casino room cannot be instantiated")
        return
    root.add_child(room)
    await process_frame
    await process_frame
    await process_frame

    if suite not in ["all", "baseline"]:
        var isolated_room := ROOM.instantiate() as Node3D
        root.add_child(isolated_room)
        await process_frame
        await process_frame
        print("QA major event: ", suite)
        var passed := false
        match suite:
            "flood": passed = _verify_flood(room, isolated_room)
            "other_side": passed = _verify_other_side(room, isolated_room)
        if not passed:
            _fail("Major event suite failed: " + suite)
            return
        room.queue_free()
        isolated_room.queue_free()
        await process_frame
        print("Casino Anomaly major event QA PASS: ", suite)
        root.get_node("AudioDirector").call("request_quit")
        return

    if not _verify_cool_fixture_lights(room):
        return

    # The new group blackout must affect EVERY fixture light, including
    # nested imported-model lights, and restore each individual intensity.
    var blackout_entry := Catalog.get_entry("west_chandelier_dim")
    var blackout: RefCounted = blackout_entry["handler"].new()
    var chandelier_lights: Array = blackout.call("lights_for", room)
    if chandelier_lights.size() < 7:
        _fail("Chandelier anomaly missed one of the real authored lights")
        return
    var before: Array[Dictionary] = []
    for fixture in chandelier_lights:
        var light := fixture as Light3D
        before.append({"energy": light.light_energy, "visible": light.visible})
    var unrelated := room.get_node("Lighting/WarmCasinoLamp_06") as Light3D
    var unrelated_energy := unrelated.light_energy
    var unrelated_visible := unrelated.visible
    if not bool(blackout.call("apply", room, blackout_entry)):
        _fail("Could not disable chandelier group")
        return
    for fixture in chandelier_lights:
        var light := fixture as Light3D
        if not is_zero_approx(light.light_energy) or light.visible:
            _fail("At least one chandelier still shines during blackout")
            return
    if unrelated.light_energy != unrelated_energy or unrelated.visible != unrelated_visible:
        _fail("Chandelier blackout also disabled unrelated ceiling lighting")
        return
    blackout.call("clear")
    for i in range(chandelier_lights.size()):
        var light := chandelier_lights[i] as Light3D
        if not is_equal_approx(light.light_energy, float(before[i]["energy"]))                 or light.visible != bool(before[i]["visible"]):
            _fail("Chandelier blackout did not restore every original light")
            return

    var definitions: Array[Dictionary] = Catalog.entries()
    var available: Array[String] = Catalog.available_ids(room)
    if definitions.size() < 13 or available.size() < 13:
        _fail("The 13 baseline effects must remain registered and available; additional effects are allowed")
        return

    var retired := ["table_label","entrance_label__reverse","table_label__reverse","bust_turned","bust_turned__subtle","candleholder_shifted__other","crooked_painting__reverse","crooked_painting__subtle","plant_misplaced","plant_misplaced__subtle","stool_out_of_line__other","stool_out_of_line__subtle","breathing_wall","cool_ceiling_light__other"]
    for id in retired:
        if not Catalog.get_entry(id).is_empty() or available.has(id) or Adapter.new().apply(room, id):
            _fail("Retired anomaly still selectable: " + id)
            return
    if definitions.size() != 49:
        _fail("Catalog must contain exactly 49 active definitions after Phase 5 retirement")
        return
    if Catalog.discoverable_ids().has("table_label") or not Catalog.family_entries("table_label").is_empty() or not Catalog.review_hint("table_label",false).is_empty() or not Catalog.review_hint("table_label",true).is_empty():
        _fail("Retired Table Games family or localized hint is still active")
        return
    var expected_difficulty := {"amber_ceiling_light__soft":3,"bar_label":1,"bust_turned__reverse":2,"candleholder_shifted":4,"empty_reserve":1,"watchful_camera":2,"blank_reels":3,"empty_footsteps":3,"last_kings":4,"lightless_horse":1,"silent_countdown":1,"watching_canvases":1,"the_escort":1,"black_bloom":1,"they_are_listening":1,"wrong_reflection":1,"bar_label__reverse":5,"bar_label__subtle":3,"plant_forward__other":1,"false_jackpot":2,"floating_hand":2,"inverted_cat":2,"ownerless_shadow":2,"against_gravity":2,"extra_guest":1,"forgotten_door":1,"unfinished_game":3,"the_other_side":2}
    for id in expected_difficulty:
        if int(Catalog.get_entry(id).get("difficulty", 0)) != int(expected_difficulty[id]):
            _fail("Unexpected effective difficulty: " + id)
            return
    if Catalog.family("bust_turned__reverse") != "bust_turned" or not Catalog.discoverable_ids().has("bust_turned") or Catalog.family_entry("bust_turned").get("id") != "bust_turned__reverse" or Catalog.family_entries("bust_turned").size() != 1:
        _fail("Surviving bust variant lost its stable family")
        return

    var seen := {}
    for entry in definitions:
        var id := str(entry.get("id", ""))
        if id.is_empty() or seen.has(id):
            _fail("All anomalies need unique, nonempty IDs")
            return
        seen[id] = true
        if not entry.has("handler") or not entry.has("target_path") \
                or str(entry.get("title_de", "")).is_empty() \
                or str(entry.get("title_en", "")).is_empty() \
                or str(entry.get("description_de", "")).is_empty() \
                or str(entry.get("description_en", "")).is_empty():
            _fail("Incomplete catalog definition: " + id)
            return

    for id in NEW_IDS:
        print("QA anomaly: ", id)
        if not available.has(id):
            _fail("New anomaly is unavailable in the real casino room: " + id)
            return
        var entry := Catalog.get_entry(id)
        var target := room.get_node_or_null(str(entry["target_path"]))
        if target == null:
            _fail("Anomaly target is absent: " + id)
            return
        var handler: RefCounted = entry["handler"].new()
        if not bool(handler.call("can_apply", room, entry)):
            _fail("Anomaly declined its real casino target: " + id)
            return

        var baseline := _snapshot(target)
        if not bool(handler.call("apply", room, entry)):
            _fail("Anomaly could not be applied: " + id)
            return
        if _same(baseline, _snapshot(target)):
            _fail("Anomaly did not change its visible target: " + id)
            return
        handler.call("clear")
        if not _same(baseline, _snapshot(target)):
            _fail("Anomaly did not perfectly restore its target: " + id)
            return

        # The production adapter must also apply/clear the effect, not just
        # the handler unit API used above.
        var adapter := Adapter.new()
        if not adapter.apply(room, id) or _same(baseline, _snapshot(target)):
            _fail("Runtime anomaly adapter did not apply: " + id)
            return
        adapter.clear()
        if not _same(baseline, _snapshot(target)):
            _fail("Runtime adapter did not restore: " + id)
            return

    # One alteration never mutates a different streamed instance of the
    # same authored hall, including when lights are shared in resource data.
    var next_room := ROOM.instantiate() as Node3D
    root.add_child(next_room)
    await process_frame
    await process_frame
    var sample := Catalog.get_entry("plant_forward")
    var path := str(sample["target_path"])
    var original_next := _snapshot(next_room.get_node(path))
    var adapter := Adapter.new()
    if not adapter.apply(room, "plant_forward") \
            or not _same(original_next, _snapshot(next_room.get_node(path))):
        _fail("Anomaly leaked to another independent room")
        return
    adapter.clear()
    # The moved plant crosses the long runner while keeping its entire
    # imported plant and collider attached to the original root.
    var plant_entry := Catalog.get_entry("plant_forward__other")
    var plant := room.get_node(str(plant_entry["target_path"])) as Node3D
    var plant_model := plant.get_node_or_null("GioraMonsteraOriginal") as Node3D
    var plant_collision := plant.get_node_or_null("PlantPot_04_Collision") as Node3D
    var runner := room.get_node("RedCarpet/WestRunner") as MeshInstance3D
    if plant_model == null or plant_collision == null or runner == null:
        _fail("Plant variant lost its movable model, collider or runner reference")
        return
    var plant_start := plant.transform
    var collision_start := plant_collision.transform
    var model_start := plant_model.transform
    var runner_box: AABB = (room.global_transform.affine_inverse() * runner.global_transform) * runner.get_aabb()
    var plant_before := room.to_local(plant.global_position)
    if not adapter.apply(room, "plant_forward__other"):
        _fail("Cross-carpet plant variant unavailable")
        return
    var plant_after := room.to_local(plant.global_position)
    if plant_before.z <= runner_box.end.z or plant_after.z >= runner_box.position.z or plant_collision.transform != collision_start or plant_model.transform != model_start:
        _fail("Plant did not cross the carpet intact")
        return
    # Compare the actual pot collider with the authored table and stool
    # colliders. Both test rooms overlap in world space, so use room-local
    # shape bounds instead of a world physics query that sees both rooms.
    var inverse := room.global_transform.affine_inverse()
    for pot_part in plant_collision.find_children("*", "CollisionShape3D", true, false):
        var pot_shape := pot_part as CollisionShape3D
        if pot_shape.disabled or pot_shape.shape == null:
            continue
        var pot_bounds: AABB = (inverse * pot_shape.global_transform) * pot_shape.shape.get_debug_mesh().get_aabb()
        for obstacle_part in room.get_node("GamingTables").find_children("*", "CollisionShape3D", true, false):
            var obstacle := obstacle_part as CollisionShape3D
            if obstacle.disabled or obstacle.shape == null:
                continue
            var obstacle_bounds: AABB = (inverse * obstacle.global_transform) * obstacle.shape.get_debug_mesh().get_aabb()
            if pot_bounds.intersects(obstacle_bounds):
                _fail("Moved plant collider intersects a table or stool: " + str(obstacle.get_path()))
                return
    adapter.clear()
    if not plant.transform.is_equal_approx(plant_start):
        _fail("Cross-carpet plant failed to reset")
        return
    # Batch 01: ten independent family IDs, each available on the real
    # room and isolated from the next streamed instance.
    var batch_ids := ["blank_reels","false_jackpot","dark_marquee","watchful_camera","floating_hand","missing_hand","burgundy_felt","blue_runner","empty_reserve","bare_monstera"]
    for id in batch_ids:
        print("QA anomaly: ", id)
        var entry := Catalog.get_entry(id)
        if entry.is_empty() or Catalog.family(id) != id or not available.has(id):
            _fail("Batch 01 family missing or unavailable: " + id)
            return
        var handler: RefCounted = entry["handler"].new()
        var nodes: Array[Node3D] = handler.call("targets", room, entry)
        var other_nodes: Array[Node3D] = handler.call("targets", next_room, entry)
        var expected_counts := {"blank_reels": 3, "false_jackpot": 5, "dark_marquee": 6, "watchful_camera": 2, "floating_hand": 4, "missing_hand": 8, "burgundy_felt": 1, "blue_runner": 3}
        if nodes.is_empty() or other_nodes.size() != nodes.size() or (expected_counts.has(id) and nodes.size() != int(expected_counts[id])):
            _fail("Batch 01 target mismatch: " + id)
            return
        var baseline: Array = handler.call("snapshot", nodes, id)
        var other_baseline: Array = handler.call("snapshot", other_nodes, id)
        var original_bottle_parts: Dictionary = {}
        var bottle_label_count := 0
        if id == "empty_reserve":
            for bottle in room.get_node("CornerBar").find_children("Signature_*", "Node3D", true, false):
                if bottle.scene_file_path.is_empty():
                    continue
                var paper_label := bottle.get_node_or_null("ConformalPaperLabel") as MeshInstance3D
                if paper_label == null or not paper_label.is_visible_in_tree() or not nodes.has(paper_label):
                    _fail("Missing-label anomaly does not target every visible signature label")
                    return
                bottle_label_count += 1
                for part_name in ["HandCutGlassShell", "InnerLiquidVolume", "MetallicEngravedCap", "EightPointReserveMedallion", "OrnateCrownStopper", "NaturalWoodenStopper"]:
                    var bottle_part := bottle.get_node_or_null(part_name) as Node3D
                    if bottle_part != null:
                        original_bottle_parts[bottle_part] = bottle_part.visible
            if bottle_label_count < 6 or nodes.size() != bottle_label_count:
                _fail("Missing-label anomaly has incomplete or duplicate label targets")
                return
        if not adapter.apply(room, id):
            _fail("Batch 01 adapter refused " + id)
            return
        if id == "false_jackpot":
            var title := nodes[0] as Label3D
            var glow := (nodes[1] as MeshInstance3D).material_override as StandardMaterial3D
            if title.text != "JACKPOT" or glow == null or not glow.emission_enabled:
                _fail("Jackpot title or glow changed")
                return
            for reel_index in range(2, 5):
                var glyph := nodes[reel_index] as Label3D
                if glyph.text != "7" or glyph.font_size != 35 or glyph.modulate != baseline[reel_index]["modulate"]:
                    _fail("Jackpot reels must show three matching sevens without changing glyph color")
                    return
        if id == "floating_hand":
            # The complete horizontal mesh envelopes never overlap. The
            # unchanged bob animation only changes vertical position.
            for i in range(nodes.size()):
                var card_bounds: AABB = handler.call("_card_bounds_in_table", nodes[i])
                for j in range(i + 1, nodes.size()):
                    var other_bounds: AABB = handler.call("_card_bounds_in_table", nodes[j])
                    if card_bounds.end.x + 0.0001 >= other_bounds.position.x:
                        _fail("Floating card horizontal envelopes intersect")
                        return
        if id == "burgundy_felt" or id == "blue_runner":
            for node in nodes:
                var mesh := node as MeshInstance3D
                var mat := mesh.get_active_material(0) as StandardMaterial3D
                if not mesh.is_visible_in_tree() or mat == null or not mat.emission_enabled or mat.emission != mat.albedo_color:
                    _fail("Batch 01 did not recolor the actual visible surface: " + id)
                    return
        if id == "empty_reserve":
            for paper_label_node in nodes:
                if paper_label_node.visible:
                    _fail("A signature bottle still has its paper label")
                    return
            for bottle_part_node in original_bottle_parts:
                if bottle_part_node.visible != original_bottle_parts[bottle_part_node]:
                    _fail("Missing-label anomaly changed bottle glass, liquid or hardware")
                    return
        if id == "watchful_camera":
            for node in nodes:
                if not node.has_node("AnomalyRecordingLED"):
                    _fail("Camera recording LED missing")
                    return
        if id == "bare_monstera":
            for name in ["Plant_03", "Plant_04", "Plant_05"]:
                var reviewed_plant := room.get_node("Decor/" + name + "/GioraMonsteraOriginal")
                for leaf in reviewed_plant.find_children("Leaves", "Node3D", true, false):
                    if (leaf as Node3D).visible:
                        _fail("Plant leaves remained visible: " + name)
                        return
        if handler.call("snapshot", nodes, id) == baseline:
            _fail("Batch 01 did not change the target: " + id)
            return
        if handler.call("snapshot", other_nodes, id) != other_baseline:
            _fail("Batch 01 leaked to another room: " + id)
            return
        adapter.clear()
        if handler.call("snapshot", nodes, id) != baseline:
            _fail("Batch 01 did not restore the baseline: " + id)
            return
    if not (await _verify_horror_batch(room, next_room)):
        return
    if not (await _verify_reality_batch(room, next_room)):
        return
    if suite == "all":
        print("QA major event: flood")
        if not _verify_flood(room,next_room):
            return
        print("QA major event: other_side")
        if not _verify_other_side(room,next_room):
            return
    room.queue_free()
    next_room.queue_free()
    await process_frame
    print("Casino Anomaly ten subtle anomalies QA PASS")
    root.get_node("AudioDirector").call("request_quit")


func _verify_horror_batch(hall: Node3D, other_hall: Node3D) -> bool:
    var horror_ids := ["synchronized_busts","inverted_cat","lightless_horse","watching_canvases","stay_here","last_kings","ownerless_shadow","empty_footsteps","crimson_hall","silent_countdown"]
    var horror_adapter := Adapter.new()
    var horror_counts := {"synchronized_busts": 2, "inverted_cat": 3, "watching_canvases": 3, "stay_here": 3, "ownerless_shadow": 1, "empty_footsteps": 1}
    var available_horror := Catalog.available_ids(hall)
    for horror_id in horror_ids:
        print("QA anomaly: ", horror_id)
        var horror_entry := Catalog.get_entry(horror_id)
        if horror_entry.is_empty() or Catalog.family(horror_id) != horror_id or not available_horror.has(horror_id):
            _fail("Pack 02 family unavailable: " + horror_id)
            return false
        var inspector: RefCounted = horror_entry["handler"].new()
        var affected: Array[Node3D] = inspector.call("targets", hall, horror_entry)
        var unaffected: Array[Node3D] = inspector.call("targets", other_hall, horror_entry)
        if affected.is_empty() or unaffected.size() != affected.size() or (horror_counts.has(horror_id) and affected.size() != int(horror_counts[horror_id])):
            _fail("Pack 02 incomplete targets: " + horror_id)
            return false
        var initial: Array = inspector.call("snapshot", affected, horror_id)
        var isolated: Array = inspector.call("snapshot", unaffected, horror_id)
        if not horror_adapter.apply(hall, horror_id):
            _fail("Pack 02 failed to apply: " + horror_id)
            return false
        if inspector.call("snapshot", affected, horror_id) == initial or inspector.call("snapshot", unaffected, horror_id) != isolated:
            _fail("Pack 02 ineffective or leaked between rooms: " + horror_id)
            return false
        if horror_id == "inverted_cat":
            var horse_plinth := hall.get_node("ModelInteriors/DecorativeStatuePlinth_02") as CollisionObject3D
            var cat_plinth := hall.get_node("ModelInteriors/DecorativeStatuePlinth_01") as Node3D
            if not affected.has(horse_plinth) or affected.has(cat_plinth) or horse_plinth.collision_layer != 0 or horse_plinth.collision_mask != 0 or not cat_plinth.visible:
                _fail("Vanished guardians hid the wrong pedestal or left invisible collision")
                return false
            for hidden in affected:
                if hidden.visible:
                    _fail("Vanished guardians left one target visible")
                    return false
        if horror_id == "ownerless_shadow":
            var shadow_group := affected[0].get_node_or_null("AnomalyHorrorMark")
            if shadow_group == null:
                _fail("Projected human shadow missing")
                return false
            var shadow_capture := shadow_group.get_node_or_null("SilhouetteCapture") as SubViewport
            var shadow_plane := shadow_group.get_node_or_null("ShadowProjection") as MeshInstance3D
            if shadow_capture == null or not shadow_capture.own_world_3d or not shadow_capture.transparent_bg or shadow_plane == null or not shadow_plane.material_override is ShaderMaterial:
                _fail("Shadow is not rendered from an isolated model projection")
                return false
            var poses := shadow_capture.find_children("ShadowPose", "Node3D", true, false)
            if poses.is_empty():
                _fail("Shadow capture missing human model")
                return false
            var figure := poses[0] as Node3D
            if not is_equal_approx(figure.scale.x,figure.scale.y) or not is_equal_approx(figure.scale.y,figure.scale.z):
                _fail("Shadow human proportions are distorted")
                return false
            var projection_mesh := shadow_plane.mesh as PlaneMesh
            if projection_mesh == null or projection_mesh.size.x >= 2.1 or projection_mesh.size.y <= projection_mesh.size.x:
                _fail("Shadow projection does not preserve the narrow elongated light-space footprint")
                return false
        if horror_id == "empty_footsteps":
            var mark_group := affected[0].get_node_or_null("AnomalyHorrorMark")
            if mark_group == null or mark_group.get_child_count() != 28:
                _fail("Pack 02 missing floor marks: " + horror_id)
                return false
            for mark_mesh in mark_group.get_children():
                if not mark_mesh is MeshInstance3D or mark_mesh.material_override.albedo_texture == null:
                    _fail("Pack 02 floor mark missing generated texture")
                    return false
            var first_foot := mark_group.get_child(0) as Node3D
            var next_foot := mark_group.get_child(1) as Node3D
            var travel := (next_foot.position - first_foot.position).normalized()
            var toes := (first_foot.basis * Vector3.FORWARD).normalized()
            if toes.dot(travel) < 0.8:
                _fail("Footprint toes point against the travel direction")
                return false
        if horror_id == "synchronized_busts":
            for n in range(affected.size()):
                var pivot: Vector3 = inspector.call("_bust_pivot", affected[n])
                var original: Transform3D = initial[n]["transform"]
                if not (original * pivot).is_equal_approx(affected[n].transform * pivot):
                    _fail("Bust moved away from its physical pivot")
                    return false
        if horror_id == "silent_countdown":
            var tick_node := affected[floori(float(affected.size()) * 0.5)].get_node_or_null("AnomalyCountdownTick") as AudioStreamPlayer3D
            if tick_node == null or not tick_node.stream is AudioStreamWAV or tick_node.volume_db > -9.0 or tick_node.volume_db < -12.0 or tick_node.max_distance < 20.0 or tick_node.bus != "HORROR":
                _fail("Countdown tick missing or level/range regressed")
                return false
            # Verify the real timer invokes playback, not merely the node.
            await create_timer(1.15).timeout
            if int(tick_node.get_meta("tick_count", 0)) < 1 or (affected[0] as Label3D).text == "01:00":
                _fail("Countdown timer did not trigger tick playback")
                return false
        if horror_id == "empty_footsteps":
            var foot_group := affected[0].get_node("AnomalyHorrorMark")
            var first_mat := (foot_group.get_child(0) as MeshInstance3D).material_override
            var last_mat := (foot_group.get_child(27) as MeshInstance3D).material_override
            if first_mat == last_mat:
                _fail("Footprints share alpha material")
                return false
        horror_adapter.clear()
        if horror_id == "silent_countdown" and affected[floori(float(affected.size()) * 0.5)].has_node("AnomalyCountdownTick"):
            _fail("Countdown tick leaked after clear")
            return false
        if inspector.call("snapshot", affected, horror_id) != initial:
            _fail("Pack 02 failed to restore: " + horror_id)
            return false
    return true


func _verify_reality_batch(hall: Node3D, other_hall: Node3D) -> bool:
    var reality_ids := ["unfinished_game","invisible_dealer","forgotten_door","against_gravity","pendulum","black_bloom","extra_guest","wrong_reflection","they_are_listening"]
    var reality_adapter := Adapter.new()
    var reality_available := Catalog.available_ids(hall)
    for reality_id in reality_ids:
        print("QA anomaly: ", reality_id)
        var reality_entry := Catalog.get_entry(reality_id)
        if reality_entry.is_empty() or Catalog.family(reality_id) != reality_id or not reality_available.has(reality_id):
            _fail("Pack 03 unavailable: " + reality_id)
            return false
        var reality_probe: RefCounted = reality_entry["handler"].new()
        var reality_nodes: Array[Node3D] = reality_probe.call("targets", hall, reality_entry)
        var reality_other: Array[Node3D] = reality_probe.call("targets", other_hall, reality_entry)
        if reality_nodes.is_empty() or reality_other.size() != reality_nodes.size():
            _fail("Pack 03 target mismatch: " + reality_id)
            return false
        var reality_before: Array = reality_probe.call("snapshot", reality_nodes, reality_id)
        var reality_isolated: Array = reality_probe.call("snapshot", reality_other, reality_id)
        var reality_wall := hall.get_node("Architecture/SouthWestWall") as MeshInstance3D
        var reality_wall_layers := reality_wall.layers
        if not reality_adapter.apply(hall, reality_id):
            _fail("Pack 03 apply failed: " + reality_id)
            return false
        if reality_probe.call("snapshot", reality_nodes, reality_id) == reality_before:
            _fail("Pack 03 effect unchanged: " + reality_id)
            return false
        if reality_id == "unfinished_game":
            var wheel := reality_nodes[0]
            var effect := wheel.get_node_or_null("AnomalyPack03")
            var reality_ball := wheel.get_node_or_null("AnomalyPack03/OrbitingIvoryBall") as Node3D
            var rotor := wheel.get_node_or_null("AnomalyPack03/InnerRotor") as Node3D
            if reality_ball == null or rotor == null or rotor.get_child_count() == 0:
                _fail("Unfinished game has no ball or inner rotor")
                return false
            # The second real room retains all original render geometry.
            # Sample that wheel, not the first room's partitioned copies.
            var source_wheel := reality_other[0]
            var wheel_bounds: AABB = reality_probe.call("_bounds",source_wheel)
            var orbit_radius := minf(wheel_bounds.size.x,wheel_bounds.size.z)*0.40
            var track_height: float = reality_probe.call("_roulette_track_height",source_wheel,wheel_bounds,orbit_radius)
            if absf(reality_ball.position.y-track_height-0.022) > 0.002 or reality_ball.position.y >= wheel_bounds.end.y:
                _fail("Pack 03 roulette ball not seated on wheel track")
                return false
            var original_meshes: Array = effect.get("originals").duplicate()
            if original_meshes.is_empty():
                _fail("Rotor did not preserve original source geometry")
                return false
            var start: Vector2 = effect.call("cycle_targets",0.0,0)
            var near_result: Vector2 = effect.call("cycle_targets",0.78,0)
            var end: Vector2 = effect.call("cycle_targets",1.0,0)
            if not start.is_equal_approx(end) or near_result.x >= start.x*0.8 or near_result.y >= start.y*0.2:
                _fail("Roulette cannot approach a result and smoothly climb out again")
                return false
            var previous := start
            for i in range(1,201):
                var targets: Vector2 = effect.call("cycle_targets",float(i)/200.0,0)
                if absf(targets.x-previous.x)>0.02 or absf(targets.y-previous.y)>0.16:
                    _fail("Roulette phase has an abrupt discontinuity")
                    return false
                previous = targets
            var reality_ball_start := reality_ball.position
            var rotor_start := rotor.rotation.y
            effect.call("advance",0.25)
            if reality_ball.position.is_equal_approx(reality_ball_start) or is_equal_approx(rotor.rotation.y,rotor_start):
                _fail("Ball and rotor must both move")
                return false
            reality_adapter.clear()
            for source in original_meshes:
                if not is_instance_valid(source["node"]) or source["node"].visible != source["visible"]:
                    _fail("Roulette original render geometry not restored")
                    return false
            if wheel.has_node("AnomalyPack03"):
                _fail("Roulette rotor or ball survived reset")
                return false
            # Reapply and run the shared room isolation/reset checks too.
            if not reality_adapter.apply(hall,reality_id):
                _fail("Roulette cannot be reapplied after clear")
                return false
        if reality_id == "invisible_dealer" and reality_nodes.size() != 16:
            _fail("Both card tables must be animated")
            return false
        if reality_id == "forgotten_door":
            var door_root := reality_nodes[0].get_node_or_null("AnomalyPack03") as Node3D
            if door_root == null or not door_root.has_node("DoorCollision/Shape") or not door_root.has_node("DoorBacking"):
                _fail("Pack 03 door backing/collision missing")
                return false
            if absf(door_root.position.z - reality_wall.get_aabb().position.z) > 0.13:
                _fail("Pack 03 door detached from the wall")
                return false
            if absf(door_root.position.x-(reality_wall.get_aabb().end.x-7.9)) > 0.01:
                _fail("Pack 03 door not in the reviewed free wall bay")
                return false
            var hinge := door_root.get_node_or_null("DoorHinge") as Node3D
            var recess := door_root.get_node_or_null("DarkRecess") as MeshInstance3D
            if hinge == null or recess == null or not hinge.has_node("WeatheredDoor") or not hinge.has_node("DoorKnob") or not hinge.has_node("MovingLeafCollision"):
                _fail("Door hinge, moving details, solid leaf or recess missing")
                return false
            var black := recess.material_override as StandardMaterial3D
            if black == null or black.albedo_color != Color.BLACK or black.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
                _fail("Door recess must remain opaque and unlit")
                return false
            var frame_transform := (door_root.get_node("Lintel") as Node3D).transform
            var initial_angle := hinge.rotation.y
            door_root.call("advance",0.10,1.0,false)
            if hinge.rotation.y <= initial_angle or hinge.rotation.y >= deg_to_rad(16.0):
                _fail("Door opening did not ease toward target")
                return false
            for step in range(50):
                door_root.call("advance",0.1,1.0,false)
            var opened := hinge.rotation.y
            if opened < deg_to_rad(15.0) or (door_root.get_node("Lintel") as Node3D).transform != frame_transform:
                _fail("Door opening or fixed frame regressed")
                return false
            door_root.call("advance",0.1,6.0,false)
            if hinge.rotation.y >= opened or hinge.rotation.y <= 0.0:
                _fail("Door closing snapped or failed to start")
                return false
            for step in range(60):
                door_root.call("advance",0.1,6.0,false)
            if absf(hinge.rotation.y) > 0.001:
                _fail("Door did not close on departure")
                return false
        if reality_id == "black_bloom":
            var bloom_root := reality_nodes[0].get_node_or_null("AnomalyPack03") as Node3D
            if bloom_root == null or bloom_root.get_child_count() < 19:
                _fail("Pack 03 organic strands missing")
                return false
            var core := bloom_root.get_node_or_null("OrganicSourceCore") as MeshInstance3D
            if core == null or not core.mesh is ArrayMesh or core.get_aabb().size.x > 1.2 or core.get_aabb().size.x < 0.5:
                _fail("Bloom is missing its compact organic source")
                return false
            var painting_bounds: Array[AABB] = reality_probe.call("_bloom_painting_bounds", hall, bloom_root, reality_wall.get_aabb().size.x * 0.5)
            if painting_bounds.is_empty():
                _fail("Bloom painting clearance has no authored painting geometry")
                return false
            var bloom_bounds := AABB()
            var first_strand := true
            for strand in bloom_root.get_children():
                if not (strand is MeshInstance3D) or not (strand.mesh is ArrayMesh):
                    _fail("Pack 03 organic strand not 3D geometry")
                    return false
                if strand == core:
                    continue
                var vertices: PackedVector3Array = strand.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
                for vertex in vertices:
                    for painting in painting_bounds:
                        if painting.has_point(vertex):
                            _fail("Bloom strand intersects authored painting bounds")
                            return false
                var strand_bounds: AABB = strand.transform * strand.get_aabb()
                bloom_bounds = strand_bounds if first_strand else bloom_bounds.merge(strand_bounds)
                first_strand = false
            if bloom_bounds.size.x < reality_wall.get_aabb().size.x*0.88:
                _fail("Pack 03 organic strands no longer cover the wall width")
                return false
        if reality_id == "against_gravity":
            var drop_emitter := reality_nodes[0].get_node_or_null("AnomalyPack03")
            if drop_emitter == null or not drop_emitter.find_children("*", "CollisionObject3D", true, false).is_empty():
                _fail("Inverted rain must have no physics bodies or ceiling rebound")
                return false
            var drops := drop_emitter.find_children("RisingLiquid_*", "MeshInstance3D", false, false)
            var sources: Array = drop_emitter.get("sources")
            if sources.size() != reality_nodes.size() or drops.size() != sources.size()*3:
                _fail("Inverted rain pool does not cover the upper bottle row")
                return false
            for drop in drops:
                if not drop.mesh is ArrayMesh or not drop.material_override is StandardMaterial3D or drop.material_override.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
                    _fail("Inverted rain needs shaped translucent liquid meshes")
                    return false
            for index in range(sources.size()):
                var start: Dictionary = drop_emitter.call("sample_drop", index, 0.025, 0.0, 0.0)
                var middle: Dictionary = drop_emitter.call("sample_drop", index, 0.025, 0.0, float(start["duration"])*0.5)
                var end: Dictionary = drop_emitter.call("sample_drop", index, 0.025, 0.0, float(start["duration"]))
                var p0: Vector3 = start["position"]
                var p1: Vector3 = middle["position"]
                var p2: Vector3 = end["position"]
                if p1.y <= p0.y or p2.y-p1.y <= p1.y-p0.y or p2.y >= float(drop_emitter.get("ceiling_height")) or float(end["opacity"]) > 0.001 or float(middle["opacity"]) < 0.9:
                    _fail("Inverted rain must accelerate upward and fade before the ceiling")
                    return false
        if reality_id == "they_are_listening":
            if not reality_nodes[0].has_node("AnomalyPack03/ListeningView"):
                _fail("Listening screen effect missing")
                return false
            var positions := [Vector3(0,0,5),Vector3(-6,0,-5.05),Vector3(-12,0,-5.05),Vector3(-18,0,-5.05),Vector3(-24,0,-5.05),Vector3(-30,0,-5.05),Vector3(-36,0,-5.05)]
            var weights: Array[float] = []
            for point in positions:
                weights.append(float(reality_probe.call("_listening_weight",point)))
            if weights[0] < 0.99 or weights[1] > 0.15 or weights[2] < 0.60 or weights[3] > 0.15 or weights[4] < 0.88 or weights[5] > 0.15 or weights[6] < 0.65:
                _fail("Listening intensity no longer alternates along the runner")
                return false
            var previous := float(reality_probe.call("_listening_weight",Vector3(-6,0,-5.05)))
            for step in range(1,381):
                var weight := float(reality_probe.call("_listening_weight",Vector3(-6.0-float(step)*0.1,0,-5.05)))
                if absf(weight-previous) > 0.06:
                    _fail("Listening has an abrupt trigger boundary")
                    return false
                previous = weight
        if reality_id == "extra_guest":
            var guest_root := reality_nodes[0].get_node_or_null("AnomalyPack03") as Node3D
            var guest := reality_nodes[0].get_node_or_null("AnomalyPack03/SeatedGuest") as Node3D
            if guest_root == null or guest == null or guest.scene_file_path != "res://models/silent_audience/suit_man/scene.gltf":
                _fail("Silent guest must use the newer suited character")
                return false
            if not str(guest.get_meta("seated_source_clip","")).to_lower().contains("sitting_idle") or int(guest.get_meta("face_mask_surfaces",0)) < 1:
                _fail("Silent guest is missing the actual sitting clip or face-only mask")
                return false
            if not is_equal_approx(guest.scale.x,guest.scale.y) or not is_equal_approx(guest.scale.y,guest.scale.z):
                _fail("Silent guest has distorted character proportions")
                return false
            var collision := guest_root.get_node_or_null("GuestCollision") as StaticBody3D
            if collision == null or collision.collision_layer != 1 or collision.get_child_count() < 6:
                _fail("Silent guest lacks pose-shaped physical collision")
                return false
            var masks := 0
            var single_pass_head := false
            var hidden_glasses := false
            for part in guest.find_children("*","MeshInstance3D",true,false):
                var mesh := part as MeshInstance3D
                if mesh.mesh == null:
                    continue
                if mesh.has_meta("guest_hidden_glasses"):
                    hidden_glasses = not mesh.visible
                for surface in range(mesh.mesh.get_surface_count()):
                    var material := mesh.get_active_material(surface)
                    if material == null or not material.has_meta("guest_face_mask"):
                        continue
                    var label := str(material.resource_name).to_lower()
                    if "avatarhead" in label:
                        single_pass_head = material is ShaderMaterial and material.next_pass == null
                        if not single_pass_head:
                            _fail("Guest face must be shaded in its original surface, not an overlay")
                            return false
                    if not ("avatarhead" in label or "eyeball" in label or "cornea" in label or "eyelash" in label or "teeth" in label):
                        _fail("Face mask modified a body or clothing surface")
                        return false
                    if not "avatarhead" in label:
                        var dark := material as StandardMaterial3D
                        if dark == null or dark.albedo_color != Color.BLACK or dark.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or dark.albedo_texture != null:
                            _fail("Guest face accessory can reveal facial detail")
                            return false
                    masks += 1
            if masks < 1 or not single_pass_head or not hidden_glasses:
                _fail("Face mask not installed on facial surfaces")
                return false
            if float(guest.get_meta("standing_height",0.0)) < 1.75:
                _fail("Guest human proportions too small")
                return false
            var front := float(guest.get_meta("seat_front_z",0.0))
            var seat_y := float(guest.get_meta("seat_surface_y",0.0))
            var floor_y := float(guest.get_meta("floor_y",0.0))
            for side in ["left","right"]:
                var thigh_shape := collision.get_node_or_null(side+"_thigh") as CollisionShape3D
                var shin_shape := collision.get_node_or_null(side+"_shin") as CollisionShape3D
                var arm_shape := collision.get_node_or_null(side+"_forearm") as CollisionShape3D
                if thigh_shape == null or shin_shape == null or arm_shape == null:
                    _fail("Guest pose collision missing")
                    return false
                var shin := shin_shape.shape as CapsuleShape3D
                var axis := shin_shape.basis.y.normalized()
                var half := (shin.height-2.0*shin.radius)*0.5
                var p0 := shin_shape.position-axis*half
                var p1 := shin_shape.position+axis*half
                var knee := p0 if p0.y>p1.y else p1
                var ankle := p1 if p0.y>p1.y else p0
                if knee.z < front-0.025 or ankle.z < front or ankle.y < floor_y-0.025:
                    _fail("Guest leg intersects front of sofa or floor")
                    return false
                if arm_shape.position.y < seat_y+0.09:
                    _fail("Guest forearm intersects seat")
                    return false
            # Check the real wrist landmarks, not a stored target. Across
            # the knuckles should be nearly horizontal, with fingers pointing
            # towards the knees rather than palms facing each other.
            var guest_rig: Skeleton3D
            for item in guest.find_children("*","Skeleton3D",true,false):
                if (item as Skeleton3D).get_bone_count()>25:
                    guest_rig = item as Skeleton3D
                    break
            if guest_rig == null:
                _fail("Guest skeleton missing")
                return false
            for prefix in ["LeftHand","RightHand"]:
                var landmarks := {}
                for bone_index in range(guest_rig.get_bone_count()):
                    for part_name in ["_","Index1_","Middle1_","Pinky1_"]:
                        if str(guest_rig.get_bone_name(bone_index)).begins_with(prefix+part_name):
                            landmarks[part_name] = guest_root.to_local(guest_rig.to_global(guest_rig.get_bone_global_pose(bone_index).origin))
                if landmarks.size()!=4:
                    _fail("Guest wrist landmarks missing")
                    return false
                var across: Vector3 = (landmarks["Pinky1_"]-landmarks["Index1_"]).normalized()
                var along: Vector3 = (landmarks["Middle1_"]-landmarks["_"]).normalized()
                if absf(across.y)>0.20 or along.z<0.90:
                    _fail("Guest palms are not resting flat towards knees")
                    return false
            for animator in guest.find_children("*","AnimationPlayer",true,false):
                if (animator as AnimationPlayer).is_playing():
                    _fail("Silent guest is not motionless")
                    return false
        if reality_id == "wrong_reflection":
            var reality_mirror := reality_nodes[0].get_node_or_null("AnomalyPack03")
            if reality_mirror == null or not reality_mirror.has_node("ReflectionViewport/ReflectedCamera") or not reality_mirror.has_node("ReflectionOnlyGuest") or not reality_mirror.has_node("MirrorSurface"):
                _fail("Pack 03 reflection setup incomplete")
                return false
            var viewport := reality_mirror.get_node("ReflectionViewport") as SubViewport
            var reflection_actor := reality_mirror.get_node("ReflectionOnlyGuest") as Node3D
            if viewport.size.x < 1008 or not reality_mirror.has_node("MirrorCollision/Shape") or reflection_actor.scene_file_path != "res://models/silent_audience/security_guard/scene.gltf" or not reflection_actor.has_meta("native_idle_pose"):
                _fail("Pack 03 mirror quality, collision or native actor regression")
                return false
            if not is_equal_approx(reflection_actor.scale.x,reflection_actor.scale.y) or not is_equal_approx(reflection_actor.scale.y,reflection_actor.scale.z) or not reflection_actor.find_children("*","CollisionObject3D",true,false).is_empty():
                _fail("Mirror actor has distorted proportions or real-world collision")
                return false
            for reflected_mesh in reflection_actor.find_children("*", "MeshInstance3D", true, false):
                if reflected_mesh.layers != (1 << 19) or reflected_mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
                    _fail("Pack 03 reflected guest visible or casting shadows outside mirror layer")
                    return false
            var mirror_node := reality_mirror as Node3D
            var mirror_center := mirror_node.global_position
            var mirror_normal := mirror_node.global_basis.z.normalized()
            var reflected := viewport.get_node("ReflectedCamera") as Camera3D
            # Close and oblique eye positions must retain the quad corner rays.
            for eye_offset in [Vector3(0,0,2.0),Vector3(0.70,-0.35,0.10),Vector3(-1.3,0.25,1.0)]:
                var eye: Vector3 = mirror_center+mirror_node.global_basis*eye_offset
                if not bool(reality_mirror.call("_sync_reflected_camera",eye,100.0)):
                    _fail("Mirror rejected a valid close or off-axis eye")
                    return false
                var reflected_eye := eye-2.0*(eye-mirror_center).dot(mirror_normal)*mirror_normal
                var top_left := mirror_center-reflected.global_basis.x*0.825+reflected.global_basis.y*0.925
                var bottom_right := mirror_center+reflected.global_basis.x*0.825-reflected.global_basis.y*0.925
                if not reflected.global_position.is_equal_approx(reflected_eye) or reflected.unproject_position(top_left).distance_to(Vector2.ZERO)>3.0 or reflected.unproject_position(bottom_right).distance_to(Vector2(viewport.size))>3.0:
                    _fail("Mirror perspective does not remain attached to its physical corners")
                    return false
        if reality_probe.call("snapshot", reality_other, reality_id) != reality_isolated:
            _fail("Pack 03 leaked to another room: " + reality_id)
            return false
        reality_adapter.clear()
        if reality_wall.layers != reality_wall_layers:
            _fail("Pack 03 reflection layer remained after cleanup")
            return false
        if reality_probe.call("snapshot", reality_nodes, reality_id) != reality_before:
            _fail("Pack 03 failed to restore: " + reality_id)
            return false
    return true


func _verify_flood(hall: Node3D, other: Node3D) -> bool:
    if not Catalog.discoverable_ids().has("the_flood") or not Catalog.available_ids(hall).has("the_flood"):
        _fail("Major event The Flood unavailable in real casino")
        return false
    var adapter := Adapter.new()
    var floor := hall.get_node("Architecture/OakMainWing") as MeshInstance3D
    var original_mesh := floor.mesh
    var original_material := floor.material_override
    if not adapter.apply(hall,"the_flood"):
        _fail("The Flood apply failed")
        return false
    var event := hall.get_node_or_null("AnomalyFlood")
    if event == null or not event.has_node("FloodSurface") or not event.has_node("FloatingCards") or other.has_node("AnomalyFlood"):
        _fail("Flood geometry/cards missing or leaked across rooms")
        return false
    if not bool(event.call("contains_water",Vector3(3.25,0,8.0))) or bool(event.call("contains_water",Vector3(-42,0,-6))):
        _fail("Flood must start as a local puddle")
        return false
    hall.set_meta("_streaming_standby",true)
    event.call("_process",3.0)
    hall.remove_meta("_streaming_standby")
    if float(event.get("elapsed")) != 0.0:
        _fail("Flood advanced in staged room")
        return false
    event.set("elapsed",24.0)
    event.call("_update_progress")
    var half_height := float(event.get("water_height"))
    if half_height <= 0.09 or half_height >= 0.19:
        _fail("Flood midpoint height invalid")
        return false
    event.set("elapsed",48.0)
    event.call("_update_progress")
    if not bool(event.call("contains_water",Vector3(-44,0,-6))) or not bool(event.call("contains_water",Vector3(0,0,12))) or bool(event.call("contains_water",Vector3(-20,0,5))):
        _fail("Flood does not match the full L-shaped floor")
        return false
    if absf(float(event.get("water_height"))-0.230)>0.002 or event.get_node("FloatingCards").get_child_count() < 8:
        _fail("Flood depth or card models missing")
        return false
    for card in event.get_node("FloatingCards").get_children():
        if not is_equal_approx(card.scale.x,0.16):
            _fail("Flood floating card scale regressed")
            return false
    var drop := event.get_node_or_null("CeilingDroplet_00") as MeshInstance3D
    if drop == null or not (drop.mesh is ArrayMesh) or drop.mesh.get_aabb().size.y < 0.08:
        _fail("Flood shaped droplet missing")
        return false
    if not event.find_children("*","CollisionObject3D",true,false).is_empty():
        _fail("Flood must never obstruct player or exits")
        return false
    adapter.clear()
    if hall.has_node("AnomalyFlood") or floor.mesh != original_mesh or floor.material_override != original_material:
        _fail("Flood cleanup modified base room")
        return false
    return true


func _verify_other_side(hall: Node3D, other: Node3D) -> bool:
    if not Catalog.discoverable_ids().has("the_other_side") or not Catalog.available_ids(hall).has("the_other_side"):
        _fail("Major event The Other Side unavailable")
        return false
    var wall := hall.get_node("Architecture/SouthWestWall") as MeshInstance3D
    var original_mesh := wall.mesh
    var original_visible := wall.visible
    var original_material := wall.material_override
    var collider := hall.get_node_or_null("Architecture/SouthWestWall_Collision")
    var other_wall := other.get_node("Architecture/SouthWestWall") as MeshInstance3D
    var other_visible := other_wall.visible
    # Find the real saved lower cladding independently. It may have an
    # automatic editor name, so the event must not depend on its label.
    var trim: MeshInstance3D
    for child in wall.get_parent().get_children():
        var mesh := child as MeshInstance3D
        if mesh == null or not (mesh.mesh is BoxMesh):
            continue
        var b: AABB = (hall.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
        if b.size.x>30.0 and b.size.y>1.5 and b.size.y<2.5 and b.size.z<0.3 and absf(b.get_center().z)<0.2:
            trim = mesh
            break
    if trim == null:
        _fail("Other Side test: missing south wall cladding")
        return false
    var trim_original_name := trim.name
    var trim_original_visible := trim.visible
    trim.name = "RenamedCladdingForQA"
    # Exercise the same runtime geometry replacement as the real run.
    var portals := StreamPortals.new()
    if not portals.prepare_room(hall) or hall.get_node("Architecture/FarExitWall").visible:
        _fail("Other Side test: streaming exit geometry not prepared")
        return false
    var adapter := Adapter.new()
    if not adapter.apply(hall,"the_other_side"):
        _fail("Other Side apply failed")
        return false
    var event := hall.get_node_or_null("AnomalyOtherSide")
    if event == null or wall.visible or trim.visible or other.has_node("AnomalyOtherSide") or other_wall.visible!=other_visible:
        _fail("Other Side wall replacement or isolation failed")
        return false
    var capture := event.get_node_or_null("OtherSideViewport") as SubViewport
    var inverted := event.get_node_or_null("OtherSideViewport/InvertedCasino") as Node3D
    var panel := event.get_node_or_null("SlidingWallSection") as Node3D
    if capture == null or inverted == null or panel == null or not capture.own_world_3d or capture.find_world_3d()==hall.get_world_3d():
        _fail("Other Side needs an isolated visual world")
        return false
    if inverted.basis.y.dot(Vector3.DOWN)<0.99 or int(event.get("cloned_meshes"))<30 or not inverted.has_node("SketchfabFurniture"):
        _fail("Other Side casino is not fully inverted")
        return false
    var stream_copy := inverted.get_node_or_null("StreamingPortals")
    if stream_copy == null or stream_copy.find_children("*ExitWallPier*","MeshInstance3D",true,false).is_empty() or stream_copy.find_children("*StraightFloor*","MeshInstance3D",true,false).size()<2:
        _fail("Other Side did not clone runtime exit piers and both corridors")
        return false
    var aperture := event.get_node("OtherSideAperture") as MeshInstance3D
    var source_wall: AABB = event.get("wall_bounds")
    var anchor := Vector3(aperture.position.x+0.65,source_wall.get_center().y,source_wall.position.z)
    var destination: Vector3 = inverted.transform*anchor
    var inward: Vector3 = inverted.basis*Vector3.FORWARD
    if absf(destination.z-aperture.position.z)>0.001 or absf(destination.x-anchor.x)>0.001 or inward.dot(Vector3.BACK)<0.999 or inverted.basis.x.dot(Vector3.RIGHT)<0.999:
        _fail("Other Side still uses the former opposite-wall orientation")
        return false
    var opposite := hall.get_node("Architecture/NorthWestWall") as MeshInstance3D
    var opposite_local := hall.to_local(opposite.global_position)
    if (inverted.transform*opposite_local).z <= aperture.position.z+10.0:
        _fail("Other Side opposite wall is not behind the aperture")
        return false
    var debris: Array = event.get("debris")
    event.set("reduced",false)
    event.set("debris_clock",0.0)
    var first_debris: Dictionary = debris[0]
    var particle := first_debris["node"] as Node3D
    first_debris["delay"] = 0.0
    event.call("_update_debris",0.15)
    var high := particle.position.y
    event.call("_update_debris",0.8)
    if particle.position.y>=high or high<source_wall.get_center().y:
        _fail("Other Side debris does not fall from inverted floor toward ceiling")
        return false
    if absf(aperture.position.x+27.05)>0.01:
        _fail("Other Side aperture not at the clear lounge approach")
        return false
    var env := (capture.get_node("InvertedEnvironment") as WorldEnvironment).environment
    if env.ambient_light_energy>0.25 or env.tonemap_exposure>1.0:
        _fail("Other Side lighting washed out")
        return false
    event.set("quality","original")
    if event.call("_capture_size",Vector2(1920,1080))!=Vector2i(2400,1350):
        _fail("Other Side default capture resolution regressed")
        return false
    event.set("quality","ultra")
    if event.call("_capture_size",Vector2(2560,1440))!=Vector2i(3840,2160):
        _fail("Other Side ultra capture resolution regressed")
        return false
    # A close, offset eye must still project the physical corners to the
    # same texture corners. This is independent of player yaw and pitch.
    var aperture_size := (aperture.mesh as QuadMesh).size
    capture.size = Vector2i(1300,1000)
    var eye := aperture.position+Vector3(0.8,-1.3,-0.95)
    event.call("_sync_portal_camera",eye,100.0)
    var virtual_camera := capture.get_node("OtherSideCamera") as Camera3D
    var top_left := aperture.position+Vector3(aperture_size.x*0.5,aperture_size.y*0.5,0.0)
    var bottom_right := aperture.position-Vector3(aperture_size.x*0.5,aperture_size.y*0.5,0.0)
    if virtual_camera.projection!=Camera3D.PROJECTION_FRUSTUM or virtual_camera.unproject_position(top_left).distance_to(Vector2.ZERO)>2.0 or virtual_camera.unproject_position(bottom_right).distance_to(Vector2(capture.size))>2.0:
        _fail("Other Side close-range projection is not anchored to the aperture")
        return false
    if not capture.find_children("*","CollisionObject3D",true,false).is_empty():
        _fail("Other Side cloned active gameplay physics")
        return false
    hall.set_meta("_streaming_standby",true)
    event.call("_process",3.0)
    hall.remove_meta("_streaming_standby")
    if str(event.get("phase"))!="waiting" or float(event.get("elapsed"))!=0.0:
        _fail("Other Side advanced during streaming standby")
        return false
    event.set("reduced",false)
    event.call("_advance",0.1,true)
    event.call("_advance",6.0,true)
    if str(event.get("phase"))!="open" or panel.position.x>-3.9 or not event.get_node("OtherSideAperture").visible:
        _fail("Other Side did not fully open")
        return false
    event.call("_advance",26.0,true)
    event.call("_advance",6.0,true)
    if str(event.get("phase"))!="rest" or absf(panel.position.x)>0.01:
        _fail("Other Side did not close")
        return false
    event.call("_advance",8.0,true)
    event.call("_advance",0.1,true)
    if str(event.get("phase"))!="opening":
        _fail("Other Side cannot repeat for late observers")
        return false
    adapter.clear()
    # Restore the editor name only after exercising the normal clear path.
    var trim_restored := trim.visible==trim_original_visible
    # Auto-generated names containing @ are not valid manual assignments.
    # The test hall is destroyed immediately after this regression check.
    if not str(trim_original_name).contains("@"):
        trim.name = trim_original_name
    if not trim_restored or hall.has_node("AnomalyOtherSide") or wall.mesh!=original_mesh or wall.material_override!=original_material or wall.visible!=original_visible or hall.get_node_or_null("Architecture/SouthWestWall_Collision")!=collider:
        _fail("Other Side cleanup changed authored room")
        return false
    return true
