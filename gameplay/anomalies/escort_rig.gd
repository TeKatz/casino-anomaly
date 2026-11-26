extends Node3D
## One original Security Guard skin, driven by authored Quaternius clips.
## The engine's native RetargetModifier3D transfers rest-relative rotations;
## no manually authored joint motion, no procedural limb animation.
const MODEL := "res://models/silent_audience/security_guard/scene.gltf"
const LIBRARY := "res://models/escort_animations/UAL1_Standard.glb"
const BODY_MAP := {
    "Hips": ["pelvis","Hips"], "Spine": ["spine_01","Spine"],
    "Chest": ["spine_02","Spine1"], "UpperChest": ["spine_03","Spine2"],
    "Neck": ["neck_01","Neck"], "Head": ["Head","Head"],
    "LeftShoulder": ["clavicle_l","LeftShoulder"], "RightShoulder": ["clavicle_r","RightShoulder"],
    "LeftUpperArm": ["upperarm_l","LeftArm"], "RightUpperArm": ["upperarm_r","RightArm"],
    "LeftLowerArm": ["lowerarm_l","LeftForeArm"], "RightLowerArm": ["lowerarm_r","RightForeArm"],
    "LeftHand": ["hand_l","LeftHand"], "RightHand": ["hand_r","RightHand"],
    "LeftUpperLeg": ["thigh_l","LeftUpLeg"], "RightUpperLeg": ["thigh_r","RightUpLeg"],
    "LeftLowerLeg": ["calf_l","LeftLeg"], "RightLowerLeg": ["calf_r","RightLeg"],
    "LeftFoot": ["foot_l","LeftFoot"], "RightFoot": ["foot_r","RightFoot"],
    "LeftToes": ["ball_l","LeftToeBase"], "RightToes": ["ball_r","RightToeBase"]
}
var target: Skeleton3D
var donor: Skeleton3D
var modifier: RetargetModifier3D
var player: AnimationPlayer
var tree: AnimationTree
var figure: Node3D
var source: Node3D
var idle_name: StringName
var walk_name: StringName
var jog_name: StringName
# Original root-motion data: 1.30m / 1.333s walk, 5.0m / 0.933s jog.
# The guard is approximately 6% taller than the source mannequin.
const WALK_STRIDE_SPEED := 1.04
const JOG_STRIDE_SPEED := 5.68
var blend := 0.0
var ready_to_play := false

static func available() -> bool:
    return ResourceLoader.exists(MODEL,"PackedScene") and ResourceLoader.exists(LIBRARY,"PackedScene")

func _skeleton(root_node: Node) -> Skeleton3D:
    for item in root_node.find_children("*","Skeleton3D",true,false):
        return item as Skeleton3D
    return null

func _mixamo_key(name_value: String) -> String:
    var key: String = name_value.to_lower()
    if key.begins_with("mixamorig"):
        key = key.trim_prefix("mixamorig").lstrip(":_")
    # The verified Sketchfab glTF appends _01, _00 etc. to its bones.
    return key.get_slice("_",0)

func _target_index(name_value: String) -> int:
    for i in range(target.get_bone_count()):
        if _mixamo_key(target.get_bone_name(i)) == name_value.to_lower():
            return i
    return -1

func _map_pair(canonical: String, donor_name: String, mixamo_name: String, source_names: Dictionary, target_names: Dictionary) -> bool:
    var a: int = donor.find_bone(donor_name)
    var b: int = _target_index(mixamo_name)
    if a < 0 or b < 0:
        return false
    source_names[str(donor.get_bone_name(a))] = canonical
    target_names[str(target.get_bone_name(b))] = canonical
    return true

func _find_clip(p: AnimationPlayer, wanted: String) -> StringName:
    for name_value in p.get_animation_list():
        var name_key: String = str(name_value).get_file().to_lower().replace("_","").replace("-","")
        if name_key == wanted or name_key == wanted+"loop":
            return name_value
    return &""

func _rename_bones(skeleton: Skeleton3D, names: Dictionary) -> void:
    for old in names:
        skeleton.set_bone_name(skeleton.find_bone(str(old)),str(names[old]))

func _clone_clip(original: Animation, names: Dictionary) -> Animation:
    var clip: Animation = original.duplicate(true) as Animation
    for i in range(clip.get_track_count()-1,-1,-1):
        var path: NodePath = clip.track_get_path(i)
        if path.get_subname_count() != 1 or not names.has(str(path.get_subname(0))):
            clip.remove_track(i)
            continue
        # Keep authored rotation keys only. Both rigs have their own bone
        # lengths and rest offsets. No source-scale or root displacement.
        if clip.track_get_type(i) != Animation.TYPE_ROTATION_3D:
            clip.remove_track(i)
            continue
        clip.track_set_path(i,NodePath(str(path.get_concatenated_names())+":"+str(names[str(path.get_subname(0))])))
    clip.loop_mode = Animation.LOOP_LINEAR
    return clip

func configure() -> bool:
    if not available():
        return false
    var target_scene: PackedScene = load(MODEL) as PackedScene
    var donor_scene: PackedScene = load(LIBRARY) as PackedScene
    if target_scene == null or donor_scene == null:
        return false
    figure = target_scene.instantiate() as Node3D
    source = donor_scene.instantiate() as Node3D
    if figure == null or source == null:
        return false
    figure.name = "SecurityGuard"
    source.name = "QuaterniusMotionSource"
    add_child(figure)
    add_child(source)
    target = _skeleton(figure)
    donor = _skeleton(source)
    if target == null or donor == null:
        return false
    for item in figure.find_children("*","AnimationPlayer",true,false):
        var old_player: AnimationPlayer = item as AnimationPlayer
        old_player.stop()
        old_player.active = false
    for item in figure.find_children("*","AnimationTree",true,false):
        (item as AnimationTree).active = false
    var players: Array[Node] = source.find_children("*","AnimationPlayer",true,false)
    if players.is_empty():
        return false
    player = players[0] as AnimationPlayer
    var idle_key: StringName = _find_clip(player,"idle")
    var walk_key: StringName = _find_clip(player,"walkformal")
    var jog_key: StringName = _find_clip(player,"jogfwd")
    if idle_key.is_empty() or walk_key.is_empty() or jog_key.is_empty():
        return false
    player.stop()
    var source_names: Dictionary = {}
    var target_names: Dictionary = {}
    for canonical in BODY_MAP:
        var pair: Array = BODY_MAP[canonical]
        if not _map_pair(str(canonical),str(pair[0]),str(pair[1]),source_names,target_names):
            push_warning("Escort missing required bone: "+str(canonical))
            return false
    # Match the actual Mixamo finger chains, with Humanoid profile names.
    for side in ["Left","Right"]:
        var side_name: String = str(side)
        var suffix: String = "l" if side_name == "Left" else "r"
        for finger in ["Thumb","Index","Middle","Ring","Pinky"]:
            var digit: String = str(finger)
            var human_digit: String = "Little" if digit == "Pinky" else digit
            var segments: Array[String] = ["Proximal","Intermediate","Distal"]
            if digit == "Thumb":
                segments = ["Metacarpal","Proximal","Distal"]
            for i in range(3):
                _map_pair(side_name+human_digit+segments[i],"%s_%02d_%s" % [digit.to_lower(),i+1,suffix],
                    side_name+"Hand"+digit+str(i+1),source_names,target_names)
    var idle: Animation = _clone_clip(player.get_animation(idle_key),source_names)
    var walk: Animation = _clone_clip(player.get_animation(walk_key),source_names)
    var jog: Animation = _clone_clip(player.get_animation(jog_key),source_names)
    if idle.get_track_count() < 18 or walk.get_track_count() < 18 or jog.get_track_count() < 18 or walk.length < 0.5:
        return false
    # Measure the visible original rig once in model/world coordinates.
    target.reset_bone_poses()
    target.force_update_all_bone_transforms()
    var head: Vector3 = target.to_global(target.get_bone_global_rest(_target_index("Head")).origin)
    var toe_left: Vector3 = target.to_global(target.get_bone_global_rest(_target_index("LeftToeBase")).origin)
    var toe_right: Vector3 = target.to_global(target.get_bone_global_rest(_target_index("RightToeBase")).origin)
    var low: float = minf(toe_left.y,toe_right.y)
    var span: float = head.y-low
    if span < 0.001:
        return false
    figure.scale *= 1.65/span
    target.force_update_all_bone_transforms()
    var sole: Vector3 = target.to_global(target.get_bone_global_rest(_target_index("LeftToeBase")).origin)
    figure.position.y += global_position.y + 0.035-sole.y
    # Save all skin references before changing hierarchy/names. Duplicate
    # named Skin resources, so the source asset and other NPCs stay intact.
    var meshes: Array[MeshInstance3D] = []
    for item in figure.find_children("*","MeshInstance3D",true,false):
        var mesh: MeshInstance3D = item as MeshInstance3D
        if mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == target:
            var skin: Skin = mesh.skin.duplicate(true) as Skin
            for i in range(skin.get_bind_count()):
                var bind_name: String = str(skin.get_bind_name(i))
                if target_names.has(bind_name):
                    skin.set_bind_name(i,StringName(target_names[bind_name]))
            mesh.skin = skin
            meshes.append(mesh)
    if meshes.is_empty():
        return false
    for item in source.find_children("*","MeshInstance3D",true,false):
        var mesh: MeshInstance3D = item as MeshInstance3D
        mesh.hide()
        mesh.skin = null
    _rename_bones(donor,source_names)
    _rename_bones(target,target_names)
    # RetargetModifier3D expects target Skeleton3D children. Keeping the
    # global transform preserves the imported skin scale and facing (+Z).
    modifier = RetargetModifier3D.new()
    modifier.name = "NativeHumanoidRetarget"
    modifier.profile = SkeletonProfileHumanoid.new()
    modifier.use_global_pose = false
    modifier.set_position_enabled(false)
    modifier.set_scale_enabled(false)
    donor.add_child(modifier)
    target.reparent(modifier,true)
    for mesh in meshes:
        mesh.skeleton = mesh.get_path_to(target)
        mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    # Only these authored clips are played, independent from the guard's
    # original idle. Never modify imported AnimationLibrary resources.
    var library: AnimationLibrary = AnimationLibrary.new()
    library.add_animation(&"Idle",idle)
    library.add_animation(&"WalkFormal",walk)
    library.add_animation(&"Jog",jog)
    player.add_animation_library(&"escort",library)
    idle_name = &"escort/Idle"
    walk_name = &"escort/WalkFormal"
    jog_name = &"escort/Jog"
    var blend_space: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
    blend_space.min_space = -WALK_STRIDE_SPEED
    blend_space.max_space = JOG_STRIDE_SPEED
    blend_space.add_blend_point(_clip_node(walk_name,true),-WALK_STRIDE_SPEED)
    blend_space.add_blend_point(_clip_node(idle_name,false),0.0)
    blend_space.add_blend_point(_clip_node(walk_name,false),WALK_STRIDE_SPEED)
    blend_space.add_blend_point(_clip_node(jog_name,false),JOG_STRIDE_SPEED)
    var graph: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
    graph.add_node(&"Locomotion",blend_space,Vector2(0,0))
    graph.add_node(&"Speed",AnimationNodeTimeScale.new(),Vector2(220,0))
    graph.connect_node(&"Speed",0,&"Locomotion")
    graph.connect_node(&"output",0,&"Speed")
    tree = AnimationTree.new()
    tree.name = "EscortLocomotion"
    player.get_parent().add_child(tree)
    tree.root_node = player.root_node
    tree.anim_player = tree.get_path_to(player)
    tree.tree_root = graph
    tree.deterministic = false
    tree.active = true
    tree.set("parameters/Locomotion/blend_position",0.0)
    tree.set("parameters/Speed/scale",1.0)
    ready_to_play = true
    return true

func _clip_node(key: StringName, reverse: bool) -> AnimationNodeAnimation:
    var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
    node.animation = key
    if reverse:
        node.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
    return node

func drive(signed_speed: float, delta: float) -> void:
    if not ready_to_play:
        return
    var desired: float = clampf(signed_speed,-WALK_STRIDE_SPEED,JOG_STRIDE_SPEED)
    blend = move_toward(blend,desired,delta*16.0)
    if absf(signed_speed)<0.035 and absf(blend)<0.04:
        blend = 0.0
    tree.set("parameters/Locomotion/blend_position",blend)
    # The weighted gait blend already accounts for slow motion. Scale
    # against its actual nominal stride rather than always a full walk.
    # The reverse cadence is deliberately bounded; fast escapes use Jog.
    var nominal: float = maxf(absf(blend),0.12)
    var rate: float = 1.0 if absf(signed_speed)<0.035 else clampf(absf(signed_speed)/nominal,0.35,2.2 if signed_speed<0.0 else 2.5)
    tree.set("parameters/Speed/scale",rate)
