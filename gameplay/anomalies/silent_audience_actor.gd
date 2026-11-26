extends Node3D
## Licensed humanoid skeletons use semantic bone roles, not copied root motion.
## Continuous analytic idle movement avoids snapping at animation loop boundaries.
const Pose = preload("res://gameplay/anomalies/silent_audience_pose.gd")
var skeleton: Skeleton3D
var figure: Node3D
var physical: StaticBody3D
var collider: CollisionShape3D
var roles: Dictionary = {}
var standing_pose: Array[Dictionary] = []
var seated_pose: Array[Dictionary] = []
var standing := false
var rising := false
var start_rise_at := 0.0
var rise_duration := 4.0
var stand_y := 0.0
var seat_y := 0.0
var age := 0.0
var variant := 0
var seat_kind := "sofa"
var appearance_id := ""
var visible_player: Node3D

func configure(packed: PackedScene, identifier: String, seat: Dictionary, serial: int) -> bool:
    variant = serial
    appearance_id = identifier
    seat_kind = str(seat["kind"])
    position = seat["anchor"]
    figure = packed.instantiate() as Node3D
    if figure == null:
        return false
    figure.name = "GuestModel"
    add_child(figure)
    figure.rotation.y = float(seat["yaw"])
    for item in figure.find_children("*", "AnimationPlayer", true, false):
        (item as AnimationPlayer).stop()
    for node in figure.find_children("*", "Skeleton3D", true, false):
        if (node as Skeleton3D).get_bone_count() >= 30:
            skeleton = node as Skeleton3D
            break
    if skeleton == null:
        return false
    _resolve_roles()
    for required in ["hip","head","left_thigh","right_thigh","left_calf","right_calf","left_foot","right_foot"]:
        if not roles.has(required):
            var names: Array[String] = []
            for bone in range(skeleton.get_bone_count()):
                names.append(skeleton.get_bone_name(bone))
            push_warning("Audience %s rig missing %s; imported bones: %s" % [identifier,required,str(names)])
            return false
    skeleton.force_update_all_bone_transforms()
    var head := _bone_height("head")
    var low := minf(_bone_height("left_foot"),_bone_height("right_foot"))
    var measured := head-low
    if measured<0.01:
        return false
    var desired := 1.43+0.036*float((serial*5)%9)
    figure.scale = Vector3.ONE*(desired/measured)
    _individual_materials()
    standing_pose = Pose.snapshot(skeleton)
    _sitting_pose()
    seated_pose = Pose.snapshot(skeleton)
    var hip_pos := to_local(skeleton.to_global(skeleton.get_bone_global_pose(int(roles["hip"])).origin))
    figure.position -= hip_pos
    seat_y = figure.position.y
    Pose.restore(skeleton,standing_pose)
    skeleton.force_update_all_bone_transforms()
    var feet := minf(_bone_height("left_foot"),_bone_height("right_foot"))
    stand_y = figure.position.y-(position.y+feet)
    Pose.restore(skeleton,seated_pose)
    figure.position.y = seat_y
    _make_collision()
    return true

func _name_key(name: String) -> String:
    # Godot sanitizes glTF bone names (notably the Mixamo namespace
    # colon). Accept both source names and imported variants.
    var key := name.to_lower().strip_edges()
    if key.begins_with("mixamorig"):
        key = key.trim_prefix("mixamorig").lstrip(":_ .-")
    if key.begins_with("cc_base"):
        key = key.trim_prefix("cc_base").lstrip(":_ .-")
    return key

func _resolve_roles() -> void:
    var pattern := {
        "hip":["hips_","hip_","pelvis_"], "head":["head_"],
        "chest":["chest_","spine2_","spine02_","spine1_"],
        "left_thigh":["leftupleg_","l_thigh_","l_leg_2_","upper_leg_l_"],
        "right_thigh":["rightupleg_","r_thigh_","r_leg_2_","upper_leg_r_"],
        "left_calf":["leftleg_","l_calf_","l_knee_2_","lower_leg_l_"],
        "right_calf":["rightleg_","r_calf_","r_knee_2_","lower_leg_r_"],
        "left_foot":["leftfoot_","l_foot_","foot_l_"],
        "right_foot":["rightfoot_","r_foot_","foot_r_"],
        "left_arm":["leftarm_","l_upperarm_","l_arm_2_","upper_arm_l_"],
        "right_arm":["rightarm_","r_upperarm_","r_arm_2_","upper_arm_r_"],
        "left_forearm":["leftforearm_","l_forearm_","l_elbow_2_","lower_arm_l_"],
        "right_forearm":["rightforearm_","r_forearm_","r_elbow_2_","lower_arm_r_"],
        "jaw":["jaw_","jawroot_"]
    }
    for role in pattern:
        for bone in range(skeleton.get_bone_count()):
            var label := _name_key(skeleton.get_bone_name(bone))
            for prefix in pattern[role]:
                if label.begins_with(str(prefix)):
                    roles[role] = bone
                    break
            if roles.has(role):
                break

func _bone_height(role: String) -> float:
    if not roles.has(role):
        return 0.0
    skeleton.force_update_all_bone_transforms()
    return to_local(skeleton.to_global(skeleton.get_bone_global_pose(int(roles[role])).origin)).y

func _apply_world_hinge(role: String, axis: Vector3, degrees: float) -> void:
    if not roles.has(role):
        return
    var idx := int(roles[role])
    var to_bone := skeleton.get_bone_global_pose(idx).basis.orthonormalized().inverse()
    var local_axis := (to_bone*axis).normalized()
    var original := skeleton.get_bone_pose_rotation(idx)
    skeleton.set_bone_pose_rotation(idx,original*Quaternion(local_axis,deg_to_rad(degrees)))

func _sitting_pose() -> void:
    var id := variant%6
    var lean: float = [-8.0,6.0,-15.0,9.0,-4.0,3.0][id]
    var spread: float = [0.0,5.0,11.0,3.0,-7.0,8.0][id]
    _apply_world_hinge("left_thigh",Vector3.RIGHT,-68.0+spread)
    _apply_world_hinge("right_thigh",Vector3.RIGHT,-70.0-spread*0.65)
    _apply_world_hinge("left_calf",Vector3.RIGHT,75.0-spread*0.5)
    _apply_world_hinge("right_calf",Vector3.RIGHT,80.0+spread*0.3)
    _apply_world_hinge("left_arm",Vector3.RIGHT,12.0+float(id%3)*10.0)
    _apply_world_hinge("right_arm",Vector3.RIGHT,26.0+float((id+1)%3)*7.0)
    _apply_world_hinge("left_forearm",Vector3.RIGHT,-15.0-float(id%2)*12.0)
    _apply_world_hinge("right_forearm",Vector3.RIGHT,-22.0+float(id%3)*4.0)
    _apply_world_hinge("chest",Vector3.RIGHT,lean)
    _apply_world_hinge("head",Vector3.RIGHT,-lean*0.35)
    _apply_world_hinge("head",Vector3.FORWARD,[-5.0,0.0,3.0,-2.0,5.0,0.0][id])
    var hip := int(roles["hip"])
    skeleton.set_bone_pose_position(hip,skeleton.get_bone_pose_position(hip)+Vector3(0,-0.13-float(id%3)*0.025,0))

func _individual_materials() -> void:
    var cloth := [Color("#e0e0db"),Color("#aeb4bf"),Color("#c7b6aa"),
        Color("#c1c0b4"),Color("#b4c0bf"),Color("#d0c3b2")]
    var tint: Color = cloth[variant%cloth.size()]
    for item in figure.find_children("*","MeshInstance3D",true,false):
        var mesh := item as MeshInstance3D
        mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        mesh.material_overlay = null
        for surface in range(mesh.mesh.get_surface_count() if mesh.mesh!=null else 0):
            var original := mesh.get_active_material(surface) as BaseMaterial3D
            if original==null:
                continue
            var material := original.duplicate() as BaseMaterial3D
            var label := str(mesh.name).to_lower()+" "+str(original.resource_name).to_lower()
            if "suit" in label or "outfit" in label or "coat" in label or "shirt" in label or "body_1" in label:
                material.albedo_color *= tint
            material.roughness = maxf(material.roughness,0.48)
            mesh.set_surface_override_material(surface,material)

func _make_collision() -> void:
    physical = StaticBody3D.new()
    physical.name = "GuestBody"
    physical.collision_layer = 1
    physical.collision_mask = 0
    add_child(physical)
    collider = CollisionShape3D.new()
    collider.name = "BodyCapsule"
    physical.add_child(collider)
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.29
    capsule.height = 1.15
    collider.shape = capsule
    collider.position.y = 0.49

func start_standing(offset: float) -> bool:
    # No unobstructed way out of bar chairs: remain seated instead of
    # intersecting the solid counter or translating through the stool.
    if seat_kind!="sofa":
        return false
    start_rise_at = age+offset
    rise_duration = 3.2+float((variant*7)%9)*0.22
    rising = true
    return true

func _process(delta: float) -> void:
    if skeleton==null:
        return
    var parent_room := get_parent().get_parent() as Node3D
    if parent_room!=null and parent_room.has_meta("_streaming_standby"):
        return
    age += delta
    if rising:
        var t := clampf((age-start_rise_at)/rise_duration,0.0,1.0)
        var height_t := smoothstep(0.12,0.91,t)
        # World X/Z never change; skeletal limbs move while hips rise.
        figure.position.y = lerpf(seat_y,stand_y,height_t)
        Pose.blend(skeleton,seated_pose,standing_pose,smoothstep(0.0,1.0,t),variant%3)
        collider.position.y = lerpf(0.49,-position.y+0.87,height_t)
        (collider.shape as CapsuleShape3D).height = lerpf(1.15,1.72,height_t)
        if t>=1.0:
            rising = false
            standing = true
        return
    if standing:
        Pose.restore(skeleton,standing_pose)
    else:
        Pose.restore(skeleton,seated_pose)
    var phase := age*(0.55+float(variant%5)*0.11)+float(variant)*1.73
    var breath := sin(phase)*0.011
    if roles.has("chest"):
        var chest := int(roles["chest"])
        skeleton.set_bone_pose_rotation(chest,skeleton.get_bone_pose_rotation(chest)*Quaternion(Vector3.RIGHT,breath))
    if roles.has("head"):
        var head := int(roles["head"])
        var yaw: float = sin(phase*0.47)*[0.04,0.01,0.07,0.03,0.09,0.02][variant%6]
        if visible_player!=null and is_instance_valid(visible_player) and variant%3==0:
            var facing := to_local(visible_player.global_position)
            yaw += clampf(atan2(facing.x,facing.z)*0.25,-0.22,0.22)
        skeleton.set_bone_pose_rotation(head,skeleton.get_bone_pose_rotation(head)*Quaternion(Vector3.UP,yaw))
    if not standing and not rising and roles.has("jaw") and variant%4==1:
        var jaw := int(roles["jaw"])
        var amplitude := maxf(0.0,sin(phase*2.2))*0.045
        skeleton.set_bone_pose_rotation(jaw,skeleton.get_bone_pose_rotation(jaw)*Quaternion(Vector3.RIGHT,amplitude))

func _exit_tree() -> void:
    # Important for the strict headless renderer and the room-stream teardown:
    # release imported skinned mesh instances before their material RIDs.
    if is_instance_valid(figure):
        for item in figure.find_children("*","MeshInstance3D",true,false):
            var mesh := item as MeshInstance3D
            mesh.material_overlay = null
            if mesh.mesh!=null:
                for surface in range(mesh.mesh.get_surface_count()):
                    mesh.set_surface_override_material(surface,null)
