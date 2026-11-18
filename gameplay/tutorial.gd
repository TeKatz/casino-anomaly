extends Node3D
## The small introductory room is an ordinary editable .tscn scene.

@onready var player: CharacterBody3D = $Player
@onready var door: Node3D = $ExitDoor

var hint: Label
var changing := false


func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    var layer := CanvasLayer.new()
    layer.name = "TutorialHUD"
    add_child(layer)
    var instructions := Label.new()
    instructions.name = "Instructions"
    instructions.position = Vector2(28, 28)
    instructions.add_theme_font_size_override("font_size", 19)
    instructions.add_theme_color_override("font_color", Color("#f3e6cf"))
    instructions.text = "CASINO ANOMALY   |   EINFÜHRUNG\n\nDu durchquerst immer denselben Flur.\nManchmal ist alles normal. Manchmal verändert sich ein Detail.\nMerke dir die Umgebung und triff am Ausgang deine Wahl:\n\nLINKS: Etwas stimmt nicht.     RECHTS: Alles ist normal.\nAcht richtige Entscheidungen in Folge führen hinaus.\nEin Fehler setzt nur deinen Fortschritt zurück."
    layer.add_child(instructions)
    hint = Label.new()
    hint.position = Vector2(28, 295)
    hint.add_theme_font_size_override("font_size", 20)
    hint.add_theme_color_override("font_color", Color("#f1c987"))
    layer.add_child(hint)


func _process(_delta: float) -> void:
    if changing:
        return
    var close_enough := player.global_position.distance_to(door.global_position + Vector3(0, 1.5, 0)) < 2.5
    hint.text = "E – Durch die Tür zum ersten Durchlauf" if close_enough else "WASD: bewegen  |  Maus: umsehen  |  E: Tür öffnen"


func _unhandled_input(event: InputEvent) -> void:
    if changing or not (event is InputEventKey):
        return
    if event.keycode != KEY_E or not event.pressed or event.echo:
        return
    if player.global_position.distance_to(door.global_position + Vector3(0, 1.5, 0)) > 2.5:
        return
    changing = true
    var state = get_node_or_null("/root/LoopState")
    if state != null:
        state.complete_tutorial()
    get_viewport().set_input_as_handled()
    get_tree().change_scene_to_file("res://main.tscn")
