extends Node3D
## Minimal diegetic intro: interaction only when looking directly at the
## starting door. No permanent tutorial text or gameplay status overlay.
const Loc = preload("res://gameplay/localization.gd")

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/Camera3D
@onready var door: Node3D = $ExitDoor

var hint: Label
var changing := false


func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    var layer := CanvasLayer.new()
    layer.name = "DoorInteractionHUD"
    layer.layer = 2
    add_child(layer)
    hint = Label.new()
    hint.name = "DoorHint"
    hint.anchor_left = 0.5
    hint.anchor_right = 0.5
    hint.anchor_top = 1.0
    hint.anchor_bottom = 1.0
    hint.offset_left = -240
    hint.offset_right = 240
    hint.offset_top = -95
    hint.offset_bottom = -48
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 23)
    hint.add_theme_color_override("font_color", Color("#f1c987"))
    layer.add_child(hint)


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


func _process(_delta: float) -> void:
    if changing:
        hint.text = ""
        return
    hint.text = Loc.t("tutorial.start", self) if _is_looking_at_door() else ""


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
