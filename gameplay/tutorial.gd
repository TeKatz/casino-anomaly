extends Node3D
## The introduction uses only world-space cues: the starting door carries
## its own text, rather than projecting an interaction hint onto the screen.
const Loc = preload("res://gameplay/localization.gd")

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/Camera3D
@onready var door: Node3D = $ExitDoor

var hint: Label3D
var changing := false


func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    hint = Label3D.new()
    hint.name = "DoorHint"
    hint.position = Vector3(0, 3.60, 0.24)
    hint.font_size = 54
    hint.pixel_size = 0.0035
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.modulate = Color("#f1c987")
    hint.double_sided = false
    door.add_child(hint)
    var settings = get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_settings_changed)
    _refresh_hint()


func _refresh_hint() -> void:
    hint.text = Loc.t("tutorial.start", self)


func _on_settings_changed(key: String) -> void:
    if key == "language":
        _refresh_hint()


func _is_looking_at_door() -> bool:
    var center := door.global_position + Vector3(0, 1.6, 0)
    var towards: Vector3 = center - camera.global_position
    var distance := towards.length()
    if distance < 0.05 or distance > 3.0:
        return false
    # The starting door faces +Z; do not allow opening it from behind.
    if door.to_local(camera.global_position).z < 0.15:
        return false
    return (-camera.global_transform.basis.z).dot(towards / distance) >= 0.985


func _unhandled_input(event: InputEvent) -> void:
    if changing or not (event is InputEventKey):
        return
    if event.keycode != KEY_E or not event.pressed or event.echo:
        return
    if not _is_looking_at_door():
        return
    changing = true
    var state = get_node_or_null("/root/LoopState")
    if state != null:
        state.complete_tutorial()
    get_viewport().set_input_as_handled()
    get_tree().change_scene_to_file("res://main.tscn")
