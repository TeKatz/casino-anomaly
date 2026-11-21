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
@export var imported_model_proportions := Vector3(1.6, 1.0, 2.05)
@export_range(0.5, 1.5, 0.05) var imported_model_scale := 1.0
@export var imported_model_offset := Vector3.ZERO

@onready var character_pivot: Node3D = $CharacterPivot
@onready var model_anchor: Node3D = $CharacterPivot/ModelAnchor
@onready var hint: Label3D = $InteractionHint

var _idle_clock := 0.0
var _animator: AnimationPlayer
var _talking := false
var _active_animation := ""


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
    _play_character_animation()


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
    if _talking == value:
        return
    _talking = value
    _play_character_animation()


func _play_character_animation() -> void:
    if _animator == null or Engine.is_editor_hint():
        return
    var selected := _pick_animation("talk" if _talking else "idle")
    if selected.is_empty() or selected == _active_animation:
        return
    var clip := _animator.get_animation(selected)
    if clip != null:
        clip.loop_mode = Animation.LOOP_LINEAR
    _animator.play(selected, 0.2)
    _active_animation = selected


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
