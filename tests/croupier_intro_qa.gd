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
    if desk.position.x > -1.5:
        _fail("The welcome counter obstructs the main exit route")
        return
    var model_installed := ResourceLoader.exists("res://models/croupier/scene.gltf", "PackedScene")
    if model_installed:
        var character := anchor.get_node_or_null("BusinessMan") as Node3D
        var animator := desk.get("_animator") as AnimationPlayer
        if character == null or proxy.visible or animator == null:
            _fail("Imported business man, animation player or proxy switch missing")
            return
        if str(desk.call("_pick_animation", "idle")).is_empty() \
                or str(desk.call("_pick_animation", "talk")).is_empty():
            _fail("The imported model needs idle and talking clips")
            return
        _diagnose_model_geometry(desk, character)

    elif not proxy.visible or anchor.get_child_count() != 0:
        _fail("A missing source archive must keep the original proxy in the start room")
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
    var response := dialogue.get("response_label") as Label
    if response == null or not response.text.contains("Willkommen"):
        _fail("German welcome must be concise and visible")
        return
    dialogue.call("_on_choice", "rules")
    if not response.text.to_lower().contains("zwölf"):
        _fail("Rules must explain the required streak in German")
        return
    settings.set_option("language", "en")
    if hint.text != "E · Talk" or not response.text.to_lower().contains("twelve"):
        _fail("Bilingual text did not update live")
        return
    dialogue.call("close_conversation")
    # The headless display server cannot hold OS-level mouse capture; it
    # reports VISIBLE even after correctly requesting CAPTURED.
    var mouse_failed := DisplayServer.get_name() != "headless" \
            and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
    if bool(dialogue.get("active")) or bool(player.get("interaction_locked")) or mouse_failed:
        _fail("Closing conversation: active=%s locked=%s mouse_mode=%s" % [
            str(dialogue.get("active")), str(player.get("interaction_locked")),
            str(Input.mouse_mode)])
        return

    room.queue_free()
    await process_frame
    settings.set_option("language", prior)
    print("Casino Anomaly croupier welcome desk and dialogue QA PASS")
    quit(0)


func _diagnose_model_geometry(desk: Node3D, character: Node3D) -> void:
    var meshes: Array[MeshInstance3D] = []
    var all: Array[Node] = [character]
    while not all.is_empty():
        var node := all.pop_back()
        if node is MeshInstance3D:
            meshes.append(node)
        for child in node.get_children():
            all.append(child)
    var low := Vector3(INF, INF, INF)
    var high := Vector3(-INF, -INF, -INF)
    var anchor := desk.get_node("CharacterPivot/ModelAnchor") as Node3D
    for part in meshes:
        if part.mesh == null:
            continue
        var rect := part.mesh.get_aabb()
        for xi in range(2):
            for yi in range(2):
                for zi in range(2):
                    var local_point := rect.position + rect.size * Vector3(float(xi), float(yi), float(zi))
                    var anchored := anchor.to_local(part.to_global(local_point))
                    low = low.min(anchored)
                    high = high.max(anchored)
    print("CROUPIER_DIAGNOSTIC: mesh_count=", meshes.size(), " pose_aabb_min=", low, " max=", high, " dimensions=", high - low)
    print("CROUPIER_DIAGNOSTIC: character_local=", character.transform, " char_global=", character.global_transform)
    for part in meshes:
        print("CROUPIER_DIAGNOSTIC: mesh ", part.name, " aabb=", part.mesh.get_aabb() if part.mesh else "<none>", " global_transform=", part.global_transform)
    var all_skeletons: Array[Node] = [character]
    while not all_skeletons.is_empty():
        var n := all_skeletons.pop_back()
        if n is Skeleton3D:
            var skeleton := n as Skeleton3D
            for bone_i in skeleton.get_bone_count():
                var name := skeleton.get_bone_name(bone_i)
                if name.to_lower().contains("hips") or name.to_lower().contains("head") or name.to_lower().contains("foot"):
                    var pose := skeleton.get_bone_global_pose(bone_i)
                    print("CROUPIER_DIAGNOSTIC: bone=",name, " position=",anchor.to_local(skeleton.to_global(pose.origin)))
        for child in n.get_children():
            all_skeletons.append(child)
