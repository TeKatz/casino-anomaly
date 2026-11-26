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
var seat_surface_y := -0.17
var seat_front := 0.26
var support_y := 0.0
var worktop_y := 0.0
var worktop_reach := 0.48
var arm_reference: Dictionary = {}
var stature := 0.0
var motion_clock := 0.0
const MODEL_STATURES := [1.85, 1.77, 1.83, 1.86, 1.68]

func configure(packed: PackedScene, identifier: String, seat: Dictionary, serial: int) -> bool:
    variant = serial
    appearance_id = identifier
    style = maxi(0, STYLES.find(identifier))
    seat_kind = str(seat["kind"])
    position = seat["anchor"]
    # The seat describes the actual upholstered surface, not a bone pivot.
    # The hip is above the cushion by the model's pelvis-to-buttock distance.
    var surface: Vector3 = seat.get("surface", position - Vector3.UP * 0.09)
    var pelvis_clearance: float = [0.17, 0.16, 0.17, 0.18, 0.145][style]
    position = surface + Vector3.UP * pelvis_clearance
    floor_y = float(seat.get("floor_y", 0.0)) - position.y
    seat_surface_y = surface.y - position.y
    seat_front = float(seat.get("front", 0.28))
    support_y = float(seat.get("support_y", 0.0)) - position.y
    worktop_y = float(seat.get("worktop_y", 1.34 if seat_kind == "bar" else 0.94)) - position.y
    worktop_reach = float(seat.get("worktop_reach", 0.55))
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
    # Normalize real standing proportions: head joint to lowest toe is
    # roughly full stature minus the crown and shoe sole, not full height.
    var measured: float = _point("head").y - minf(_point("left_toe").y, _point("right_toe").y)
    if measured < 0.01:
        return false
    stature = float(MODEL_STATURES[style])
    var joint_height: float = stature - (0.17 if style == 4 else 0.15)
    figure.scale *= joint_height / measured
    skeleton.force_update_all_bone_transforms()
    figure.position -= _point("hip")
    for side in ["left", "right"]:
        var foot: String = str(side) + "_foot"
        var toe: String = str(side) + "_toe"
        var index := int(roles[foot])
        foot_reference[side] = {
            "rotation": skeleton.get_bone_global_pose(index).basis.orthonormalized().get_rotation_quaternion(),
            "clearance": clampf(_point(foot).y - _point(toe).y + 0.045, 0.06, 0.20)
        }
    _sitting_pose()
    seated_pose = Pose.snapshot(skeleton)
    for side in ["left", "right"]:
        var prefix: String = str(side)
        var hand: String = prefix + "_hand"
        var index: int = int(roles[hand])
        arm_reference[prefix] = {
            "rotation": skeleton.get_bone_global_pose(index).basis.orthonormalized().get_rotation_quaternion(),
            "side": 1.0 if side == "left" else -1.0
        }
    for role in ["chest","head","jaw"]:
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
    # The anomaly inherits pause behavior from the live room; no imported
    # AnimationPlayer is allowed to overwrite this actor's skeletal poses.
    set_process(true)
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
        "left_finger":["lefthandmiddle1_","lefthandindex1_","l_middle1_","l_mid1_","l_index1_"],
        "right_finger":["righthandmiddle1_","righthandindex1_","r_middle1_","r_mid1_","r_index1_"],
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

func _restore_global_rotation(role: String, rotation_value: Quaternion) -> void:
    var index: int = int(roles[role])
    var parent: int = skeleton.get_bone_parent(index)
    var parent_rotation: Quaternion = skeleton.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
    skeleton.set_bone_pose_rotation(index, (parent_rotation.inverse() * rotation_value).normalized())
    skeleton.force_update_all_bone_transforms()

func _solve_leg(side: String, outward: float) -> void:
    var thigh: String = side + "_thigh"
    var calf: String = side + "_calf"
    var foot: String = side + "_foot"
    var hip: Vector3 = _point(thigh)
    var upper: float = hip.distance_to(_point(calf))
    var lower: float = _point(calf).distance_to(_point(foot))
    var reference: Dictionary = foot_reference[side]
    var clearance: float = float(reference["clearance"])
    # Keep the thighs ABOVE the cushion, and put the knee beyond its front
    # edge before the shin drops. A high stool may leave feet dangling when
    # the actual foot rail is below the anatomical reach of the guest.
    var support: float = support_y if seat_kind == "bar" else floor_y
    var ideal_knee_y: float = support + clearance + lower * 0.98
    var knee_y: float = clampf(ideal_knee_y, maxf(hip.y-upper*0.25, seat_surface_y+0.065), hip.y+upper*0.22)
    var vertical: float = clampf(knee_y-hip.y, -upper*0.30, upper*0.25)
    var horizontal: float = sqrt(maxf(0.0, upper*upper-vertical*vertical-outward*outward))
    _aim(thigh, calf, seat_forward*horizontal + seat_right*outward + Vector3.UP*vertical)
    var knee: Vector3 = _point(calf)
    # Lower legs remain in front of the upholstery / stool pedestal.
    var ankle_y: float = clampf(support+clearance, knee.y-lower*0.995, knee.y-lower*0.70)
    ankle_y = maxf(ankle_y, floor_y+clearance)
    var drop: float = clampf(knee.y-ankle_y, 0.015, lower*0.999)
    var horizontal_shin: float = sqrt(maxf(0.0, lower*lower-drop*drop))
    var knee_forward: float = knee.dot(seat_forward)
    # Bar guests may tuck their heels toward a rail, but never through the
    # stool's front edge. Sofa/table guests keep their feet in the aisle.
    var shin_sign: float = 1.0
    if seat_kind == "bar" and knee_forward-horizontal_shin > seat_front+0.065:
        shin_sign = -1.0
    _aim(calf, foot, seat_forward*horizontal_shin*shin_sign + Vector3.DOWN*drop)
    _restore_global_rotation(foot, reference["rotation"] as Quaternion)

func _sitting_pose() -> void:
    var lean: float = [0.08,0.22,-0.04,0.11,0.05][style]
    if seat_kind == "table":
        lean += 0.18
    elif seat_kind == "bar":
        lean += 0.10
    _aim("chest", "head", Vector3.UP + seat_forward*lean)
    var spread: float = [0.07,0.045,0.08,0.06,0.025][style]
    _solve_leg("left", spread)
    _solve_leg("right", -spread)

func _solve_arm(side: String, target: Vector3, palm_direction: Vector3) -> void:
    var arm: String = side + "_arm"
    var forearm: String = side + "_forearm"
    var hand: String = side + "_hand"
    var shoulder: Vector3 = _point(arm)
    var upper: float = shoulder.distance_to(_point(forearm))
    var lower: float = _point(forearm).distance_to(_point(hand))
    var offset: Vector3 = target - shoulder
    if offset.length_squared() < 0.000001 or upper < 0.001 or lower < 0.001:
        return
    var axis: Vector3 = offset.normalized()
    var distance: float = clampf(offset.length(), absf(upper-lower)+0.005, upper+lower-0.008)
    var lateral: float = 1.0 if side == "left" else -1.0
    var pole: Vector3 = Vector3.DOWN + seat_right*lateral*0.55
    var bend: Vector3 = (pole-axis*pole.dot(axis)).normalized()
    if bend.length_squared() < 0.001:
        bend = seat_right*lateral
    var along: float = (upper*upper-lower*lower+distance*distance)/(2.0*distance)
    var perpendicular: float = sqrt(maxf(0.0, upper*upper-along*along))
    var elbow: Vector3 = shoulder+axis*along+bend*perpendicular
    _aim(arm, forearm, elbow-shoulder)
    _aim(forearm, hand, shoulder+axis*distance-_point(forearm))
    # Restore the hand's source pitch before aligning fingers. Otherwise
    # the wrist inherits the two arbitrary IK rotations and twists into
    # the thigh/torso. Keep a shallow forward direction, above the surface.
    var reference: Dictionary = arm_reference[side]
    _restore_global_rotation(hand, reference["rotation"] as Quaternion)
    var finger: String = side + "_finger"
    if roles.has(finger):
        _aim(hand, finger, palm_direction)

func _hand_target(side: String, phase: float, motion: float) -> Vector3:
    var lateral: float = 1.0 if side == "left" else -1.0
    var dominant: String = "left" if style in [1,4] else "right"
    var intensity: float = 1.0 if side == dominant else 0.37
    var wave: float = sin(phase*2.0 + lateral*0.45)
    # Each character has a different conversational rhythm; the envelope
    # never switches abruptly, including across the loop boundary.
    var talk: float = pow(0.5+0.5*sin(phase+float(style)*0.71), 2.0)*motion
    var gesture: float = (0.12 + float(style)*0.013)*intensity*talk
    var shoulder: Vector3 = _point(side+"_arm")
    var target: Vector3
    if seat_kind == "sofa":
        var hip: Vector3 = _point(side+"_thigh")
        var knee: Vector3 = _point(side+"_calf")
        target = hip.lerp(knee, 0.70) + Vector3.UP*0.155 + seat_right*lateral*0.045
        target += Vector3.UP*gesture*(0.65+0.35*wave)
        target += seat_forward*gesture*0.60 + seat_right*lateral*gesture*0.42
    else:
        # Hands reach out toward the actual work surface, not the lap.
        # Elbows remain bent and wrists are elevated above the tabletop.
        var reach: float = worktop_reach + 0.045*sin(phase+lateral)*motion
        var width: float = maxf(absf(shoulder.dot(seat_right))*0.84, 0.13)
        target = seat_forward*reach + seat_right*lateral*width
        target.y = worktop_y + 0.095
        target += Vector3.UP*gesture*(0.65+0.35*wave)
        target += seat_right*lateral*gesture*0.42
        target += seat_forward*gesture*0.52
    return target

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
    capsule.height = 1.24
    collider.shape = capsule
    collider.position = Vector3(0, 0.40, 0)

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
    _animate("chest", (0.025+0.007*float(style))*breath)
    _animate("head", 0.15*nod + 0.045*sin(phase)*motion,
        (0.13+0.032*float(style))*sin(phase)*motion)
    skeleton.force_update_all_bone_transforms()
    for side in ["left","right"]:
        var prefix: String = str(side)
        var target: Vector3 = _hand_target(prefix, phase, motion)
        _solve_arm(prefix, target, seat_forward + Vector3.DOWN*0.16)
    # Only the guard and female glTFs expose a jaw; other models communicate
    # through body language, rather than deforming the entire face.
    _animate("jaw", 0.12*speech*(0.5+0.5*sin(phase*9.0)))

func _process(delta: float) -> void:
    if skeleton == null or seated_pose.is_empty():
        return
    var event := get_parent()
    var room := event.get_parent() if event != null else null
    if room != null and room.has_meta("_streaming_standby"):
        return
    age = fposmod(age + delta, loop_period)
    # Keep the IK update bounded to 30 Hz even on very fast machines.
    # Real-time phase still advances at the actual elapsed time.
    motion_clock += delta
    if motion_clock >= 1.0/30.0:
        motion_clock = fmod(motion_clock, 1.0/30.0)
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
