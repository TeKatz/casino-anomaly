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
        var pose_error := _validate_model_pose(desk, character)
        if not pose_error.is_empty():
            _fail(pose_error)
            return
        var proportions_error := _validate_model_proportions(character)
        if not proportions_error.is_empty():
            _fail(proportions_error)
            return


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


func _validate_model_pose(desk: Node3D, character: Node3D) -> String:
    # Mesh AABBs cannot detect a wrongly rotated skinned character: the
    # bind-pose mesh stays Y-up even when the animated Skeleton3D lies flat.
    # Validate the actual animated bone landmarks in model-anchor space.
    var skeleton := _find_skeleton(character)
    if skeleton == null:
        return "The imported character lacks an animated Skeleton3D"
    var anchor := desk.get_node("CharacterPivot/ModelAnchor") as Node3D
    for name in ["Head_06", "Face_011", "Foot_L_065", "Foot_R_069"]:
        if skeleton.find_bone(name) < 0:
            return "The imported croupier is missing landmark bone: " + name
    var head := _bone_anchor_position(skeleton, anchor, "Head_06")
    var face := _bone_anchor_position(skeleton, anchor, "Face_011")
    var left_foot := _bone_anchor_position(skeleton, anchor, "Foot_L_065")
    var right_foot := _bone_anchor_position(skeleton, anchor, "Foot_R_069")
    var feet := (left_foot + right_foot) * 0.5
    var standing_height := head.y - feet.y
    if head.y < 1.4 or head.y > 2.1 or standing_height < 1.35 \
            or standing_height > 1.95 or absf(feet.y) > 0.2:
        return "Croupier rig is not standing on the floor. Head=%s feet=%s height=%.2f" % [
            str(head), str(feet), standing_height]
    if absf(head.x) > 0.3 or absf(head.z - feet.z) > 0.45:
        return "Croupier rig is displaced horizontally: head=%s feet=%s" % [
            str(head), str(feet)]
    if face.z <= head.z + 0.035:
        return "Croupier must face the customers at positive Z: face=%s head=%s" % [
            str(face), str(head)]
    return ""


func _bone_anchor_position(skeleton: Skeleton3D, anchor: Node3D, name: String) -> Vector3:
    var index := skeleton.find_bone(name)
    return anchor.to_local(skeleton.to_global(skeleton.get_bone_global_pose(index).origin))


func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var candidate := _find_skeleton(child)
        if candidate != null:
            return candidate
    return null


func _validate_model_proportions(character: Node3D) -> String:
    # Rig landmarks alone can pass even when FBX mesh transforms make the
    # character appear paper-thin. Check *world* bounds (never anchor-local:
    # that would discard inherited scale corrections).
    var nodes: Array[Node] = [character]
    var minimum := Vector3(INF, INF, INF)
    var maximum := Vector3(-INF, -INF, -INF)
    var meshes := 0
    while not nodes.is_empty():
        var node: Node = nodes.pop_back()
        if node is MeshInstance3D:
            var instance := node as MeshInstance3D
            if instance.mesh != null:
                meshes += 1
                var bounds := instance.mesh.get_aabb()
                for x in range(2):
                    for y in range(2):
                        for z in range(2):
                            var corner := bounds.position + bounds.size * Vector3(
                                float(x), float(y), float(z))
                            var world_corner := instance.to_global(corner)
                            minimum = minimum.min(world_corner)
                            maximum = maximum.max(world_corner)
        for child in node.get_children():
            nodes.append(child)
    if meshes < 3:
        return "The imported croupier lost its skinned body meshes"
    var dimensions := maximum - minimum
    print("CROUPIER_WORLD_PROPORTIONS: dimensions=", dimensions,
            " width/height=", dimensions.x / maxf(dimensions.y, 0.01),
            " depth/height=", dimensions.z / maxf(dimensions.y, 0.01))
    if dimensions.y < 1.3 or dimensions.y > 2.4:
        return "Croupier height is no longer realistic: %s" % str(dimensions)
    if dimensions.x < 0.52 or dimensions.x > 1.4 \
            or dimensions.z < 0.21 or dimensions.z > 0.9:
        return "Croupier is still too flat or has become too broad: %s" % str(dimensions)
    return ""
