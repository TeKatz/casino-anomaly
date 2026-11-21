extends SceneTree
## Intro desk, model drop-in, bilingual dialogue, input locking and exit regression.
const INTRO = preload("res://gameplay/tutorial.tscn")
const Loc = preload("res://gameplay/localization.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("Casino croupier intro QA: " + message)
    quit(1)


func _run() -> void:
    var settings = root.get_node_or_null("GameSettings")
    var prior = settings.get_option("language")
    settings.set_option("language", "de")
    var room := INTRO.instantiate() as Node3D
    root.add_child(room)
    await process_frame

    var desk := room.get_node_or_null("CroupierStation") as Node3D
    var collision := room.get_node_or_null("CroupierStation/CounterCollision/CounterShape") as CollisionShape3D
    var anchor := room.get_node_or_null("CroupierStation/CharacterPivot/ModelAnchor") as Node3D
    var proxy := room.get_node_or_null("CroupierStation/CharacterPivot/Face") as MeshInstance3D
    var hint := room.get_node_or_null("CroupierStation/InteractionHint") as Label3D
    var player := room.get_node_or_null("Player") as CharacterBody3D
    var camera := room.get_node_or_null("Player/Camera3D") as Camera3D
    var dialogue := room.get_node_or_null("CroupierDialogue") as CanvasLayer
    if desk == null or collision == null or anchor == null or proxy == null \
            or hint == null or player == null or camera == null or dialogue == null:
        _fail("Desk scene, collision, model anchor, proxy or conversation is missing")
        return
    if desk.position.x > -1.5 or not proxy.visible or anchor.get_child_count() != 0:
        _fail("The desk must stand aside and retain a clean model replacement anchor")
        return
    if hint.text != "E · Sprechen":
        _fail("German interaction cue is missing")
        return

    player.position = Vector3(-2.0, 1.02, 1.4)
    camera.look_at(desk.global_position + Vector3(0, 1.48, -0.38), Vector3.UP)
    await process_frame
    if not bool(room.call("_is_looking_at_croupier")):
        _fail("Looking at the croupier from the customer side must allow interaction")
        return
    if bool(room.call("_is_looking_at_door")):
        _fail("The start door must not steal the croupier interaction")
        return

    room.call("_open_conversation")
    await process_frame
    if not bool(dialogue.get("active")) or not bool(player.get("interaction_locked")):
        _fail("Opening dialogue must activate the panel and lock movement")
        return
    if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
        _fail("Dialogue must release the mouse for its buttons")
        return
    var response := dialogue.get_node("CroupierOverlay/DialoguePanel/MarginContainer/VBoxContainer/Response") as Label
    if response == null or not response.text.contains("Willkommen"):
        _fail("German welcome must be concise and visible")
        return
    dialogue.call("_on_choice", "rules")
    if not response.text.to_lower().contains("zwölf"):
        _fail("Rules must explain the required streak in German")
        return
    settings.set_option("language", "en")
    if hint.text != "E · Talk" or not response.text.contains("twelve"):
        _fail("Bilingual text did not update live")
        return
    dialogue.call("close_conversation")
    if bool(dialogue.get("active")) or bool(player.get("interaction_locked")) \
            or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        _fail("Closing a conversation must restore first-person controls")
        return

    room.queue_free()
    await process_frame
    settings.set_option("language", prior)
    print("Casino Anomaly croupier welcome desk and dialogue QA PASS")
    quit(0)
