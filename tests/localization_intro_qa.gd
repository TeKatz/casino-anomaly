extends SceneTree
## Regression for language persistence, gaze-only intro prompt and PBR door.
const INTRO = preload("res://gameplay/tutorial.tscn")
const Loc = preload("res://gameplay/localization.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("Casino localization/intro QA: " + message)
    quit(1)


func _run() -> void:
    var settings = root.get_node_or_null("GameSettings")
    if settings == null:
        _fail("Missing persistent settings")
        return
    var old_language = settings.get_option("language")
    settings.set_option("language", "en")
    if Loc.t("world.anomaly", root) != "ANOMALY":
        _fail("English translations are unavailable")
        return

    var intro := INTRO.instantiate() as Node3D
    root.add_child(intro)
    await process_frame
    var door := intro.get_node_or_null("ExitDoor") as Node3D
    var camera := intro.get_node_or_null("Player/Camera3D") as Camera3D
    var player := intro.get_node_or_null("Player") as CharacterBody3D
    var prompt := intro.get_node_or_null("DoorInteractionHUD/DoorHint") as Label
    var leaf := intro.get_node_or_null("ExitDoor/Door") as MeshInstance3D
    if door == null or camera == null or player == null or prompt == null or leaf == null:
        _fail("Starting room is missing the interaction or door")
        return
    var wood := leaf.material_override as StandardMaterial3D
    if wood == null or wood.albedo_texture == null or intro.get_node_or_null("ExitDoor/Handle") == null:
        _fail("Starting door must have textured wood, hardware and detailing")
        return

    player.position = Vector3(0, 1.02, -2.15)
    camera.look_at(door.global_position + Vector3(0, 1.6, 0), Vector3.UP)
    await process_frame
    if not bool(intro.call("_is_looking_at_door")) or prompt.text != "Press E to start":
        _fail("English E prompt must appear only while aiming at the nearby door")
        return

    camera.rotate_y(PI)
    await process_frame
    if bool(intro.call("_is_looking_at_door")) or not prompt.text.is_empty():
        _fail("Looking away must remove the interaction prompt")
        return

    settings.set_option("language", "de")
    camera.look_at(door.global_position + Vector3(0, 1.6, 0), Vector3.UP)
    await process_frame
    if prompt.text != "E drücken, um zu starten":
        _fail("Door prompt must translate instantly to German")
        return

    intro.queue_free()
    await process_frame
    settings.set_option("language", old_language)
    print("Casino Anomaly bilingual intro and door interaction QA PASS")
    quit(0)
