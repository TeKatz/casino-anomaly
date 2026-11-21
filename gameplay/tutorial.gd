extends Node3D
## Optional short conversations; the starting door remains the way forward.
const Loc = preload("res://gameplay/localization.gd")
const Conversation = preload("res://gameplay/croupier_dialogue.gd")

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/Camera3D
@onready var door: Node3D = $ExitDoor
@onready var croupier: Node3D = $CroupierStation

var hint: Label3D
var conversation: CanvasLayer
var changing := false


func _ready() -> void:
    # The counter occupies the LEFT wall (x=-3.7), not the exit wall.
    # Keep the NPC inside its enclosed booth and facing the customers (+X).
    croupier.position = Vector3(-2.56, 0.0, 0.25)
    croupier.rotation.y = PI * 0.5
    _ensure_reception_collision()
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
    conversation = Conversation.new()
    conversation.name = "CroupierDialogue"
    add_child(conversation)
    conversation.closed.connect(_on_conversation_closed)
    var settings = get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_settings_changed)
    _refresh_hint()


func _ensure_reception_collision() -> void:
    # The three authored collision shapes also exist in tutorial.tscn.
    # Restoring only missing ones prevents imported-scene node loss from
    # leaving a gap that lets the player enter the staff-only pocket.
    var body := get_node_or_null("ReceptionCounterCollision") as StaticBody3D
    if body == null:
        body = StaticBody3D.new()
        body.name = "ReceptionCounterCollision"
        add_child(body)
    var specs: Array[Dictionary] = [
        {"name": "ReceptionLongCollider",
            "at": Vector3(-2.15, 0.52, 0.25),
            "size": Vector3(0.64, 1.04, 3.16)},
        {"name": "ReceptionFrontReturnCollider",
            "at": Vector3(-2.91, 0.52, -1.33),
            "size": Vector3(1.6, 1.04, 0.64)},
        {"name": "ReceptionRearReturnCollider",
            "at": Vector3(-2.91, 0.52, 1.83),
            "size": Vector3(1.6, 1.04, 0.64)}
    ]
    for spec in specs:
        var collider := body.get_node_or_null(str(spec["name"])) as CollisionShape3D
        if collider == null:
            collider = CollisionShape3D.new()
            collider.name = str(spec["name"])
            body.add_child(collider)
        collider.position = spec["at"]
        if not (collider.shape is BoxShape3D):
            var shape := BoxShape3D.new()
            shape.size = spec["size"]
            collider.shape = shape


func _refresh_hint() -> void:
    hint.text = Loc.t("tutorial.start", self)


func _on_settings_changed(key: String) -> void:
    if key == "language":
        _refresh_hint()


func _process(_delta: float) -> void:
    croupier.call("set_hint_visible", not changing and not is_dialogue_open() \
            and _is_looking_at_croupier())


func _is_looking_at_door() -> bool:
    var center := door.global_position + Vector3(0, 1.6, 0)
    var towards: Vector3 = center - camera.global_position
    var distance := towards.length()
    if distance < 0.05 or distance > 3.0:
        return false
    if door.to_local(camera.global_position).z < 0.15:
        return false
    return (-camera.global_transform.basis.z).dot(towards / distance) >= 0.985


func _is_looking_at_croupier() -> bool:
    # Target the face in station-local coordinates: moving the counter must
    # never detach the E trigger from the actual animated NPC.
    var center := croupier.to_global(Vector3(0, 1.53, -0.52))
    var towards: Vector3 = center - camera.global_position
    var distance := towards.length()
    if distance < 0.2 or distance > 3.35:
        return false
    if croupier.to_local(camera.global_position).z < 0.78:
        return false
    return (-camera.global_transform.basis.z).dot(towards / distance) >= 0.925


func is_dialogue_open() -> bool:
    return conversation != null and bool(conversation.get("active"))


func _open_conversation() -> void:
    if changing or is_dialogue_open():
        return
    player.call("set_interaction_locked", true)
    croupier.call("set_hint_visible", false)
    croupier.call("set_talking", true)
    conversation.call("show_conversation")


func _on_conversation_closed() -> void:
    if changing:
        return
    croupier.call("set_talking", false)
    player.call("set_interaction_locked", false)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
    if changing or is_dialogue_open() or not (event is InputEventKey):
        return
    if event.keycode != KEY_E or not event.pressed or event.echo:
        return
    if _is_looking_at_croupier():
        get_viewport().set_input_as_handled()
        _open_conversation()
        return
    if not _is_looking_at_door():
        return
    get_viewport().set_input_as_handled()
    var loader = get_node_or_null("/root/SceneLoader")
    if loader == null or not loader.travel_to("res://main.tscn", true):
        push_warning("Could not show the casino loading screen.")
        return
    changing = true
    loader.transition_failed.connect(_on_scene_load_failed, CONNECT_ONE_SHOT)


func _on_scene_load_failed(_path: String) -> void:
    changing = false
