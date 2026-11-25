extends SceneTree
## Validate all new, understated anomalies against real casino nodes:
## registration, visibility, exact restoration, room isolation, and adapter.
const ROOM = preload("res://main.tscn")
const Catalog = preload("res://gameplay/anomaly_catalog.gd")
const Adapter = preload("res://gameplay/demo_anomalies.gd")

const NEW_IDS := [
    "stool_out_of_line",
    "plant_forward",
    "plant_misplaced",
    "crooked_painting",
    "candleholder_shifted",
    "bust_turned",
    "west_chandelier_dim",
    "cool_ceiling_light",
    "amber_ceiling_light",
    "horse_spotlight_off"
]


func _initialize() -> void:
    call_deferred("_run")


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
        "plant_misplaced": {
            "target_path": "Decor/Plant_04",
            "position_offset": Vector3(0.45, 0.0, -0.80)
        },
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
            "color": Color("#72bfff"),
            "energy_scale": 1.90
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


func _run() -> void:
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

    # Real room geometry: pot 04 must stay between both sofas and away
    # from the green wall. Its authored Z was -0.78 and the earlier +0.60
    # moved it through the wall; keep it well within the walkable lounge.
    var plant := room.get_node("Decor/Plant_04") as Node3D
    var left_sofa := room.get_node("ModelInteriors/LoungeSofa_04") as Node3D
    var right_sofa := room.get_node("ModelInteriors/LoungeSofa_03") as Node3D
    var moved_pos: Vector3 = plant.position + Catalog.get_entry("plant_misplaced")["position_offset"]
    if moved_pos.z > -1.35 or moved_pos.z < -2.25             or moved_pos.x <= left_sofa.position.x + 1.7             or moved_pos.x >= right_sofa.position.x - 1.7:
        _fail("Plant 04 must move into the clear aisle-side gap, not into wall or sofas")
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
    # Batch 01: ten independent family IDs, each available on the real
    # room and isolated from the next streamed instance.
    var batch_ids := ["blank_reels","false_jackpot","dark_marquee","watchful_camera","floating_hand","missing_hand","burgundy_felt","blue_runner","empty_reserve","bare_monstera"]
    for id in batch_ids:
        var entry := Catalog.get_entry(id)
        if entry.is_empty() or Catalog.family(id) != id or not available.has(id):
            _fail("Batch 01 family missing or unavailable: " + id)
            return
        var handler: RefCounted = entry["handler"].new()
        var nodes: Array[Node3D] = handler.call("targets", room, entry)
        var other_nodes: Array[Node3D] = handler.call("targets", next_room, entry)
        var expected_counts := {"blank_reels": 3, "false_jackpot": 2, "dark_marquee": 6, "watchful_camera": 2, "floating_hand": 4, "missing_hand": 8, "burgundy_felt": 1, "blue_runner": 3}
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
    if not _verify_horror_batch(room, next_room):
        return
    room.queue_free()
    next_room.queue_free()
    await process_frame
    print("Casino Anomaly ten subtle anomalies QA PASS")
    quit(0)


func _verify_horror_batch(hall: Node3D, other_hall: Node3D) -> bool:
    var horror_ids := ["synchronized_busts","inverted_cat","lightless_horse","watching_canvases","stay_here","last_kings","ownerless_shadow","empty_footsteps","crimson_hall","silent_countdown"]
    var horror_adapter := Adapter.new()
    var horror_counts := {"synchronized_busts": 2, "inverted_cat": 1, "watching_canvases": 3, "stay_here": 3, "ownerless_shadow": 1, "empty_footsteps": 1}
    var available_horror := Catalog.available_ids(hall)
    for horror_id in horror_ids:
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
        if horror_id in ["ownerless_shadow", "empty_footsteps"]:
            var mark_group := affected[0].get_node_or_null("AnomalyHorrorMark")
            var expected_marks := 1 if horror_id == "ownerless_shadow" else 6
            if mark_group == null or mark_group.get_child_count() != expected_marks:
                _fail("Pack 02 missing floor marks: " + horror_id)
                return false
            for mark_mesh in mark_group.get_children():
                if not mark_mesh is MeshInstance3D or mark_mesh.material_override.albedo_texture == null:
                    _fail("Pack 02 floor mark missing generated texture")
                    return false
        horror_adapter.clear()
        if inspector.call("snapshot", affected, horror_id) != initial:
            _fail("Pack 02 failed to restore: " + horror_id)
            return false
    return true
