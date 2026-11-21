@tool
extends Node3D
## Authored casino welcome desk. Replace the proxy by placing an imported
## glTF/GLB scene under ModelAnchor; no gameplay code depends on its rig.

const Loc = preload("res://gameplay/localization.gd")

@onready var character_pivot: Node3D = $CharacterPivot
@onready var model_anchor: Node3D = $CharacterPivot/ModelAnchor
@onready var placeholder: Node3D = $CharacterPivot/ProxyHuman
@onready var hint: Label3D = $InteractionHint

var _idle_clock := 0.0
var _playing_character: Node = null


func _ready() -> void:
    _sync_placeholder()
    if Engine.is_editor_hint():
        return
    hint.visible = false
    var settings = get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_settings_changed)
    _refresh_language()
    _play_model_idle()


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
    # Only a slight natural posture change; the imported model may supply
    # its own actual skeletal idle clip.
    if placeholder.visible:
        character_pivot.position.y = sin(_idle_clock * 1.45) * 0.006


func _sync_placeholder() -> void:
    if model_anchor != null and placeholder != null:
        placeholder.visible = model_anchor.get_child_count() == 0


func _play_model_idle() -> void:
    if model_anchor.get_child_count() == 0:
        return
    var animator := _find_animator(model_anchor)
    if animator == null:
        return
    for candidate in ["Idle", "idle", "IDLE", "Armature|Idle"]:
        if animator.has_animation(candidate):
            animator.play(candidate)
            return


func _find_animator(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
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
