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
    if e.ssao_radius > 0.90 or e.ssao_light_affect < 0.18:
        _fail("Tight tabletop/floor contact occlusion must affect lit areas")
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
    # Every playable table needs an actual shadow-casting source. Emissive
    # strips and SSAO alone cannot generate these floor silhouettes.
    var table_spots := atmosphere.find_children(
        "TableKey_*", "SpotLight3D", false, false)
    if table_spots.size() != 6:
        _fail("Expected six shadow-casting table keys, got %d" % table_spots.size())
        return
    for table_spot in table_spots:
        var key_light := table_spot as SpotLight3D
        if key_light == null or not key_light.shadow_enabled \
                or key_light.light_energy < 1.3 \
                or key_light.spot_range < 8.0 \
                or key_light.spot_range > 8.5 \
                or key_light.shadow_normal_bias > 0.18 \
                or key_light.shadow_blur > 0.6 \
                or key_light.shadow_opacity < 0.99 \
                or key_light.distance_fade_shadow < 27.0 \
                or not key_light.distance_fade_enabled:
            _fail("Table lights must create real, local, budgeted shadows")
            return
    var gaming := hall.get_node_or_null("GamingTables") as Node3D
    if gaming == null:
        _fail("Casino tables are missing")
        return
    # The scene may auto-rename duplicate generated nodes. Match each
    # light to the closest actual table by position, not a hardcoded name.
    for light_node in table_spots:
        var key_light := light_node as SpotLight3D
        var nearest_table: Node3D = null
        var nearest_distance := INF
        for table_node in gaming.get_children():
            var table := table_node as Node3D
            if table == null or not (table.name.begins_with("Roulette") \
                    or table.name.begins_with("Blackjack") \
                    or table.name.begins_with("Cards")):
                continue
            var horizontal := Vector2(
                key_light.position.x - table.position.x,
                key_light.position.z - table.position.z)
            if horizontal.length() < nearest_distance:
                nearest_distance = horizontal.length()
                nearest_table = table
        if nearest_table == null or nearest_distance > 2.1:
            var names := PackedStringArray()
            for table_node in gaming.get_children():
                var t := table_node as Node3D
                if t != null:
                    names.append("%s:%s" % [t.name, t.position])
            _fail("Shadow key %s at %s not near any playable table (distance %s). Actual table positions: %s" % [
                key_light.name, key_light.position, nearest_distance,
                ", ".join(names)
            ])
            return
        var aisle_offset: float = key_light.position.z - nearest_table.position.z
        if absf(aisle_offset) < 1.2:
            _fail("Table key must rake in from the aisle, not overhead")
            return
    for table_node in gaming.get_children():
        if not (table_node.name.begins_with("Roulette") \
                or table_node.name.begins_with("Blackjack") \
                or table_node.name.begins_with("Cards")):
            continue
        var shadow_caster := table_node.get_node_or_null("TableSupport") as MeshInstance3D
        if shadow_caster == null or shadow_caster.cast_shadow != \
                GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
            _fail("Table geometry does not cast real shadows")
            return

    if not atmosphere.find_children(
            "NeonWallWash_*", "SpotLight3D", false, false).is_empty():
        _fail("Old round neon wall spotlight cones returned")
        return
    var strip_fills := atmosphere.find_children(
        "NeonStripFill_*", "OmniLight3D", false, false)
    if strip_fills.size() != 30:
        _fail("Need a continuous, budgeted strip-light fallback")
        return
    var rig := hall.get_node_or_null("VoxelGIRig") as Node3D
    if rig == null:
        _fail("Missing GI rig for mutual-exclusion lighting check")
        return
    var gi_active := false
    for volume in rig.get_children():
        if volume is VoxelGI and volume.visible:
            gi_active = true
    for strip in strip_fills:
        var light := strip as OmniLight3D
        if light == null or light.shadow_enabled or light.omni_range > 3.6 \
                or not light.distance_fade_enabled \
                or light.visible == gi_active:
            _fail("Strip fallback must be inexpensive and off when GI is on")
            return
    var furniture_fills := atmosphere.find_children(
        "FurnitureFill_*", "OmniLight3D", false, false)
    if furniture_fills.size() != 23:
        _fail("Need local lower-floor, gaming wall and bar furniture readability")
        return
    for fill in furniture_fills:
        var light := fill as OmniLight3D
        if light == null or light.shadow_enabled or light.light_energy > 0.4 \
                or light.omni_range > 4.9 \
                or light.light_volumetric_fog_energy > 0.0 \
                or not light.distance_fade_enabled:
            _fail("Furniture fill must stay gentle and cheap")
            return
    for sign_name in ["BarSignSpill", "EntrySignSpill"]:
        var sign_light := atmosphere.get_node_or_null(sign_name) as OmniLight3D
        if sign_light == null or sign_light.light_energy <= 0.4 \
                or sign_light.shadow_enabled:
            _fail("Glowing signage must illuminate the nearby wall: " + sign_name)
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
    if bright < 4 or shadows < 4:
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
