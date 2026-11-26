extends Node3D
## Major event 33: a room-local, rigged, silent crowd. No AI, movement,
## colliders or gameplay modifications. Every new node belongs to this root.
const MODEL_PATH := "res://models/croupier/scene.gltf"
const STOOL := preload("res://models/casino_furniture/gaming_stool.tscn")
const FACE_SHADER := preload("res://gameplay/anomalies/silent_audience_face.gdshader")
const FIRST_APPEARANCE := 5.0
const APPEARANCE_INTERVAL := 2.65
const FINALE_DELAY := 7.0
const MIN_GUESTS := 15
const MAX_GUESTS := 25
const HEAD_SPEED := 0.13

var hall: Node3D
var model: PackedScene
var seats: Array[Dictionary] = []
var guests: Array[Dictionary] = []
var target_count := 0
var elapsed := 0.0
var next_appearance := FIRST_APPEARANCE
var last_appearance := 0.0
var finale_started := false
var finale_at := 0.0
var finale_frozen := false
var configured := false
var reduced_motion := false
var settings_clock := 0.0
var rng := RandomNumberGenerator.new()
var audio_baseline: Dictionary = {}


func configure(room: Node3D) -> bool:
    hall = room
    process_priority = 100
    rng.seed = 33033033
    model = ResourceLoader.load(MODEL_PATH, "PackedScene") as PackedScene
    if model == null:
        return false
    _collect_seats()
    target_count = mini(MAX_GUESTS, seats.size())
    if target_count < MIN_GUESTS:
        push_warning("Silent Audience: only %d suitable seats" % target_count)
        return false
    _read_settings()
    configured = true
    return true


func _collect_seats() -> void:
    # Use the actual saved sofa and stool cushions. With all authored assets,
    # there are twenty locations across the lounge, bar, tables and slots.
    for i in range(1, 6):
        _seat_from_prop(hall.get_node_or_null("ModelInteriors/LoungeSofa_%02d" % i) as Node3D, true, 0.0)
    for i in range(1, 8):
        _seat_from_prop(hall.get_node_or_null("ModelInteriors/CounterStool_%02d" % i) as Node3D, false, PI)
    for i in range(1, 4):
        _seat_from_prop(hall.get_node_or_null("ModelInteriors/SideStool_%02d" % i) as Node3D, false, PI * 0.5)
    # Supplement the actual tables with matching upholstered game stools.
    # The additional stools are cosmetic only and never block the walkway.
    for x in [-13.6, -20.3, -27.2, -41.1]:
        _extra_stool(Vector3(x, 0.005, -8.68), PI)
    if hall.has_node("SketchfabFurniture/EditableImportedModels/RetroSlotHero"):
        _extra_stool(Vector3(3.55, 0.005, 10.40), PI * 0.5)


func _seat_from_prop(prop: Node3D, is_sofa: bool, facing: float) -> void:
    # 'visible' (local) is intentional: staged halls are often hidden
    # wholesale during preloading but their local furniture is valid.
    if prop == null or not prop.visible:
        return
    var cushion: MeshInstance3D
    if not is_sofa:
        cushion = prop.find_child("SoftSeatCrown", true, false) as MeshInstance3D
    if cushion == null:
        for item in prop.find_children("*", "MeshInstance3D", true, false):
            if str(item.name).to_lower().contains("seat"):
                cushion = item as MeshInstance3D
                break
    if cushion == null or cushion.mesh == null:
        return
    var bounds := (prop.global_transform.affine_inverse() * cushion.global_transform) * cushion.get_aabb()
    var center := bounds.get_center()
    var hip := Vector3(center.x, bounds.end.y + 0.10, center.z - (0.10 if is_sofa else 0.0))
    var yaw := facing
    if is_sofa:
        var basis := (hall.global_transform.affine_inverse() * prop.global_transform).basis.orthonormalized()
        yaw = basis.get_euler().y
    seats.append({"anchor": to_local(prop.to_global(hip)), "yaw": yaw,
        "kind": "sofa" if is_sofa else "bar"})


func _extra_stool(at: Vector3, yaw: float) -> void:
    seats.append({"anchor": at + Vector3(0, 0.73, 0), "yaw": yaw,
        "kind": "extra_stool", "stool_at": at})


func _read_settings() -> void:
    var settings := get_node_or_null("/root/GameSettings")
    reduced_motion = settings != null and bool(settings.call("get_option", "reduced_motion"))


func _unseen(camera: Camera3D, player: CollisionObject3D, seat: Dictionary) -> bool:
    var head := hall.to_global((seat["anchor"] as Vector3) + Vector3(0, 0.65, 0))
    if camera.is_position_behind(head):
        return true
    var point := camera.unproject_position(head)
    var size := camera.get_viewport().get_visible_rect().size
    if point.x < -80.0 or point.y < -80.0 or point.x > size.x + 80.0 or point.y > size.y + 80.0:
        return true
    # A visible screen coordinate can be entirely hidden by casino walls.
    var query := PhysicsRayQueryParameters3D.create(camera.global_position, head)
    query.exclude = [player.get_rid()]
    var hit := hall.get_world_3d().direct_space_state.intersect_ray(query)
    return not hit.is_empty() and (hit["position"] as Vector3).distance_to(head) > 0.22


func _pick_unseen(camera: Camera3D, player: CollisionObject3D) -> int:
    var choices: Array[int] = []
    for i in range(seats.size()):
        if _unseen(camera, player, seats[i]):
            choices.append(i)
    if choices.is_empty():
        return -1
    return choices[rng.randi_range(0, choices.size() - 1)]


func _find_clip(animator: AnimationPlayer, fragment: String) -> String:
    for clip in animator.get_animation_list():
        if str(clip).to_lower().contains(fragment):
            return str(clip)
    return ""


func _spawn_stool(at: Vector3) -> Node3D:
    var stool := STOOL.instantiate() as Node3D
    if stool == null:
        return null
    # Strip physics BEFORE inserting the new scenery into the live room.
    for body in stool.find_children("*", "CollisionObject3D", true, false):
        (body as CollisionObject3D).free()
    stool.name = "AudienceStool_%02d" % guests.size()
    add_child(stool)
    stool.position = at
    stool.hide()
    return stool


func _spawn_seat(index: int) -> bool:
    if index < 0 or index >= seats.size() or model == null:
        return false
    var seat := seats[index]
    var stool: Node3D
    if str(seat["kind"]) == "extra_stool":
        stool = _spawn_stool(seat["stool_at"] as Vector3)
        if stool == null:
            return false
    var figure := model.instantiate() as Node3D
    if figure == null:
        if is_instance_valid(stool):
            stool.free()
        return false
    figure.name = "AudienceMember_%02d" % guests.size()
    figure.hide()
    add_child(figure)
    var height_scale := rng.randf_range(0.955, 1.045)
    figure.scale = Vector3(1.88, 1.12, 1.84) * height_scale
    figure.rotation.y = float(seat["yaw"])
    var animator: AnimationPlayer
    var sitting := ""
    var standing := ""
    for item in figure.find_children("*", "AnimationPlayer", true, false):
        var candidate := item as AnimationPlayer
        var idle_clip := _find_clip(candidate, "sitting_idle")
        var stand_clip := _find_clip(candidate, "sitting_end")
        if not idle_clip.is_empty() and not stand_clip.is_empty():
            animator = candidate
            sitting = idle_clip
            standing = stand_clip
            break
    var skeleton: Skeleton3D
    var hip_index := -1
    for item in figure.find_children("*", "Skeleton3D", true, false):
        var candidate := item as Skeleton3D
        var index_in_rig := candidate.find_bone("Hips_01")
        if index_in_rig >= 0 and candidate.find_bone("Head_06") >= 0:
            skeleton = candidate
            hip_index = index_in_rig
            break
    if animator == null or skeleton == null:
        figure.free()
        if is_instance_valid(stool):
            stool.free()
        push_warning("Silent Audience: seated character has no valid rig")
        return false
    animator.play(sitting)
    animator.seek(0.4, true)
    animator.pause()
    skeleton.force_update_all_bone_transforms()
    var old_hip := to_local(skeleton.to_global(skeleton.get_bone_global_pose(hip_index).origin))
    figure.position += (seat["anchor"] as Vector3) - old_hip
    skeleton.force_update_all_bone_transforms()
    var head := skeleton.find_bone("Head_06")
    var chest := skeleton.find_bone("Chest_04")
    var head_y := skeleton.to_global(skeleton.get_bone_global_pose(head).origin).y
    _appearance(figure, head_y - 0.13, guests.size())
    if is_instance_valid(stool):
        stool.show()
    figure.show()
    guests.append({"figure": figure, "animator": animator, "stand_clip": standing,
        "skeleton": skeleton, "head": head, "chest": chest,
        "base_head": skeleton.get_bone_pose_rotation(head),
        "base_chest": skeleton.get_bone_pose_rotation(chest) if chest >= 0 else Quaternion.IDENTITY,
        "yaw": 0.0, "appeared": elapsed, "kind": seat["kind"]})
    seats.remove_at(index)
    last_appearance = elapsed
    return true


func _appearance(figure: Node3D, cutoff: float, index: int) -> void:
    # The source's real suit/skin textures are retained; only per-instance
    # material overrides are adjusted. One shared face shader for all rigs.
    var palette := [Color(0.43, 0.45, 0.50), Color(0.50, 0.43, 0.42),
        Color(0.39, 0.45, 0.47), Color(0.49, 0.48, 0.40), Color(0.43, 0.40, 0.48)]
    var tint: Color = palette[index % palette.size()]
    var mask := ShaderMaterial.new()
    mask.shader = FACE_SHADER
    mask.set_shader_parameter("cutoff", cutoff)
    for item in figure.find_children("*", "MeshInstance3D", true, false):
        var mesh := item as MeshInstance3D
        if mesh.mesh == null:
            continue
        mesh.material_overlay = mask
        mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        for i in range(mesh.mesh.get_surface_count()):
            var original := mesh.get_active_material(i) as StandardMaterial3D
            if original == null:
                continue
            var dark := original.duplicate() as StandardMaterial3D
            dark.albedo_color *= tint
            dark.roughness = 0.83
            dark.metallic = 0.0
            dark.metallic_specular = 0.16
            dark.emission_enabled = false
            mesh.set_surface_override_material(i, dark)


func _watch(delta: float, player: Node3D) -> void:
    for person in guests:
        var rig := person["skeleton"] as Skeleton3D
        var body := person["figure"] as Node3D
        var head := int(person["head"])
        var chest := int(person["chest"])
        var desired := 0.0
        if not reduced_motion and elapsed - float(person["appeared"]) > 6.5:
            var toward := body.to_local(player.global_position)
            if toward.length() < 20.0:
                desired = clampf(atan2(toward.x, toward.z), -0.68, 0.68)
        var yaw := move_toward(float(person["yaw"]), desired, delta * HEAD_SPEED)
        person["yaw"] = yaw
        rig.set_bone_pose_rotation(head, (person["base_head"] as Quaternion) * Quaternion(Vector3.UP, yaw))
        if chest >= 0:
            var synchronized := 0.0 if reduced_motion else sin(elapsed * 0.52) * 0.012
            rig.set_bone_pose_rotation(chest, (person["base_chest"] as Quaternion) * Quaternion(Vector3.RIGHT, synchronized))


func _stand_together() -> void:
    if finale_started or guests.size() != target_count:
        return
    finale_started = true
    finale_at = elapsed
    for person in guests:
        var animator := person["animator"] as AnimationPlayer
        # Same-frame, six-second stand-up. No pursuit and no interaction.
        animator.play(str(person["stand_clip"]), 0.45)


func _freeze_finale() -> void:
    if finale_frozen:
        return
    finale_frozen = true
    for person in guests:
        var animator := person["animator"] as AnimationPlayer
        var clip := str(person["stand_clip"])
        if animator.has_animation(clip):
            animator.seek(animator.get_animation(clip).length, true)
            animator.pause()


func _silence(weight: float) -> void:
    var director := get_node_or_null("/root/AudioDirector")
    if director != null:
        var room_tone := director.get("room_player") as AudioStreamPlayer
        if room_tone != null and room_tone.playing:
            if not audio_baseline.has(room_tone):
                audio_baseline[room_tone] = room_tone.volume_db
            room_tone.volume_db = lerpf(float(audio_baseline[room_tone]), -58.0, weight)
    var soundscape := hall.get_node_or_null("RoomSoundscape")
    if soundscape == null:
        return
    var sources: Array = soundscape.get("_sources")
    var levels: Array = soundscape.get("_target_db")
    for i in range(mini(sources.size(), levels.size())):
        var emitter := sources[i] as AudioStreamPlayer3D
        if emitter == null or not emitter.playing:
            continue
        if not audio_baseline.has(emitter):
            audio_baseline[emitter] = levels[i]
        emitter.volume_db = lerpf(float(audio_baseline[emitter]), -58.0, weight)


func _restore_audio() -> void:
    for source in audio_baseline:
        if is_instance_valid(source):
            source.volume_db = audio_baseline[source]
    audio_baseline.clear()


func _process(delta: float) -> void:
    if not configured or not is_instance_valid(hall) or hall.has_meta("_streaming_standby"):
        return
    var player := hall.get_node_or_null("Player") as CollisionObject3D
    if player == null:
        return
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    if camera == null:
        return
    elapsed += delta
    settings_clock += delta
    if settings_clock >= 0.8:
        settings_clock = 0.0
        _read_settings()
    if not finale_started:
        if guests.size() < target_count and elapsed >= next_appearance:
            var unseen_index := _pick_unseen(camera, player)
            if unseen_index >= 0 and _spawn_seat(unseen_index):
                next_appearance = elapsed + APPEARANCE_INTERVAL + rng.randf_range(-0.30, 0.45)
            else:
                # Never pop an actor directly into the player's view.
                next_appearance = elapsed + 0.35
        _watch(delta, player)
        if guests.size() == target_count and elapsed - last_appearance >= FINALE_DELAY:
            _stand_together()
    elif not finale_frozen and elapsed - finale_at >= 6.25:
        _freeze_finale()
    _silence(smoothstep(0.08, 0.98, float(guests.size()) / float(maxi(1, target_count))))


func _exit_tree() -> void:
    _restore_audio()
    # Stop the imported animation rigs and detach their custom materials
    # before freeing the skinned MeshInstance3D children. With Forward+
    # this also avoids stale per-instance material RIDs on teardown; the
    # dummy renderer used in headless QA is particularly strict about them.
    for person in guests:
        var animator := person["animator"] as AnimationPlayer
        if is_instance_valid(animator):
            animator.stop()
        var figure := person["figure"] as Node3D
        if not is_instance_valid(figure):
            continue
        for item in figure.find_children("*", "MeshInstance3D", true, false):
            var mesh := item as MeshInstance3D
            mesh.material_overlay = null
            for surface in range(mesh.mesh.get_surface_count() if mesh.mesh != null else 0):
                mesh.set_surface_override_material(surface, null)
    guests.clear()
