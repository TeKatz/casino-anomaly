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

    # Translation must be safe for the next hall even BEFORE it is attached
    # to the tree; streaming opens translated exit signs at that stage.
    var loose_node := Node3D.new()
    if Loc.t("world.anomaly", loose_node) != "ANOMALY":
        _fail("Off-tree staged translation did not use the current language")
        return
    loose_node.free()

    var intro := INTRO.instantiate() as Node3D
    root.add_child(intro)
    await process_frame
    var door := intro.get_node_or_null("SideGalleries/EastGallery/AccessBays/MainCasinoEntrance") as Node3D
    var camera := intro.get_node_or_null("Player/Camera3D") as Camera3D
    var player := intro.get_node_or_null("Player") as CharacterBody3D
    var prompt := intro.get_node_or_null("DoorInteractionHUD") as CanvasLayer
    var old_sign := intro.get_node_or_null("SideGalleries/EastGallery/AccessBays/MainCasinoEntrance/DoorHint")
    var leaf := intro.get_node_or_null("SideGalleries/EastGallery/AccessBays/MainCasinoEntrance/ClosedLeaf/Mesh") as MeshInstance3D
    if door == null or camera == null or player == null or prompt == null or leaf == null:
        _fail("Starting room is missing the interaction or door")
        return
    var wood := leaf.material_override as StandardMaterial3D
    if wood == null or wood.albedo_texture == null or intro.get_node_or_null("SideGalleries/EastGallery/AccessBays/MainCasinoEntrance/LeftHandle") == null:
        _fail("Starting door must have textured wood, hardware and detailing")
        return

    if old_sign != null or prompt.get_node_or_null("Root/Prompt") == null:
        _fail("The old floating door lettering must be replaced by a HUD prompt")
        return
    if bool(prompt.get("_shown")):
        _fail("The door prompt must be hidden outside interaction range")
        return
    player.global_position = door.to_global(Vector3(0,1.02,2.15))
    camera.look_at(door.global_position + Vector3(0, 1.6, 0), Vector3.UP)
    await process_frame
    if not bool(intro.call("_is_looking_at_door")) or not bool(prompt.get("_shown")) \
            or (prompt.get("caption") as Label).text != "Enter the casino":
        _fail("English HUD prompt must only appear when looking at the door")
        return

    camera.rotate_y(PI)
    await process_frame
    if bool(intro.call("_is_looking_at_door")) or bool(prompt.get("_shown")):
        _fail("Door HUD prompt must disappear when looking away")
        return

    settings.set_option("language", "de")
    camera.look_at(door.global_position + Vector3(0, 1.6, 0), Vector3.UP)
    await process_frame
    if (prompt.get("caption") as Label).text != "Casino betreten" or not bool(prompt.get("_shown")):
        _fail("Door HUD prompt must translate instantly to German")
        return

    intro.queue_free()
    await process_frame
    settings.set_option("language", old_language)
    print("Casino Anomaly bilingual intro and door interaction QA PASS")
    quit(0)
