extends Node3D
## Optional short conversations; the starting door remains the way forward.
const Controls = preload("res://gameplay/input_bindings.gd")
const Loc = preload("res://gameplay/localization.gd")
const Conversation = preload("res://gameplay/croupier_dialogue.gd")
const DoorPrompt = preload("res://ui/door_prompt.gd")

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/Camera3D
@onready var door: Node3D = $ExitDoor
@onready var croupier: Node3D = $CroupierStation

var door_prompt: CanvasLayer
var conversation: CanvasLayer
var changing := false


func _ready() -> void:
    # The counter occupies the LEFT wall (x=-3.7), not the exit wall.
    # Keep the NPC inside its enclosed booth and facing the customers (+X).
    croupier.position = Vector3(-2.56, 0.0, 0.25)
    croupier.rotation.y = PI * 0.5
    _ensure_reception_collision()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    door_prompt = DoorPrompt.new()
    door_prompt.name = "DoorInteractionHUD"
    add_child(door_prompt)
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
    door_prompt.call("set_prompt_text", Loc.t("tutorial.enter", self))


func _on_settings_changed(key: String) -> void:
    if key == "language":
        _refresh_hint()


func _process(_delta: float) -> void:
    var can_interact := not changing and not is_dialogue_open() and not get_tree().paused
    croupier.call("set_hint_visible", can_interact and _is_looking_at_croupier())
    door_prompt.call("set_prompt_visible", can_interact and _is_looking_at_door())


func _is_looking_at_door() -> bool:
    # Aim at the actual DOOR PANEL rather than a tiny point in its centre.
    # The old .985 dot threshold demanded an almost exact viewing angle.
    # Project the camera's sight line onto the door plane in door-local
    # space. This tracks the designer's door transforms, including scale.
    var eye := door.to_local(camera.global_position)
    if eye.z < 0.15 or eye.z > 5.0:
        return false
    var view_world := -camera.global_transform.basis.z
    var forward := door.to_local(camera.global_position + view_world) - eye
    if forward.z >= -0.15:
        return false
    var hit := eye + forward * (eye.z / -forward.z)
    # Authored door: 1.85m wide x 3.15m tall in local units. A small
    # allowance around the frame makes the E prompt comfortable, without
    # activating when looking sideways down the hallway.
    return absf(hit.x) <= 1.18 and hit.y >= 0.05 and hit.y <= 3.30


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
    player.call("interaction_vibration")
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
    if changing or is_dialogue_open():
        return
    if not Controls.pressed(event, "interact"):
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
    player.call("interaction_vibration")
    changing = true
    loader.transition_failed.connect(_on_scene_load_failed, CONNECT_ONE_SHOT)


func _on_scene_load_failed(_path: String) -> void:
    changing = false
