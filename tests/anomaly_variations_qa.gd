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
    room.queue_free()
    next_room.queue_free()
    await process_frame
    print("Casino Anomaly ten subtle anomalies QA PASS")
    quit(0)
