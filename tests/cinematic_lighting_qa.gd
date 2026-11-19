extends SceneTree
## Lighting regression: authored lights and Forward+ effects must stay
## coherent in every instanced hall without affecting the room's geometry.
const ROOM = preload("res://main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("Casino cinematic lighting QA: " + message)
    quit(1)

func _run() -> void:
    var hall := ROOM.instantiate() as Node3D
    if hall == null:
        _fail("Authored casino scene cannot be instantiated")
        return
    root.add_child(hall)
    await process_frame
    await process_frame

    var world := hall.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if world == null or world.environment == null:
        _fail("Missing WorldEnvironment")
        return
    var e := world.environment
    if e.ambient_light_energy < 0.15 or e.ambient_light_energy > 0.18:
        _fail("Ambient illumination is not balanced for dark casino corners")
        return
    if e.tonemap_exposure < 0.98 or e.tonemap_exposure > 1.05:
        _fail("Cinematic exposure is outside the restrained night range")
        return
    if not e.ssao_enabled or not e.ssil_enabled or not e.ssr_enabled:
        _fail("Forward+ contact shadows, indirect light or reflections missing")
        return
    if e.ssil_radius > 3.0 or e.ssr_max_steps > 40 or e.ssil_intensity < 0.75:
        _fail("Screen-space effects exceed the reasonable performance budget")
        return
    if not e.volumetric_fog_enabled or e.volumetric_fog_density > 0.008:
        _fail("Volumetric haze must remain subtle")
        return
    if e.fog_density > 0.002 or e.glow_bloom > 0.025:
        _fail("Fog or bloom is washing away the new contrast")
        return
    var atmosphere := hall.get_node_or_null("CasinoAtmosphere") as Node3D
    if atmosphere == null:
        _fail("Missing atmosphere node")
        return
    # Dark corners are retained; two local, shadowless fills bring back
    # shelf bottles, the counter edge and nearby stool silhouettes.
    for name in ["BarShelfFill", "BarCounterFill"]:
        var bar_fill := atmosphere.get_node_or_null(name) as OmniLight3D
        if bar_fill == null:
            _fail("Missing local bar fill: " + name)
            return
        if bar_fill.light_energy <= 0.2 or bar_fill.light_energy > 0.5 \
                or bar_fill.omni_range > 4.5 or bar_fill.shadow_enabled \
                or bar_fill.light_volumetric_fog_energy != 0.0:
            _fail("Bar fill washes out the shadows or adds undue cost: " + name)
            return
    var probe_count := 0
    for node in atmosphere.get_children():
        var probe := node as ReflectionProbe
        if probe == null:
            continue
        probe_count += 1
        if not probe.box_projection or not probe.interior                 or probe.enable_shadows or probe.update_mode != ReflectionProbe.UPDATE_ONCE:
            _fail("Probe must be an inexpensive one-shot interior box capture")
            return
    if probe_count != 2:
        var child_names := PackedStringArray()
        for child in atmosphere.get_children():
            child_names.append("%s (%s)" % [child.name, child.get_class()])
        _fail("Expected two ReflectionProbes, got %d. Atmosphere children: %s" % [
            probe_count, ", ".join(child_names)
        ])
        return
    var light_rig := hall.get_node_or_null("Lighting") as Node3D
    if light_rig == null:
        _fail("Casino light rig was removed")
        return
    var bright := 0
    var shadows := 0
    for child in light_rig.get_children():
        var lamp := child as OmniLight3D
        if lamp == null:
            continue
        if lamp.light_energy > 1.8 or lamp.omni_range > 7.2:
            _fail("Unnaturally broad ceiling light flattens the casino")
            return
        if lamp.shadow_enabled:
            shadows += 1
        if lamp.light_energy > 0.8:
            bright += 1
    if bright < 4 or shadows < 2:
        _fail("Need readable, shadow-casting light pools between casino bays")
        return
    var parent_lamps := hall.get_node_or_null("ModelInteriors") as Node3D
    if parent_lamps == null:
        _fail("Original chandelier nodes missing")
        return
    var nested := parent_lamps.get_node_or_null("ChandelierWarmLight_01/ChandelierWarmLight_01") as OmniLight3D
    if nested == null or nested.light_volumetric_fog_energy > 0.35:
        _fail("Chandelier caused excessive volumetric blowout")
        return

    hall.queue_free()
    await process_frame
    print("Casino Anomaly cinematic lighting and reflection QA PASS")
    quit(0)
