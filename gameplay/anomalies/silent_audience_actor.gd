extends Node3D
## Permanent seated performance on the original five heterogeneous rigs.
## Solve against anatomical joint positions in actor space, not imported bone axes.
const Pose = preload("res://gameplay/anomalies/silent_audience_pose.gd")
const STYLES := ["security_guard", "old_man", "suit_man", "guard", "female"]
var skeleton: Skeleton3D
var figure: Node3D
var physical: StaticBody3D
var collider: CollisionShape3D
var roles: Dictionary = {}
var seated_pose: Array[Dictionary] = []
var animated_roles: Dictionary = {}
var foot_reference: Dictionary = {}
var seat_forward := Vector3.BACK
var seat_right := Vector3.RIGHT
var seat_kind := "sofa"
var appearance_id := ""
var age := 0.0
var variant := 0
var style := 0
var loop_period := 10.0
var floor_y := 0.0
var reduced_motion := false

func configure(packed: PackedScene, identifier: String, seat: Dictionary, serial: int) -> bool:
    variant = serial
    appearance_id = identifier
    style = maxi(0, STYLES.find(identifier))
    seat_kind = str(seat["kind"])
    position = seat["anchor"]
    floor_y = float(seat.get("floor_y", 0.0)) - position.y
    var yaw := float(seat["yaw"])
    seat_forward = Basis(Vector3.UP, yaw) * Vector3.BACK
    seat_right = Basis(Vector3.UP, yaw) * Vector3.RIGHT
    figure = packed.instantiate() as Node3D
    if figure == null:
        return false
    figure.name = "GuestModel"
    figure.hide()
    add_child(figure)
    # The female source actually faces -Z, unlike all four male sources.
    figure.rotation.y = yaw + (PI if identifier == "female" else 0.0)
    for item in figure.find_children("*", "AnimationTree", true, false):
        (item as AnimationTree).active = false
    for item in figure.find_children("*", "AnimationPlayer", true, false):
        (item as AnimationPlayer).stop()
        (item as AnimationPlayer).active = false
    for node in figure.find_children("*", "Skeleton3D", true, false):
        var candidate := node as Skeleton3D
        if skeleton == null or candidate.get_bone_count() > skeleton.get_bone_count():
            skeleton = candidate
    if skeleton == null:
        return false
    _resolve_roles()
    for required in ["hip","head","chest","left_thigh","right_thigh","left_calf","right_calf","left_foot","right_foot","left_toe","right_toe","left_arm","right_arm","left_forearm","right_forearm","left_hand","right_hand"]:
        if not roles.has(required):
            push_warning("Audience %s rig missing %s" % [identifier, required])
            return false
    skeleton.reset_bone_poses()
    skeleton.force_update_all_bone_transforms()
    var measured := _point("head").y - minf(_point("left_foot").y, _point("right_foot").y)
    if measured < 0.01:
        return false
    # Keep natural differences between the five silhouettes, not random giant guests.
    var desired: float = [1.48, 1.43, 1.46, 1.49, 1.38][style]
    figure.scale *= desired / measured
    skeleton.force_update_all_bone_transforms()
    figure.position -= _point("hip")
    for side in ["left", "right"]:
        var foot: String = str(side) + "_foot"
        var toe: String = str(side) + "_toe"
        var index := int(roles[foot])
        foot_reference[side] = {
            "rotation": skeleton.get_bone_global_pose(index).basis.orthonormalized().get_rotation_quaternion(),
            "clearance": clampf(_point(foot).y - _point(toe).y + 0.035, 0.055, 0.16)
        }
    _sitting_pose()
    seated_pose = Pose.snapshot(skeleton)
    for role in ["chest","head","left_arm","right_arm","left_forearm","right_forearm","jaw"]:
        if roles.has(role):
            var index := int(roles[role])
            var basis := _actor_basis(index)
            animated_roles[role] = {"index":index, "rest":skeleton.get_bone_pose_rotation(index),
                "pitch":(basis.inverse()*seat_right).normalized(),
                "yaw":(basis.inverse()*Vector3.UP).normalized()}
    loop_period = [9.2, 12.0, 10.4, 8.8, 11.2][style]
    var settings := get_node_or_null("/root/GameSettings")
    reduced_motion = settings != null and bool(settings.call("get_option", "reduced_motion"))
    _individual_materials()
    _make_collision()
    _sample_loop(0.0)
    figure.show()
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
        "left_hand":["lefthand_","l_hand_","l_wrist_2_","hand_l_"],
        "right_hand":["righthand_","r_hand_","r_wrist_2_","hand_r_"],
        "left_toe":["lefttoebase_","l_toebase_","l_toes_2_","toe_l_"],
        "right_toe":["righttoebase_","r_toebase_","r_toes_2_","toe_r_"],
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


func _point(role: String) -> Vector3:
    return to_local(skeleton.to_global(skeleton.get_bone_global_pose(int(roles[role])).origin))

func _actor_basis(index: int) -> Basis:
    return (global_transform.affine_inverse().basis * skeleton.global_transform.basis *
        skeleton.get_bone_global_pose(index).basis).orthonormalized()

func _aim(role: String, child_role: String, direction: Vector3) -> void:
    var index := int(roles[role])
    var from := _point(child_role) - _point(role)
    if from.length_squared() < 0.00000001 or direction.length_squared() < 0.00000001:
        return
    var inverse := _actor_basis(index).inverse()
    var turn := Quaternion((inverse * from).normalized(), (inverse * direction).normalized())
    skeleton.set_bone_pose_rotation(index, (skeleton.get_bone_pose_rotation(index) * turn).normalized())
    skeleton.force_update_all_bone_transforms()

func _solve_leg(side: String, outward: float) -> void:
    var thigh := side + "_thigh"
    var calf := side + "_calf"
    var foot: String = str(side) + "_foot"
    var hip := _point(thigh)
    var upper := hip.distance_to(_point(calf))
    var lower := _point(calf).distance_to(_point(foot))
    var reference: Dictionary = foot_reference[side]
    var clearance := float(reference["clearance"])
    # Sofa and gaming stools use the actual floor; high bar stools can use
    # their foot rail rather than stretching a short rig through the floor.
    var support := floor_y
    if seat_kind == "bar" and hip.y - (support + clearance) > lower + upper * 0.40:
        support = minf(floor_y + 0.20, hip.y - lower * 0.65 - clearance)
        support = maxf(support, floor_y)
    var reach := upper * (0.96 if seat_kind == "sofa" else 0.80)
    var ankle := hip + seat_forward * reach + seat_right * outward
    ankle.y = support + clearance
    var offset := ankle - hip
    var distance := clampf(offset.length(), absf(upper-lower)+0.001, upper+lower-0.002)
    var axis := offset.normalized()
    var bend := (seat_forward - axis * seat_forward.dot(axis)).normalized()
    if bend.length_squared() < 0.001:
        bend = Vector3.UP
    var along := (upper*upper - lower*lower + distance*distance) / (2.0*distance)
    var perpendicular := sqrt(maxf(0.0, upper*upper - along*along))
    var knee := hip + axis*along + bend*perpendicular
    _aim(thigh, calf, knee - hip)
    _aim(calf, foot, hip + axis*distance - _point(calf))
    # Preserve the source's foot pitch (including the woman's heels) while
    # aligning the lower leg. Do not inherit the calf's arbitrary rotation.
    var index := int(roles[foot])
    var parent := skeleton.get_bone_parent(index)
    var parent_rotation := skeleton.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
    skeleton.set_bone_pose_rotation(index, (parent_rotation.inverse() * (reference["rotation"] as Quaternion)).normalized())
    skeleton.force_update_all_bone_transforms()

func _sitting_pose() -> void:
    # Five individual signatures: guarded, stooped, relaxed, attentive,
    # and compact. Seat kind selects a second posture layer.
    var lean: float = [0.04,0.14,-0.04,0.07,0.02][style]
    if seat_kind == "table":
        lean += 0.07
    _aim("chest","head",Vector3.UP + seat_forward * lean)
    var spread: float = [0.055,0.035,0.08,0.045,0.015][style]
    _solve_leg("left", spread)
    _solve_leg("right", -spread)
    for side in ["left","right"]:
        var sign_side := 1.0 if side == "left" else -1.0
        var arm: String = str(side) + "_arm"
        var forearm: String = str(side) + "_forearm"
        var hand: String = str(side) + "_hand"
        var elbow_direction := Vector3.DOWN + seat_right * sign_side * (0.18 if seat_kind == "sofa" else 0.09)
        elbow_direction += seat_forward * (0.24 if seat_kind == "table" else 0.10)
        _aim(arm, forearm, elbow_direction)
        # Wrists rest toward the lap or counter; never extend sideways.
        var elbow := _point(forearm)
        var knee := _point(side + "_calf")
        var lap := knee - seat_forward * (0.10 + 0.025*float(style%3))
        lap.y += 0.08
        var toward := lap - elbow
        if seat_kind == "bar":
            toward = seat_forward * 0.75 + Vector3.DOWN * (0.32 + 0.07*float(style%3))
        _aim(forearm, hand, toward)
    skeleton.force_update_all_bone_transforms()

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
    capsule.radius = 0.28
    capsule.height = 1.10
    collider.shape = capsule
    collider.position = Vector3(0, 0.38, 0)

func _animate(role: String, pitch: float, yaw: float = 0.0) -> void:
    if not animated_roles.has(role):
        return
    var data: Dictionary = animated_roles[role]
    var q: Quaternion = data["rest"]
    q = q * Quaternion(data["pitch"], pitch) * Quaternion(data["yaw"], yaw)
    skeleton.set_bone_pose_rotation(int(data["index"]), q.normalized())

func _sample_loop(seconds: float) -> void:
    # Integer harmonics of the same phase give exact continuous loop seams.
    # No animation track ever translates the root, hip, knees or feet.
    var phase := TAU * fposmod(seconds, loop_period) / loop_period + float(variant)*1.73
    var motion := 0.0 if reduced_motion else 1.0
    var speech := pow(0.5 + 0.5*sin(phase), 4.0) * motion
    var nod := sin(phase*3.0) * speech
    var breath := sin(phase*2.0) * motion
    _animate("chest", 0.012*breath)
    _animate("head", 0.045*nod + 0.016*sin(phase)*motion,
        (0.035+0.012*float(style))*sin(phase)*motion)
    var dominant := "left" if style in [1,4] else "right"
    for side in ["left","right"]:
        var emphasis := 1.0 if side == dominant else 0.30
        var strength := emphasis * (0.045+0.013*float(style))
        _animate(side+"_arm", strength*speech*sin(phase*2.0), 0.012*breath)
        _animate(side+"_forearm", strength*1.6*speech*(0.55+0.45*sin(phase*4.0)))
    # Only the guard and female glTFs expose a jaw; other models communicate
    # through body language, rather than deforming the entire face.
    _animate("jaw", 0.055*speech*(0.5+0.5*sin(phase*9.0)))

func _process(delta: float) -> void:
    if skeleton == null or seated_pose.is_empty():
        return
    var event := get_parent()
    var room := event.get_parent() if event != null else null
    if room != null and room.has_meta("_streaming_standby"):
        return
    age = fposmod(age + delta, loop_period)
    _sample_loop(age)

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
