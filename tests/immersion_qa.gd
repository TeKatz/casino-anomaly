extends SceneTree
## Headless-friendly checks: acoustic gates, procedural audio and floor logic.
const PlayerScript = preload("res://player.gd")
const Soundscape = preload("res://gameplay/room_soundscape.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("Casino immersion QA: " + message)
    quit(1)

func _run() -> void:
    var director := root.get_node_or_null("AudioDirector")
    if director == null or AudioServer.get_bus_index("WORLD") < 0:
        _fail("World audio bus or director is missing")
        return
    if director.get_node_or_null("FootstepCue") == null             or director.get_node_or_null("PressureBed") == null:
        _fail("Step/pressure players missing")
        return
    for kind in ["cabinet", "bar", "vent", "pressure"]:
        var loop := director.get_immersion_loop(kind) as AudioStreamWAV
        if loop == null or loop.loop_mode != AudioStreamWAV.LOOP_FORWARD:
            _fail("Non-looping positional bed: " + kind)
            return
    for surface in ["wood", "carpet", "corridor", "water"]:
        var wave := director.get_footstep_stream(surface, 0) as AudioStreamWAV
        if wave == null or wave.loop_mode != AudioStreamWAV.LOOP_DISABLED:
            _fail("Missing footstep: " + surface)
            return
    for variant in range(4):
        if director.get_footstep_stream("water",variant) == null:
            _fail("Missing water footstep variant")
            return
    var player = PlayerScript.new()
    for spec in [
        {"pos": Vector3(0.0, 0.0, 2.0), "surface": "carpet"},
        {"pos": Vector3(-22.0, 0.0, -5.0), "surface": "carpet"},
        {"pos": Vector3(4.0, 0.0, 2.0), "surface": "wood"},
        {"pos": Vector3(-49.0, 0.0, -3.7), "surface": "corridor"},
        {"pos": Vector3(0.0, 0.0, 15.0), "surface": "corridor"}
    ]:
        if player.classify_casino_surface(spec["pos"]) != spec["surface"]:
            _fail("Surface classification mismatch")
            return
    player.free()

    var hall := Node3D.new()
    hall.set_meta("_streaming_standby", true)
    var slots := Node3D.new()
    slots.name = "SlotMachines"
    hall.add_child(slots)
    for i in range(7):
        var slot := Node3D.new()
        slot.name = "Slot_%02d" % (i + 1)
        slots.add_child(slot)
    var zone := Soundscape.new()
    zone.name = "RoomSoundscape"
    hall.add_child(zone)
    root.add_child(hall)
    await process_frame
    await process_frame
    if zone.get_child_count() != 5 or bool(zone.get("_active")):
        _fail("Standby spatial sources must remain silent")
        return
    zone.activate()
    if not bool(zone.get("_active")):
        _fail("Spatial sound did not activate")
        return
    director.set_world_ambience_enabled(true)
    if not (director.get_node("PressureBed") as AudioStreamPlayer).playing:
        _fail("World pressure bed did not start")
        return
    if director.pressure_db_for_visits(10) <= director.pressure_db_for_visits(0):
        _fail("No progression in low-frequency ambience")
        return
    director.set_world_ambience_enabled(false)
    if (director.get_node("PressureBed") as AudioStreamPlayer).playing:
        _fail("World sound leaks into menu")
        return
    hall.queue_free()
    await process_frame
    director.queue_free()
    await process_frame
    await process_frame
    # The audio mixer can retain a decoding reference until its next tick.
    await create_timer(0.20).timeout
    if AudioServer.get_bus_index("WORLD") >= 0:
        _fail("WORLD reverb effect remains allocated after shutdown")
        return
    print("Casino Anomaly immersion QA PASS")
    quit(0)
