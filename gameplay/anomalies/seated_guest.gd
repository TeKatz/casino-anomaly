extends RefCounted
## A single motionless suited guest. Transfer the existing authored
## sitting animation by anatomical joint directions, not donor bone scales
## or root positions. No imported resource is modified.
const MODEL := "res://models/silent_audience/suit_man/scene.gltf"
const SITTING_SOURCE := "res://models/croupier/scene.gltf"
const Cache = preload("res://gameplay/runtime_asset_cache.gd")
const FACE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform vec3 center_local;
uniform vec3 right_local;
uniform vec3 up_local;
uniform vec3 front_local;
uniform vec2 extent = vec2(0.10,0.12);
varying vec3 face_coordinates;
void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    vec3 center = (MODEL_MATRIX * vec4(center_local,1.0)).xyz;
    vec3 right = normalize(mat3(MODEL_MATRIX) * right_local);
    vec3 up = normalize(mat3(MODEL_MATRIX) * up_local);
    vec3 front = normalize(mat3(MODEL_MATRIX) * front_local);
    vec3 offset = p-center;
    face_coordinates = vec3(dot(offset,right),dot(offset,up),dot(offset,front));
}
void fragment() {
    float edge = length(face_coordinates.xy / extent);
    if (edge > 1.0 || face_coordinates.z < -0.045) { discard; }
    ALBEDO = vec3(0.0015,0.0015,0.0020);
}
"""


static func available() -> bool:
    return ResourceLoader.exists(MODEL, "PackedScene") and ResourceLoader.exists(SITTING_SOURCE, "PackedScene")


static func _skeleton(model: Node3D) -> Skeleton3D:
    for item in model.find_children("*", "Skeleton3D", true, false):
        var rig := item as Skeleton3D
        if rig.get_bone_count() > 25:
            return rig
    return null


static func _bone(rig: Skeleton3D, prefix: String) -> int:
    for i in range(rig.get_bone_count()):
        if str(rig.get_bone_name(i)).to_lower().begins_with(prefix.to_lower()):
            return i
    return -1


static func _point(rig: Skeleton3D, anchor: Node3D, index: int) -> Vector3:
    return anchor.to_local(rig.to_global(rig.get_bone_global_pose(index).origin))


static func _aim(rig: Skeleton3D, anchor: Node3D, joint: int, endpoint: int, direction: Vector3) -> void:
    var current := _point(rig,anchor,endpoint)-_point(rig,anchor,joint)
    if current.length_squared() < 0.00000001 or direction.length_squared() < 0.00000001:
        return
    var joint_basis := (anchor.global_transform.affine_inverse().basis * rig.global_transform.basis * rig.get_bone_global_pose(joint).basis).orthonormalized()
    var inverse := joint_basis.inverse()
    var turn := Quaternion((inverse*current).normalized(),(inverse*direction).normalized())
    rig.set_bone_pose_rotation(joint,(rig.get_bone_pose_rotation(joint)*turn).normalized())
    rig.force_update_all_bone_transforms()


static func _direction(rig: Skeleton3D, anchor: Node3D, a: int, b: int) -> Vector3:
    return (_point(rig,anchor,b)-_point(rig,anchor,a)).normalized()


static func _source_pose(parent: Node3D) -> Dictionary:
    var packed := Cache.packed_scene(SITTING_SOURCE)
    if packed == null:
        return {}
    var donor := packed.instantiate() as Node3D
    if donor == null:
        return {}
    donor.hide()
    parent.add_child(donor)
    var rig := _skeleton(donor)
    var clip_name := ""
    for item in donor.find_children("*","AnimationPlayer",true,false):
        var animator := item as AnimationPlayer
        for clip in animator.get_animation_list():
            if str(clip).to_lower().contains("sitting_idle"):
                animator.play(clip)
                animator.advance(0.0)
                animator.seek(minf(0.4,animator.get_animation(clip).length*0.5),true)
                animator.pause()
                clip_name = str(clip)
                break
        if not clip_name.is_empty():
            break
    if rig == null or clip_name.is_empty():
        donor.free()
        return {}
    rig.force_update_all_bone_transforms()
    var result := {"clip":clip_name}
    var hip := _bone(rig,"Hips_")
    var head := _bone(rig,"Head_")
    if hip < 0 or head < 0:
        donor.free()
        return {}
    result["torso"] = _direction(rig,parent,hip,head)
    for side in ["left","right"]:
        var suffix := "L" if side == "left" else "R"
        var foot := _bone(rig,"Foot_"+suffix+"_")
        var arm := _bone(rig,"Upper_Arm_"+suffix+"_")
        var hand := _bone(rig,"Hand_"+suffix+"_")
        if mini(foot,mini(arm,hand)) < 0:
            donor.free()
            return {}
        var calf := rig.get_bone_parent(foot)
        var thigh := rig.get_bone_parent(calf) if calf >= 0 else -1
        var forearm := rig.get_bone_parent(hand)
        if mini(thigh,mini(calf,forearm)) < 0:
            donor.free()
            return {}
        result[side+"_upper_leg"] = _direction(rig,parent,thigh,calf)
        result[side+"_lower_leg"] = _direction(rig,parent,calf,foot)
        result[side+"_upper_arm"] = _direction(rig,parent,arm,forearm)
        result[side+"_lower_arm"] = _direction(rig,parent,forearm,hand)
    donor.free()
    return result


static func _roles(rig: Skeleton3D) -> Dictionary:
    var result := {}
    for pair in [
        ["hip","Hips_"],["head","Head_"],["headtop","HeadTop_End_"],
        ["left_eye","LeftEye_"],["right_eye","RightEye_"],
        ["left_thigh","LeftUpLeg_"],["left_calf","LeftLeg_"],["left_foot","LeftFoot_"],["left_toe","LeftToeBase_"],
        ["right_thigh","RightUpLeg_"],["right_calf","RightLeg_"],["right_foot","RightFoot_"],["right_toe","RightToeBase_"],
        ["left_arm","LeftArm_"],["left_forearm","LeftForeArm_"],["left_hand","LeftHand_"],
        ["right_arm","RightArm_"],["right_forearm","RightForeArm_"],["right_hand","RightHand_"]
    ]:
        var index := _bone(rig,pair[1])
        if index < 0:
            return {}
        result[pair[0]] = index
    return result


static func _capsule(body: StaticBody3D, name_value: String, a: Vector3, b: Vector3, width: float) -> void:
    var segment := b-a
    if segment.length() < 0.001:
        return
    var collision := CollisionShape3D.new()
    collision.name = name_value
    var shape := CapsuleShape3D.new()
    shape.radius = width
    shape.height = segment.length()+width*2.0
    collision.shape = shape
    body.add_child(collision)
    collision.position = (a+b)*0.5
    collision.basis = Basis(Quaternion(Vector3.UP,segment.normalized()))


static func _mask_face(figure: Node3D, rig: Skeleton3D, anchor: Node3D, roles: Dictionary) -> int:
    var left := _point(rig,anchor,int(roles["left_eye"]))
    var right := _point(rig,anchor,int(roles["right_eye"]))
    var head := _point(rig,anchor,int(roles["head"]))
    var top := _point(rig,anchor,int(roles["headtop"]))
    var up := (top-head).normalized()
    var horizontal := (left-right).normalized()
    var eyes := (left+right)*0.5
    var forward := eyes-head
    forward = (forward-up*forward.dot(up)-horizontal*forward.dot(horizontal)).normalized()
    if forward.length_squared() < 0.01:
        forward = Vector3.BACK
    var center := eyes-up*0.025
    var half_width := clampf(left.distance_to(right)*1.75,0.078,0.115)
    var half_height := clampf((top-head).length()*0.61,0.085,0.125)
    var shader := Shader.new()
    shader.code = FACE_SHADER
    var count := 0
    for item in figure.find_children("*","MeshInstance3D",true,false):
        var mesh := item as MeshInstance3D
        if mesh.mesh == null:
            continue
        mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        for surface in range(mesh.mesh.get_surface_count()):
            var original := mesh.get_active_material(surface) as StandardMaterial3D
            if original == null:
                continue
            var label := str(original.resource_name).to_lower()
            # This glTF has separately authored AvatarHead, eyes, corneas,
            # lashes and teeth. Body/outfit/glasses retain original materials.
            if not ("avatarhead" in label or "eyeball" in label or "cornea" in label or "eyelash" in label or "teeth" in label):
                continue
            var mask := ShaderMaterial.new()
            mask.shader = shader
            mask.render_priority = 2
            mask.set_shader_parameter("center_local",mesh.to_local(anchor.to_global(center)))
            var inverse := mesh.global_basis.inverse()*anchor.global_basis
            mask.set_shader_parameter("right_local",inverse*horizontal)
            mask.set_shader_parameter("up_local",inverse*up)
            mask.set_shader_parameter("front_local",inverse*forward)
            mask.set_shader_parameter("extent",Vector2(half_width,half_height))
            var material := original.duplicate() as StandardMaterial3D
            material.next_pass = mask
            mesh.set_surface_override_material(surface,material)
            count += 1
    return count


static func install(sofa: Node3D, parent: Node3D) -> Node3D:
    var packed := Cache.packed_scene(MODEL)
    if packed == null:
        return null
    var seat: MeshInstance3D
    for item in sofa.find_children("*","MeshInstance3D",true,false):
        if str(item.name).to_lower().contains("seat") and (item as MeshInstance3D).mesh != null:
            seat = item as MeshInstance3D
            break
    if seat == null:
        return null
    var seat_box: AABB = (sofa.global_transform.affine_inverse()*seat.global_transform)*seat.get_aabb()
    var seat_anchor := sofa.to_global(Vector3(seat_box.get_center().x+0.08,seat_box.end.y,seat_box.get_center().z-0.10))
    # Cancel any authored nonuniform furniture scale. Guest and collision
    # are measured in metres and the same orientation as the sofa.
    parent.global_transform = Transform3D(sofa.global_basis.orthonormalized(),seat_anchor+Vector3.UP*0.10)
    var pose := _source_pose(parent)
    if pose.is_empty():
        return null
    var figure := packed.instantiate() as Node3D
    if figure == null:
        return null
    figure.name = "SeatedGuest"
    parent.add_child(figure)
    for item in figure.find_children("*","AnimationPlayer",true,false):
        (item as AnimationPlayer).stop()
        (item as AnimationPlayer).active = false
    for item in figure.find_children("*","AnimationTree",true,false):
        (item as AnimationTree).active = false
    var rig := _skeleton(figure)
    if rig == null:
        figure.free()
        return null
    var roles := _roles(rig)
    if roles.is_empty():
        figure.free()
        return null
    rig.reset_bone_poses()
    rig.force_update_all_bone_transforms()
    var standing_height := _point(rig,parent,int(roles["headtop"])).y - minf(_point(rig,parent,int(roles["left_foot"])).y,_point(rig,parent,int(roles["right_foot"])).y)
    if standing_height < 0.001:
        figure.free()
        return null
    figure.scale *= 1.65/standing_height
    # Preserve the new rig's foot orientation before changing the leg
    # chains; the seated source's limb directions carry the actual pose.
    var feet: Dictionary = {}
    for side in ["left","right"]:
        var foot_index := int(roles[side+"_foot"])
        feet[side] = rig.get_bone_global_pose(foot_index).basis.orthonormalized().get_rotation_quaternion()
    _aim(rig,parent,int(roles["hip"]),int(roles["head"]),pose["torso"])
    for side in ["left","right"]:
        var thigh := int(roles[side+"_thigh"])
        var calf := int(roles[side+"_calf"])
        var foot := int(roles[side+"_foot"])
        var arm := int(roles[side+"_arm"])
        var forearm := int(roles[side+"_forearm"])
        var hand := int(roles[side+"_hand"])
        _aim(rig,parent,thigh,calf,pose[side+"_upper_leg"])
        _aim(rig,parent,calf,foot,pose[side+"_lower_leg"])
        var calf_rotation := rig.get_bone_global_pose(calf).basis.orthonormalized().get_rotation_quaternion()
        rig.set_bone_pose_rotation(foot,(calf_rotation.inverse()*(feet[side] as Quaternion)).normalized())
        rig.force_update_all_bone_transforms()
        _aim(rig,parent,arm,forearm,pose[side+"_upper_arm"])
        _aim(rig,parent,forearm,hand,pose[side+"_lower_arm"])
    figure.position -= _point(rig,parent,int(roles["hip"]))
    # The seated animation is retained; fit ankle height to the actual floor
    # using only a uniform scale adjustment if the proportionate model needs it.
    var room := sofa.get_parent().get_parent() as Node3D
    var floor_y := parent.to_local(room.to_global(Vector3(0,0.035,0))).y
    var foot_y := minf(_point(rig,parent,int(roles["left_foot"])).y,_point(rig,parent,int(roles["right_foot"])).y)
    if foot_y < -0.10:
        var fit := clampf((floor_y+0.075)/foot_y,0.88,1.12)
        figure.scale *= fit
        figure.position -= _point(rig,parent,int(roles["hip"]))
    var masks := _mask_face(figure,rig,parent,roles)
    if masks == 0:
        figure.free()
        return null
    figure.set_meta("seated_source_clip",pose["clip"])
    figure.set_meta("face_mask_surfaces",masks)
    var body := StaticBody3D.new()
    body.name = "GuestCollision"
    body.collision_layer = 1
    body.collision_mask = 0
    parent.add_child(body)
    var hip := _point(rig,parent,int(roles["hip"]))
    var head := _point(rig,parent,int(roles["head"]))
    var shoulder := hip.lerp(head,0.79)
    var width := _point(rig,parent,int(roles["left_arm"])).distance_to(_point(rig,parent,int(roles["right_arm"])))
    _capsule(body,"Torso",hip,shoulder,clampf(width*0.42,0.15,0.24))
    _capsule(body,"Head",head,head+Vector3.UP*0.10,0.105)
    for side in ["left","right"]:
        var knee := _point(rig,parent,int(roles[side+"_calf"]))
        var ankle := _point(rig,parent,int(roles[side+"_foot"]))
        _capsule(body,side+"_thigh",_point(rig,parent,int(roles[side+"_thigh"])),knee,0.10)
        _capsule(body,side+"_shin",knee,ankle,0.075)
    return figure
