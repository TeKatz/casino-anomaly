extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://main.tscn")
    if packed == null:
        push_error("Casino scene missing")
        quit(1)
        return
    var hall: Node3D = packed.instantiate() as Node3D
    root.add_child(hall)
    await process_frame
    await process_frame
    var fx: Node3D = hall.get_node_or_null("CasinoAtmosphere") as Node3D
    var env: WorldEnvironment = hall.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if fx == null or env == null or env.environment == null or not env.environment.glow_enabled:
        push_error("Missing visual environment")
        quit(1)
        return
    if not fx.has_node("EntrySignTop") or not fx.has_node("BarSignTop"):
        push_error("Missing luminous casino signage")
        quit(1)
        return
    # The room is editable: artist-removed or artist-added spotlights
    # are valid. Check only runaway counts and broken light resources.
    var all_spots := fx.find_children("*", "SpotLight3D", true, false)
    var display_spots: Array[Node] = []
    for spot in all_spots:
        if not spot.name.begins_with("TableKey_"):
            display_spots.append(spot)
    if display_spots.size() > 16 or all_spots.size() > 45:
        push_error("Casino spotlight budgets exceeded")
        quit(1)
        return
    for spot in display_spots:
        if spot.light_energy < 0.0 or spot.spot_range <= 0.0:
            push_error("Invalid configured display spotlight: " + spot.name)
            quit(1)
            return
    var spill_count := fx.find_children("SlotSpill*", "OmniLight3D", true, false).size()
    if spill_count < 4 or spill_count > 6:
        push_error("Screen spill light budget exceeded")
        quit(1)
        return
    for light in fx.find_children("SlotSpill*", "OmniLight3D", true, false):
        if light.light_volumetric_fog_energy != 0.0:
            push_error("Animated slot spill must not cause fog ghosting")
            quit(1)
            return
    if fx.find_children("*", "CollisionObject3D", true, false).size() != 0:
        push_error("Decorative FX may not add collisions")
        quit(1)
        return
    if ProjectSettings.get_setting("rendering/renderer/rendering_method") != "forward_plus":
        push_error("Casino Anomaly must use the Forward+ renderer")
        quit(1)
        return
    if not env.environment.fog_enabled or env.environment.fog_density <= 0.0:
        push_error("Casino depth fog is missing")
        quit(1)
        return
    if not env.environment.volumetric_fog_enabled:
        push_error("Forward+ volume scattering is disabled")
        quit(1)
        return
    # Artist-controlled denser casino fog reinforces the oppressive
    # atmosphere. Ensure scattering remains bounded without locking the
    # room to its original low-density appearance.
    if env.environment.volumetric_fog_density <= 0.0 or env.environment.volumetric_fog_density > 0.045:
        push_error("Volumetric fog is outside the supported atmosphere range")
        quit(1)
        return
    if not env.environment.ssao_enabled:
        push_error("Forward+ screen-space contact occlusion is disabled")
        quit(1)
        return
    if env.environment.ambient_light_energy > 0.50:
        push_error("Excessive ambient fill would erase visible shadows")
        quit(1)
        return
    var hall_lights: Node3D = hall.get_node_or_null("Lighting") as Node3D
    if hall_lights == null:
        push_error("Main ceiling light collection missing")
        quit(1)
        return
    # Authored light count / shadow toggles are level design choices.
    # Require a nonempty and bounded lighting collection instead of 9/8.
    var main_lights := 0
    var enabled_lights := 0
    for item in hall_lights.get_children():
        var bulb := item as OmniLight3D
        if bulb == null:
            continue
        main_lights += 1
        if bulb.visible and bulb.light_energy > 0.0:
            enabled_lights += 1
    if main_lights < 1 or main_lights > 24 or enabled_lights < 1:
        push_error("Casino must retain usable main lighting (count=%d, enabled=%d)" % [main_lights, enabled_lights])
        quit(1)
        return
    for item in hall_lights.get_children():
        var lamp := item as OmniLight3D
        if lamp != null and lamp.shadow_enabled and lamp.light_volumetric_fog_energy <= 0.0:
            push_error("Shadow-casting chandeliers need volumetric scattering")
            quit(1)
            return
    # Ambient dust stays fine and spans the full casino instead of
    # concentrating in visible clumps beneath the chandeliers.
    var dust_emitters := fx.find_children("AmbientDust_*", "CPUParticles3D", false, false)
    if dust_emitters.size() != 12:
        push_error("Fine dust must cover both casino wings in twelve zones")
        quit(1)
        return
    for motes in dust_emitters:
        if motes.amount < 18 or motes.amount > 26:
            push_error("Fine dust particle budget exceeded")
            quit(1)
            return
        var dust_mesh: SphereMesh = motes.mesh as SphereMesh
        if dust_mesh == null or dust_mesh.radius > 0.008:
            push_error("Dust motes must be smaller than the old placeholder spheres")
            quit(1)
            return
    # White wall globes and their bright unshadowed lights must both vanish.
    var decor: Node3D = hall.get_node_or_null("Decor") as Node3D
    if decor == null or decor.find_children("WallSconce", "MeshInstance3D", false, false).size() != 0:
        push_error("Floating white wall globes must be removed")
        quit(1)
        return
    if env.environment.ambient_light_energy > 0.38:
        push_error("Casino should be darker than the previous forward+ pass")
        quit(1)
        return
    var player: CharacterBody3D = hall.get_node_or_null("Player") as CharacterBody3D
    var camera: Camera3D = hall.get_node_or_null("Player/Camera3D") as Camera3D
    if player == null or camera == null:
        push_error("Player or camera missing")
        quit(1)
        return
    if not bool(player.get("camera_motion_enabled")):
        push_error("Camera breathing should be available by default")
        quit(1)
        return
    var before := camera.position
    player.call("_process", 0.50)
    if camera.position.distance_to(before) < 0.0001:
        push_error("Idle breathing has no camera effect")
        quit(1)
        return
    player.set("camera_motion_enabled", false)
    player.call("_process", 0.01)
    if camera.position.distance_to(Vector3(0, 0.55, 0)) > 0.0001:
        push_error("Disabling camera motion must restore the original eye position")
        quit(1)
        return
    print("Casino Anomaly visual FX QA PASS")
    hall.queue_free()
    quit(0)
