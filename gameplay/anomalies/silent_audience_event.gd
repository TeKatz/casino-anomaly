extends Node3D
## Major event 33: a room-local, rigged, silent crowd. No AI, movement,
## colliders or gameplay modifications. Every new node belongs to this root.
const MODEL_PATH := "res://models/croupier/scene.gltf"
const STOOL := preload("res://models/casino_furniture/gaming_stool.tscn")
const SUIT_SHADER := preload("res://gameplay/anomalies/silent_audience_suit.gdshader")
const Pose = preload("res://gameplay/anomalies/silent_audience_pose.gd")
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
var finish_after := 0.0
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
    # Two separate people fit on each broad sofa. The bar is deliberately
    # sparse: no more shoulder-to-shoulder identical heads in a single row.
    for i in range(1, 6):
        var sofa := hall.get_node_or_null("ModelInteriors/LoungeSofa_%02d" % i) as Node3D
        _seat_from_prop(sofa,true,0.0,-0.46)
        _seat_from_prop(sofa,true,0.0,0.46)
    for i in [1,3,5,7]:
        _seat_from_prop(hall.get_node_or_null("ModelInteriors/CounterStool_%02d" % i) as Node3D,false,PI)
    for i in [1,3]:
        _seat_from_prop(hall.get_node_or_null("ModelInteriors/SideStool_%02d" % i) as Node3D,false,PI*0.5)
    for x in [-13.6,-20.3,-27.2,-41.1]:
        _extra_stool(Vector3(x,0.005,-8.68),PI)
    if hall.has_node("SketchfabFurniture/EditableImportedModels/RetroSlotHero"):
        _extra_stool(Vector3(3.55,0.005,10.40),PI*0.5)

func _seat_from_prop(prop: Node3D, is_sofa: bool, facing: float,
        lateral: float = 0.0) -> void:
    if prop == null or not prop.visible:
        return
    var cushion: MeshInstance3D
    if not is_sofa:
        cushion = prop.find_child("SoftSeatCrown",true,false) as MeshInstance3D
    if cushion == null:
        for item in prop.find_children("*","MeshInstance3D",true,false):
            if str(item.name).to_lower().contains("seat"):
                cushion = item as MeshInstance3D
                break
    if cushion == null or cushion.mesh == null:
        return
    var bounds := (prop.global_transform.affine_inverse()*cushion.global_transform)*cushion.get_aabb()
    var center := bounds.get_center()
    var hip := Vector3(center.x+lateral,bounds.end.y+0.10,center.z-(0.10 if is_sofa else 0.0))
    var yaw := facing
    if is_sofa:
        var basis := (hall.global_transform.affine_inverse()*prop.global_transform).basis.orthonormalized()
        yaw = basis.get_euler().y + lateral * 0.18
    seats.append({"anchor":to_local(prop.to_global(hip)),"yaw":yaw,
        "kind":"sofa" if is_sofa else "bar"})

func _extra_stool(at: Vector3, yaw: float) -> void:
    seats.append({"anchor": at + Vector3(0, 0.73, 0), "yaw": yaw,
        "kind": "extra_stool", "stool_at": at})


func _read_settings() -> void:
    var settings := get_node_or_null("/root/GameSettings")
    reduced_motion = settings != null and bool(settings.call("get_option", "reduced_motion"))


func _unseen(camera: Camera3D, player: CollisionObject3D, seat: Dictionary) -> bool:
    var head := hall.to_global((seat["anchor"] as Vector3)+Vector3(0,0.65,0))
    # Keep a clear space around the actual player for the initial appearance.
    if camera.global_position.distance_to(head)<1.75:
        return false
    if camera.is_position_behind(head):
        return true
    var point := camera.unproject_position(head)
    var size := camera.get_viewport().get_visible_rect().size
    if point.x < -80.0 or point.y < -80.0 or point.x > size.x + 80.0 or point.y > size.y + 80.0:
        return true
    var query := PhysicsRayQueryParameters3D.create(camera.global_position,head)
    query.exclude = [player.get_rid()]
    var hit := hall.get_world_3d().direct_space_state.intersect_ray(query)
    return not hit.is_empty() and (hit["position"] as Vector3).distance_to(head)>0.22

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


func _seated_performance(figure: Node3D, animator: AnimationPlayer,
        sitting: String, seed: int) -> AnimationTree:
    var speech := _find_clip(animator,"cycle_talking")
    if speech.is_empty():
        return null
    var seated := animator.get_animation(sitting)
    var talking := animator.get_animation(speech)
    seated.loop_mode = Animation.LOOP_LINEAR
    talking.loop_mode = Animation.LOOP_LINEAR
    var idle_node := AnimationNodeAnimation.new()
    idle_node.animation = sitting
    var speech_node := AnimationNodeAnimation.new()
    speech_node.animation = speech
    var speech_blend := AnimationNodeBlend2.new()
    speech_blend.filter_enabled = true
    speech_blend.sync = true
    var facial_tracks := 0
    for i in range(talking.get_track_count()):
        var path := talking.track_get_path(i)
        var lower := str(path).to_lower()
        for part in ["lower_lip_","upper_lip_","jaw_","tongue_"]:
            if lower.contains(part):
                speech_blend.set_filter_path(path,true)
                facial_tracks += 1
                break
    if facial_tracks < 5:
        return null
    var time_seek := AnimationNodeTimeSeek.new()
    var rate := AnimationNodeTimeScale.new()
    var graph := AnimationNodeBlendTree.new()
    graph.add_node("Seated",idle_node,Vector2(0,0))
    graph.add_node("SeatTime",time_seek,Vector2(170,0))
    graph.add_node("SeatRate",rate,Vector2(320,0))
    graph.add_node("Mouth",speech_node,Vector2(160,170))
    graph.add_node("SilentSpeech",speech_blend,Vector2(480,90))
    graph.connect_node("SeatTime",0,"Seated")
    graph.connect_node("SeatRate",0,"SeatTime")
    graph.connect_node("SilentSpeech",0,"SeatRate")
    graph.connect_node("SilentSpeech",1,"Mouth")
    graph.connect_node("output",0,"SilentSpeech")
    var tree := AnimationTree.new()
    tree.name = "IndividualBehavior"
    figure.add_child(tree)
    tree.anim_player = tree.get_path_to(animator)
    tree.tree_root = graph
    tree.active = true
    tree.set("parameters/SeatRate/scale",0.70+float(seed%7)*0.082)
    tree.set("parameters/SeatTime/seek_request",float((seed*37)%83)*0.1)
    tree.set("parameters/SilentSpeech/blend_amount",0.0)
    return tree

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
    var seat: Dictionary = seats[index]
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
    var variant := guests.size()
    figure.name = "AudienceMember_%02d" % variant
    figure.hide()
    add_child(figure)
    var broadness := 0.90+float((variant*11)%13)*0.018
    var height := 0.955+float((variant*7)%11)*0.011
    figure.scale = Vector3(1.88*broadness,1.12*height,1.84*broadness)
    figure.rotation.y = float(seat["yaw"])
    var animator: AnimationPlayer
    var sitting := ""
    var standing := ""
    for item in figure.find_children("*","AnimationPlayer",true,false):
        var candidate := item as AnimationPlayer
        var idle_clip := _find_clip(candidate,"sitting_idle")
        var stand_clip := _find_clip(candidate,"sitting_end")
        if not idle_clip.is_empty() and not stand_clip.is_empty():
            animator = candidate
            sitting = idle_clip
            standing = stand_clip
            break
    var skeleton: Skeleton3D
    var hip_index := -1
    for item in figure.find_children("*","Skeleton3D",true,false):
        var candidate := item as Skeleton3D
        var idx := candidate.find_bone("Hips_01")
        if idx >= 0 and candidate.find_bone("Head_06") >= 0:
            skeleton = candidate
            hip_index = idx
            break
    if animator == null or skeleton == null:
        figure.free()
        if is_instance_valid(stool):
            stool.free()
        return false
    animator.play(sitting)
    animator.seek(0.45+float(variant%6)*0.88,true)
    animator.pause()
    skeleton.force_update_all_bone_transforms()
    var local_hip := to_local(skeleton.to_global(skeleton.get_bone_global_pose(hip_index).origin))
    figure.position += (seat["anchor"] as Vector3)-local_hip
    _appearance(figure,variant)
    _head_details(skeleton,variant)
    var tree := _seated_performance(figure,animator,sitting,variant)
    var collider := _make_collision(seat["anchor"] as Vector3,variant)
    if is_instance_valid(stool):
        stool.show()
    figure.show()
    var head := skeleton.find_bone("Head_06")
    var chest := skeleton.find_bone("Chest_04")
    guests.append({"figure":figure,"animator":animator,"tree":tree,"stand_clip":standing,
        "skeleton":skeleton,"head":head,"chest":chest,"hip":hip_index,
        "base_head":skeleton.get_bone_pose_rotation(head),
        "base_chest":skeleton.get_bone_pose_rotation(chest) if chest>=0 else Quaternion.IDENTITY,
        "yaw":0.0,"appeared":elapsed,"kind":seat["kind"],
        "anchor":seat["anchor"],"seat_yaw":seat["yaw"],"collider":collider,
        "personality":variant%3,"posture":float((variant*7)%11)*0.007,
        "speech_phase":float(variant)*2.197,"standing":false,"blocked":false,
        "start_pos":figure.position,"target_pos":figure.position,
        "sit_pose":[],"upright_pose":[],"stand_duration":5.8,
        "stand_delay":0.0})
    seats.remove_at(index)
    last_appearance = elapsed
    return true


func _make_collision(anchor: Vector3, variant: int) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = "AudienceCollision_%02d" % variant
    body.collision_layer = 1
    body.collision_mask = 0
    add_child(body)
    body.position = Vector3(anchor.x,0.0,anchor.z)
    var shape_node := CollisionShape3D.new()
    shape_node.name = "Torso"
    body.add_child(shape_node)
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.285
    capsule.height = 1.30
    shape_node.shape = capsule
    shape_node.position.y = 1.15
    return body

func _appearance(figure: Node3D, index: int) -> void:
    # The glTF separates the business suit and human skin into skinned
    # meshes. The licensed, textured face remains completely unobscured.
    var cloth := [
        Color("#404b5a"),Color("#57443f"),Color("#4c5148"),Color("#474156"),
        Color("#666055"),Color("#313b47"),Color("#69554c"),Color("#344b4e"),
        Color("#69565e"),Color("#56534a")
    ]
    var skin := [
        Color(1.0,0.94,0.88),Color(0.89,0.81,0.75),Color(0.98,0.83,0.72),
        Color(0.82,0.72,0.67),Color(0.93,0.89,0.81),Color(0.87,0.79,0.71)
    ]
    for item in figure.find_children("*","MeshInstance3D",true,false):
        var mesh := item as MeshInstance3D
        if mesh.mesh == null:
            continue
        mesh.material_overlay = null
        mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        var is_suit := str(mesh.name).to_lower().contains("suit")
        var is_skin := str(mesh.name).to_lower().contains("body")
        for surface in range(mesh.mesh.get_surface_count()):
            var original := mesh.get_active_material(surface) as StandardMaterial3D
            if original == null:
                continue
            if is_suit and original.albedo_texture != null:
                var jacket := ShaderMaterial.new()
                jacket.shader = SUIT_SHADER
                jacket.set_shader_parameter("atlas",original.albedo_texture)
                jacket.set_shader_parameter("jacket",cloth[index%cloth.size()])
                jacket.set_shader_parameter("fabric_grain",0.018+float(index%4)*0.008)
                mesh.set_surface_override_material(surface,jacket)
            else:
                var modified := original.duplicate() as StandardMaterial3D
                modified.albedo_color *= skin[index%skin.size()] if is_skin else Color(0.91,0.90,0.89)
                modified.roughness = 0.69
                modified.emission_enabled = false
                mesh.set_surface_override_material(surface,modified)


func _head_details(skeleton: Skeleton3D, index: int) -> void:
    # Rig-attached discreet hair/glasses distinguish faces even when two
    # guests wear the same suit. These follow the original head bone.
    var head := skeleton.find_bone("Head_06")
    if head < 0:
        return
    var style := index%6
    if style in [0,4]:
        return
    var attachment := BoneAttachment3D.new()
    attachment.name = "PersonalDetail"
    attachment.bone_name = "Head_06"
    skeleton.add_child(attachment)
    var dark := StandardMaterial3D.new()
    dark.albedo_color = [Color("#241e1b"),Color("#46403a"),Color("#352926")][index%3]
    dark.roughness = 0.95
    if style in [1,5]:
        # Sleek, low-profile spectacles rather than a dark silhouette.
        var metal := StandardMaterial3D.new()
        metal.albedo_color = Color("#928b7a") if style==1 else Color("#37383d")
        metal.metallic = 0.55
        metal.roughness = 0.44
        for side in [-1.0,1.0]:
            var rim := MeshInstance3D.new()
            rim.name = "SpectacleRim"
            var torus := TorusMesh.new()
            torus.inner_radius = 0.041
            torus.outer_radius = 0.045
            torus.ring_segments = 6
            torus.rings = 24
            rim.mesh = torus
            rim.material_override = metal
            attachment.add_child(rim)
            rim.rotation.x = PI*0.5
            rim.position = Vector3(side*0.047,0.082,0.115)
        var bridge := MeshInstance3D.new()
        bridge.name = "SpectacleBridge"
        var bridge_mesh := BoxMesh.new()
        bridge_mesh.size = Vector3(0.024,0.006,0.008)
        bridge.mesh = bridge_mesh
        bridge.material_override = metal
        attachment.add_child(bridge)
        bridge.position = Vector3(0.0,0.080,0.117)
    elif style in [2,3]:
        var hair := MeshInstance3D.new()
        hair.name = "DistinctHairline"
        var crown := SphereMesh.new()
        crown.radius = 0.096
        crown.height = 0.19
        crown.radial_segments = 16
        crown.rings = 8
        hair.mesh = crown
        hair.material_override = dark
        attachment.add_child(hair)
        hair.position = Vector3(0,0.172,0.006)
        hair.scale = Vector3(0.95,0.37,0.83) if style==2 else Vector3(1.0,0.47,0.74)

func _watch(delta: float, player: Node3D) -> void:
    for person in guests:
        var rig := person["skeleton"] as Skeleton3D
        var figure := person["figure"] as Node3D
        var head := int(person["head"])
        var chest := int(person["chest"])
        var duration := elapsed-float(person["appeared"])
        var phase := float(person["speech_phase"])
        var desired := 0.0
        if not reduced_motion and duration>6.5:
            var toward := figure.to_local(player.global_position)
            if toward.length()<20.0:
                # Never snap to the player. Individuals don't all stare:
                # some turn toward their neighbour or toward the table.
                var attention: float = [0.85,0.0,0.50,0.95,0.2][int(phase*10.0)%5]
                desired = clampf(atan2(toward.x,toward.z),-0.62,0.62)*attention
        var yaw := move_toward(float(person["yaw"]),desired,delta*HEAD_SPEED)
        person["yaw"] = yaw
        var id := int(person["personality"])
        var lean := (float(person["posture"])-0.035) * (1.0 if id==0 else -0.7)
        rig.set_bone_pose_rotation(head,
            (person["base_head"] as Quaternion) * Quaternion(Vector3.UP,yaw))
        if chest>=0:
            var breath := 0.0 if reduced_motion else sin(elapsed*(0.39+float(id)*0.09)+phase)*0.009
            rig.set_bone_pose_rotation(chest,
                (person["base_chest"] as Quaternion) * Quaternion(Vector3.RIGHT,lean+breath))
        var tree := person["tree"] as AnimationTree
        if tree != null:
            var talking := not reduced_motion and duration>4.0 and (int(phase)%4 in [0,2])
            var window := sin(elapsed*(0.51+float(id)*0.11)+phase)
            tree.set("parameters/SilentSpeech/blend_amount",0.88 if talking and window>0.05 else 0.0)


func _find_landing(person: Dictionary) -> Dictionary:
    # Search only the open floor in front of each seat. For bar stools
    # 'forward' points through the counter, so step back toward the aisle.
    var anchor: Vector3 = person["anchor"]
    var facing := Basis(Vector3.UP,float(person["seat_yaw"]))
    var forward: Vector3 = facing*Vector3(0,0,1 if person["kind"]=="sofa" else -1)
    var side: Vector3 = facing*Vector3.RIGHT
    var space := hall.get_world_3d().direct_space_state
    var body := person["collider"] as StaticBody3D
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.29
    capsule.height = 1.74
    for reach in [0.68,0.94,1.12,0.48]:
        for sidestep in [0.0,-0.24,0.24,-0.44,0.44]:
            var candidate: Vector3 = anchor+forward*reach+side*sidestep
            var from := hall.to_global(Vector3(candidate.x,2.35,candidate.z))
            var below := hall.to_global(Vector3(candidate.x,-0.45,candidate.z))
            var floor_query := PhysicsRayQueryParameters3D.create(from,below)
            floor_query.exclude = [body.get_rid()]
            var floor_hit := space.intersect_ray(floor_query)
            if floor_hit.is_empty():
                continue
            var floor_y := hall.to_local(floor_hit["position"] as Vector3).y
            if floor_y < -0.20 or floor_y > 0.18:
                continue
            var shape_query := PhysicsShapeQueryParameters3D.new()
            shape_query.shape = capsule
            shape_query.collision_mask = 1
            shape_query.exclude = [body.get_rid()]
            shape_query.transform = Transform3D(hall.global_transform.basis.orthonormalized(),
                hall.to_global(Vector3(candidate.x,floor_y+0.98,candidate.z)))
            if space.intersect_shape(shape_query,2).is_empty():
                return {"x":candidate.x,"z":candidate.z,"floor":floor_y}
    return {}


func _stand_together() -> void:
    if finale_started or guests.size()!=target_count:
        return
    finale_started = true
    finale_at = elapsed
    finish_after = 0.0
    for i in range(guests.size()):
        var person: Dictionary = guests[i]
        var figure := person["figure"] as Node3D
        var rig := person["skeleton"] as Skeleton3D
        var animator := person["animator"] as AnimationPlayer
        var tree := person["tree"] as AnimationTree
        if tree != null:
            tree.active = false
        var seated := Pose.snapshot(rig)
        # Sample a genuine upright pose from the same rig; this avoids
        # the imported sitting_end clip's unbounded forward/root movement.
        var idle := _find_clip(animator,"Rig|idle")
        if idle.is_empty():
            idle = _find_clip(animator,"idle")
        if idle.is_empty():
            person["blocked"] = true
            continue
        animator.play(idle)
        animator.seek(0.3+float(i%5)*0.35,true)
        animator.pause()
        rig.force_update_all_bone_transforms()
        var upright := Pose.snapshot(rig)
        var foot_y := INF
        for foot_name in ["Foot_L_065","Foot_R_069"]:
            var bone_id := rig.find_bone(foot_name)
            if bone_id>=0:
                foot_y = minf(foot_y,hall.to_local(rig.to_global(rig.get_bone_global_pose(bone_id).origin)).y)
        animator.stop()
        Pose.restore(rig,seated)
        var landing := _find_landing(person)
        if landing.is_empty() or not is_finite(foot_y):
            person["blocked"] = true
            continue
        person["sit_pose"] = seated
        person["upright_pose"] = upright
        person["start_pos"] = figure.position
        person["target_pos"] = figure.position+Vector3(
            float(landing["x"])-(person["anchor"] as Vector3).x,
            float(landing["floor"])+0.095-foot_y,
            float(landing["z"])-(person["anchor"] as Vector3).z)
        person["stand_duration"] = 4.3+float((i*7)%8)*0.37
        person["stand_delay"] = float((i*3)%7)*0.075
        person["standing"] = true
        finish_after = maxf(finish_after,float(person["stand_duration"])+float(person["stand_delay"]))
    finish_after += 0.2


func _advance_standing() -> void:
    if not finale_started or finale_frozen:
        return
    var time := elapsed-finale_at
    for person in guests:
        if not bool(person["standing"]):
            continue
        var figure := person["figure"] as Node3D
        var rig := person["skeleton"] as Skeleton3D
        var body := person["collider"] as StaticBody3D
        var rate := clampf((time-float(person["stand_delay"]))/
            float(person["stand_duration"]),0.0,1.0)
        var phase := smoothstep(0.0,1.0,rate)
        # First step clear of the chair/counter, then rise to standing.
        var outward := smoothstep(0.0,0.43,rate)
        var start: Vector3 = person["start_pos"]
        var destination: Vector3 = person["target_pos"]
        figure.position = Vector3(lerpf(start.x,destination.x,outward),
            lerpf(start.y,destination.y,phase),lerpf(start.z,destination.z,outward))
        Pose.blend(rig,person["sit_pose"],person["upright_pose"],
            phase,int(person["personality"]))
        var anchor: Vector3 = person["anchor"]
        var new_origin := Vector3(anchor.x,0.0,anchor.z).lerp(
            Vector3(anchor.x+destination.x-start.x,0.0,anchor.z+destination.z-start.z),outward)
        body.position = new_origin
        var shape := body.get_node("Torso") as CollisionShape3D
        if shape != null:
            shape.position.y = lerpf(1.15,0.97,phase)
            var capsule := shape.shape as CapsuleShape3D
            capsule.height = lerpf(1.30,1.74,phase)


func _freeze_finale() -> void:
    if finale_frozen:
        return
    finale_frozen = true
    # A few figures remain seated if the surrounding solid geometry makes
    # a standing landing impossible. They never clip through the counter.
    for person in guests:
        if bool(person["standing"]):
            var body := person["collider"] as StaticBody3D
            if is_instance_valid(body):
                ((body.get_node("Torso") as CollisionShape3D).shape as CapsuleShape3D).height = 1.74

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
    else:
        _advance_standing()
        if not finale_frozen and elapsed-finale_at>=finish_after:
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
