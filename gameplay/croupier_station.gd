@tool
extends Node3D
## Lightweight editor-visible welcoming NPC; a pinned, local glTF replaces
## the primitive proxy as soon as the licensed Sketchfab source is imported.
const Loc = preload("res://gameplay/localization.gd")
const MODEL_PATH := "res://models/croupier/scene.gltf"

# Godot resolves the nested Sketchfab/FBX axis transforms during glTF import.
# The character is already Y-up and faces the customer (+Z): do not rotate
# it by an additional 90 degrees or the skinned rig lies on the ground.
@export var imported_model_rotation := Vector3.ZERO
# This FBX-to-glTF import renders unnaturally narrow in Godot (both from
# the front and the side). Correct width/depth at the outer model root; keep
# the original height and the skeleton/animations intact.
@export var imported_model_proportions := Vector3(1.95, 1.24, 2.1)
@export_range(0.5, 1.5, 0.05) var imported_model_scale := 1.0
@export var imported_model_offset := Vector3.ZERO

@onready var character_pivot: Node3D = $CharacterPivot
@onready var model_anchor: Node3D = $CharacterPivot/ModelAnchor
@onready var hint: Label3D = $InteractionHint

var _idle_clock := 0.0
var _animator: AnimationPlayer
var _animation_tree: AnimationTree
var _talking := false


func _ready() -> void:
    _try_load_model()
    _sync_placeholder()
    if Engine.is_editor_hint():
        return
    hint.visible = false
    var settings = get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_settings_changed)
    _refresh_language()
    _setup_character_animations()


func _try_load_model() -> void:
    if model_anchor.get_child_count() > 0:
        _animator = _find_animator(model_anchor)
        return
    if not ResourceLoader.exists(MODEL_PATH, "PackedScene"):
        return
    var packed := ResourceLoader.load(MODEL_PATH, "PackedScene") as PackedScene
    if packed == null:
        push_warning("The croupier model could not be imported: " + MODEL_PATH)
        return
    var character := packed.instantiate() as Node3D
    if character == null:
        push_warning("The imported croupier model is not a 3D scene")
        return
    character.name = "BusinessMan"
    character.rotation_degrees = imported_model_rotation
    character.scale = imported_model_proportions * imported_model_scale
    character.position = imported_model_offset
    model_anchor.add_child(character)
    _animator = _find_animator(character)


func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        _sync_placeholder()
        return
    _idle_clock += delta
    var target_yaw := 0.0
    var player := get_parent().get_node_or_null("Player") as Node3D
    if player != null and player.global_position.distance_to(global_position) < 4.5:
        var delta_position: Vector3 = player.global_position - character_pivot.global_position
        target_yaw = clampf(atan2(delta_position.x, delta_position.z), -0.32, 0.32)
    character_pivot.rotation.y = lerpf(character_pivot.rotation.y, target_yaw, minf(delta * 3.0, 1.0))
    if model_anchor.get_child_count() == 0:
        character_pivot.position.y = sin(_idle_clock * 1.45) * 0.006


func _sync_placeholder() -> void:
    if model_anchor == null or character_pivot == null:
        return
    var show_proxy := model_anchor.get_child_count() == 0
    for part in character_pivot.get_children():
        if part is MeshInstance3D:
            (part as MeshInstance3D).visible = show_proxy


func set_talking(value: bool) -> void:
    _talking = value
    if _animation_tree != null:
        # The idle body pose must remain active. Only mouth/jaw tracks are
        # layered onto it, otherwise this face-only clip produces a T-pose.
        _animation_tree.set("parameters/Speech/blend_amount", 1.0 if value else 0.0)


func _setup_character_animations() -> void:
    if _animator == null or Engine.is_editor_hint():
        return
    var idle_name := _pick_animation("idle")
    if idle_name.is_empty():
        return
    var idle_clip := _animator.get_animation(idle_name)
    idle_clip.loop_mode = Animation.LOOP_LINEAR

    var talk_name := _pick_animation("talk")
    if talk_name.is_empty():
        # For other optional NPC models, do not drop the body's idle pose
        # just because a facial animation is not present.
        _animator.play(idle_name)
        return
    var speech_clip := _animator.get_animation(talk_name)
    speech_clip.loop_mode = Animation.LOOP_LINEAR

    var idle_node := AnimationNodeAnimation.new()
    idle_node.animation = idle_name
    var speech_node := AnimationNodeAnimation.new()
    speech_node.animation = talk_name

    var speech_mix := AnimationNodeBlend2.new()
    speech_mix.filter_enabled = true
    speech_mix.sync = true
    # The source 'Rig|cycle_talking' contains only facial-bone tracks.
    # In particular it has NO arms, torso or leg animation at all.
    for index in range(speech_clip.get_track_count()):
        speech_mix.set_filter_path(speech_clip.track_get_path(index), true)

    var graph := AnimationNodeBlendTree.new()
    graph.add_node("Idle", idle_node, Vector2(0, 0))
    graph.add_node("TalkingFace", speech_node, Vector2(0, 160))
    graph.add_node("Speech", speech_mix, Vector2(240, 90))
    graph.connect_node("Speech", 0, "Idle")
    graph.connect_node("Speech", 1, "TalkingFace")
    graph.connect_node("output", 0, "Speech")

    _animation_tree = AnimationTree.new()
    _animation_tree.name = "CroupierAnimationTree"
    model_anchor.add_child(_animation_tree)
    _animation_tree.anim_player = _animation_tree.get_path_to(_animator)
    _animation_tree.tree_root = graph
    # Keep idle running throughout the conversation, even while the
    # talking overlay is at full weight.
    _animation_tree.active = true
    _animation_tree.set("parameters/Speech/blend_amount", 1.0 if _talking else 0.0)


func _pick_animation(kind: String) -> String:
    if _animator == null:
        return ""
    var expected := "Rig|cycle_talking" if kind == "talk" else "Rig|idle"
    if _animator.has_animation(expected):
        return expected
    var candidates: PackedStringArray = _animator.get_animation_list()
    for name in candidates:
        var simple := name.to_lower()
        if kind == "talk" and simple.contains("cycle_talking"):
            return name
        if kind == "idle" and simple.ends_with("idle") and not simple.contains("sitting"):
            return name
    return ""


func _find_animator(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer and (node as AnimationPlayer).get_animation_list().size() > 0:
        return node as AnimationPlayer
    for child in node.get_children():
        var candidate := _find_animator(child)
        if candidate != null:
            return candidate
    return null


func _on_settings_changed(key: String) -> void:
    if key == "language":
        _refresh_language()


func _refresh_language() -> void:
    hint.text = Loc.t("croupier.prompt", self)


func set_hint_visible(enabled: bool) -> void:
    hint.visible = enabled
