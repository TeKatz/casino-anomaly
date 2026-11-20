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
            "position_offset": Vector3(0.55, 0.0, 0.60)
        },
        "crooked_painting": {
            "target_path": "ModelInteriors/FramedPainting_02",
            "position_offset": Vector3(0.0, 0.22, 0.0),
            "rotation_degrees": Vector3(0.0, 0.0, 7.0)
        },
        "candleholder_shifted": {
            "target_path": "ModelInteriors/SingleBrassCandleholder_02",
            "position_offset": Vector3(0.26, -0.035, 0.12)
        },
        "west_chandelier_dim": {"energy_scale": 0.03},
        "cool_ceiling_light": {
            "color": Color("#72bfff"),
            "energy_scale": 1.90
        },
        "amber_ceiling_light": {
            "target_path": "Lighting/WarmCasinoLamp_03",
            "color": Color("#ff8a42"),
            "energy_scale": 1.85
        },
        "horse_spotlight_off": {
            "color": Color("#ff6b6b"),
            "energy_scale": 2.20,
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

    var definitions: Array[Dictionary] = Catalog.entries()
    var available: Array[String] = Catalog.available_ids(room)
    if definitions.size() != 13 or available.size() != 13:
        _fail("Catalog and actual room must expose 3 original + 10 new anomalies")
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
