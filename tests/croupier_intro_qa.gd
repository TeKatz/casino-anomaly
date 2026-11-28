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
    var guidance_options := {}
    for key in ["hud_visible","interaction_hints","tutorial_hints","reduced_motion"]:
        guidance_options[key] = settings.get_option(key)
        settings.set_option(key, key != "reduced_motion")
    settings.set_option("language", "de")
    var room := INTRO.instantiate() as Node3D
    root.add_child(room)
    await process_frame

    var desk := room.get_node_or_null("CroupierStation") as Node3D
    var counter := room.get_node_or_null("Reception/Counter/Front") as StaticBody3D
    var front_shape := room.get_node_or_null("Reception/Counter/Front/CollisionShape3D") as CollisionShape3D
    var front_end := room.get_node_or_null("Reception/Counter/WestReturn/CollisionShape3D") as CollisionShape3D
    var rear_end := room.get_node_or_null("Reception/Counter/EastReturn/CollisionShape3D") as CollisionShape3D
    var front := room.get_node_or_null("Reception/Counter/Front/Mesh") as MeshInstance3D
    var top := room.get_node_or_null("Reception/Counter/Countertop/Mesh") as MeshInstance3D
    var return_front := room.get_node_or_null("Reception/Counter/WestReturn/Mesh") as MeshInstance3D
    var return_rear := room.get_node_or_null("Reception/Counter/EastReturn/Mesh") as MeshInstance3D
    var npc_body := room.get_node_or_null("CroupierStation/CroupierCollision") as StaticBody3D
    var npc_shape := room.get_node_or_null("CroupierStation/CroupierCollision/BodyShape") as CollisionShape3D
    var anchor := room.get_node_or_null("CroupierStation/CharacterPivot/ModelAnchor") as Node3D
    var proxy := room.get_node_or_null("CroupierStation/CharacterPivot/Face") as MeshInstance3D
    var hint := room.get_node_or_null("CroupierStation/InteractionHint") as Node3D
    var player := room.get_node_or_null("Player") as CharacterBody3D
    var camera := room.get_node_or_null("Player/Camera3D") as Camera3D
    var dialogue := room.get_node_or_null("CroupierDialogue") as CanvasLayer
    if desk == null or counter == null or front_shape == null or front_end == null \
            or rear_end == null or front == null or top == null \
            or return_front == null or return_rear == null \
            or npc_body == null or npc_shape == null or anchor == null \
            or proxy == null or hint == null or player == null \
            or camera == null or dialogue == null:
        _fail("Missing reception geometry, wall returns, model, or dialogue")
        return
    if desk.position.distance_to(Vector3(0,0,-7.08)) > 0.02 or absf(desk.rotation.y)>0.03:
        _fail("Croupier is not behind the central reception facing the entrance")
        return
    if room.get_node_or_null("ReceptionCounterCollision") != null or desk.get_node_or_null("CounterCollision") != null:
        _fail("Old reception collision was duplicated")
        return
    var front_box := front_shape.shape as BoxShape3D
    var near_box := front_end.shape as BoxShape3D
    var far_box := rear_end.shape as BoxShape3D
    if front_box == null or near_box == null or far_box == null or front_box.size.x<6.0 or near_box.size.z<1.0 or far_box.size.z<1.0:
        _fail("Central reception counter requires three full solid sections")
        return
    var counter_bounds: AABB = front.global_transform*front.get_aabb()
    var npc_capsule := npc_shape.shape as CapsuleShape3D
    if npc_capsule == null or npc_capsule.radius<0.33 or npc_capsule.height<1.6:
        _fail("Croupier collision capsule regressed")
        return
    if npc_shape.global_position.z+npc_capsule.radius>=counter_bounds.position.z or absf(npc_shape.global_position.x)>0.30:
        _fail("Croupier intersects counter or is displaced from the center")
        return
    var top_bounds: AABB = top.global_transform*top.get_aabb()
    if absf(top_bounds.end.y-1.09)>0.015 or counter_bounds.position.y>0.02:
        _fail("Countertop or grounded front has incorrect dimensions")
        return
    for part in [front,top,return_front,return_rear]:
        var finish := part.get_active_material(0) as StandardMaterial3D
        if finish == null or finish.albedo_texture == null or not finish.normal_enabled or finish.normal_texture == null:
            _fail("Reception surface lost its PBR finish: "+part.name)
            return
    await physics_frame
    var world := room.get_world_3d().direct_space_state
    for check in [
        [Vector3(0,0.75,-5.2),Vector3(0,0.75,-7.0),counter],
        [Vector3(-3.8,0.75,-7.38),Vector3(-2.2,0.75,-7.38),room.get_node("Reception/Counter/WestReturn")],
        [Vector3(3.8,0.75,-7.38),Vector3(2.2,0.75,-7.38),room.get_node("Reception/Counter/EastReturn")]
    ]:
        var params := PhysicsRayQueryParameters3D.create(check[0],check[1])
        var hit := world.intersect_ray(params)
        if hit.is_empty() or hit.get("collider") != check[2]:
            _fail("Player can pass through an authored counter section")
            return
    var npc_ray := PhysicsRayQueryParameters3D.create(npc_shape.global_position+Vector3(0,0,-0.9),npc_shape.global_position)
    var npc_hit := world.intersect_ray(npc_ray)
    if npc_hit.is_empty() or npc_hit.get("collider") != npc_body:
        _fail("Croupier body collision is broken")
        return

    var model_installed := ResourceLoader.exists("res://models/croupier/scene.gltf", "PackedScene")
    var character: Node3D = null
    if model_installed:
        character = anchor.get_node_or_null("BusinessMan") as Node3D
        var animator := desk.get("_animator") as AnimationPlayer
        if character == null or proxy.visible or animator == null:
            _fail("Imported business man, animation player or proxy switch missing")
            return
        var idle_name := str(desk.call("_pick_animation", "idle"))
        var talk_name := str(desk.call("_pick_animation", "talk"))
        if idle_name.is_empty() or talk_name.is_empty():
            _fail("The imported model needs idle and talking clips")
            return
        var speech := animator.get_animation(talk_name)
        var idle := animator.get_animation(idle_name)
        print("CROUPIER_CLIP_TRACKS: idle=", idle.get_track_count(),
                " facial_speech=", speech.get_track_count())
        if speech.get_track_count() < 10 or idle.get_track_count() < 10:
            _fail("The imported idle or speech clips have no bone tracks")
            return
        var anim_tree := desk.get("_animation_tree") as AnimationTree
        if anim_tree == null or not anim_tree.active:
            _fail("The imported model must have an active facial-overlay AnimationTree")
            return
        var graph := anim_tree.tree_root as AnimationNodeBlendTree
        var speech_mix := graph.get_node("Speech") as AnimationNodeBlend2
        if speech_mix == null or not speech_mix.filter_enabled:
            _fail("Talking animation must be masked to facial tracks")
            return
        # Godot imports 84 tracks into both clips, despite the source
        # talking clip containing just eleven mouth/jaw channels.
        var facial_paths := 0
        for track in range(speech.get_track_count()):
            var path := speech.track_get_path(track)
            var name := str(path).to_lower()
            var intended := bool(desk.call("_is_talking_facial_track", path))
            if intended:
                facial_paths += 1
                if not speech_mix.is_path_filtered(path):
                    _fail("Missing facial track from mask: " + name)
                    return
            elif speech_mix.is_path_filtered(path):
                _fail("Talking mask wrongly includes a body track: " + name)
                return
        print("CROUPIER_FACIAL_MASK: face=", facial_paths,
                " imported_talking_tracks=", speech.get_track_count())
        if facial_paths < 5 or facial_paths >= speech.get_track_count():
            _fail("The talking filter must only include facial tracks, not reset-pose tracks")
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
    var prompt_sprite := hint.get_node_or_null("PromptSprite") as Sprite3D
    var prompt_caption := hint.get("caption") as Label
    if str(hint.get("prompt_text")) != "E · Sprechen" or prompt_caption == null \
            or prompt_caption.text != "Sprechen" or prompt_sprite == null \
            or prompt_sprite.texture == null:
        _fail("German croupier keycap/plaque is missing or not localized")
        return
    if hint.position.distance_to(Vector3(0, 2.15, -0.45)) > 0.035:
        _fail("The upgraded talking plaque moved away from above the NPC")
        return

    # Customer side is room-facing (+Z), beyond the solid counter.
    player.position = Vector3(0, 1.02, -5.10)
    camera.look_at(anchor.to_global(Vector3(0, 1.53, 0)), Vector3.UP)
    await process_frame
    if not bool(room.call("_is_looking_at_croupier")):
        _fail("Looking at the croupier from the customer side must allow interaction")
        return
    if bool(room.call("_is_looking_at_door")):
        _fail("The start door must not steal the croupier interaction")
        return
    # Confirm looking at the NPC from the rear staff area cannot
    # masquerade as an accessible customer-side interaction.
    var candidate := player.position
    player.position = Vector3(0, 1.02, -8.65)
    camera.look_at(anchor.to_global(Vector3(0, 1.53, 0)), Vector3.UP)
    await process_frame
    if bool(room.call("_is_looking_at_croupier")):
        _fail("The talking prompt must only be available in front of the counter")
        return
    player.position = candidate
    camera.look_at(anchor.to_global(Vector3(0, 1.53, 0)), Vector3.UP)
    await process_frame
    if not bool(room.call("_is_looking_at_croupier")):
        _fail("Returning to the customer side must restore the talking trigger")
        return

    var marker := room.get_node("SideGalleries/EastGallery/AccessBays/MainCasinoEntrance/DestinationMarker") as Node3D
    var marker_home := marker.position
    if marker.visible or bool(room.get("has_spoken")):
        _fail("Destination marker appeared before the conversation")
        return
    var idle_hands := _hand_positions(anchor, character) if model_installed else PackedVector3Array()
    var talk := InputEventAction.new()
    talk.action = "casino_interact"
    talk.pressed = true
    room.call("_unhandled_input",talk)
    await process_frame
    await process_frame
    if model_installed:
        var active_tree := desk.get("_animation_tree") as AnimationTree
        if not is_equal_approx(float(active_tree.get("parameters/Speech/blend_amount")), 1.0):
            _fail("The facial overlay did not activate during conversation")
            return
        var talk_hands := _hand_positions(anchor, character)
        print("CROUPIER_DIALOGUE_BODY_TEST: idle_hands=", idle_hands, " talk_hands=", talk_hands)
        if idle_hands.size() != 2 or talk_hands.size() != 2                 or idle_hands[0].distance_to(talk_hands[0]) > 0.34                 or idle_hands[1].distance_to(talk_hands[1]) > 0.34:
            _fail("Body animation reset when speaking: the croupier enters a T-pose")
            return
    if not bool(dialogue.get("active")) or not bool(player.get("interaction_locked")):
        _fail("Opening dialogue must activate the panel and lock movement")
        return
    if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
        _fail("Dialogue must release the mouse for its buttons")
        return
    var response := dialogue.get("response_label") as Label
    var objective := player.get_node_or_null("ObjectiveHUD") as CanvasLayer
    if objective == null or (objective.get("card") as Control).visible:
        _fail("Objective appeared before useful dialogue")
        return
    if response == null or not response.text.contains("Willkommen") or marker.visible:
        _fail("German welcome must be concise and visible")
        return
    var choices: Dictionary = dialogue.get("buttons")
    for choice_id in ["rules", "anomalies", "casino", "leave"]:
        var choice := choices.get(choice_id) as Button
        if choice == null or choice.get_script() == null or not (choice.get_theme_stylebox("normal") is StyleBoxTexture) \
                or not choice.has_meta("_ui_click_attached"):
            _fail("Dialogue buttons must share the premium theme and UI click feedback")
            return
    # Opening and closing without reading an informative topic must not
    # grant an objective. Preserve the NPC animation and input contracts.
    dialogue.call("close_conversation")
    if marker.visible or bool(room.get("has_spoken")) or (objective.get("card") as Control).visible:
        _fail("Empty conversation granted a destination objective")
        return
    room.call("_open_conversation")
    dialogue.call("_on_choice","rules")
    if not response.text.contains("Vergleich") or marker.visible or (objective.get("card") as Control).visible:
        _fail("Reference explanation or deferred objective incorrect")
        return
    dialogue.call("_next_page")
    if not response.text.contains("ANOMALIE") or not response.text.contains("NORMAL"):
        _fail("Decision instructions missing")
        return
    dialogue.call("_next_page")
    if not response.text.to_lower().contains("zwölf"):
        _fail("Rules must explain the required Classic streak in German")
        return
    dialogue.call("_previous_page")
    if not response.text.contains("ANOMALIE"):
        _fail("Back navigation did not restore the previous line")
        return
    dialogue.call("_next_page")
    settings.set_option("language", "en")
    if str(hint.get("prompt_text")) != "E · Talk" or prompt_caption.text != "Talk" \
            or not response.text.to_lower().contains("twelve"):
        _fail("Bilingual text did not update live")
        return
    dialogue.call("close_conversation")
    if not marker.visible or not bool(room.get("has_spoken")) or not (objective.get("card") as Control).visible or str(objective.get("objective_id"))!="enter_main_casino":
        _fail("Closing informative dialogue did not reveal the destination objective")
        return
    var objective_text := objective.get("message") as Label
    if not objective_text.text.contains("Main Casino"):
        _fail("Objective was not localized in English")
        return
    settings.set_option("language","de")
    if not objective_text.text.contains("Hauptcasino"):
        _fail("Objective did not translate live")
        return
    settings.set_option("language","en")
    room.call("_update_destination_marker",0.7)
    if absf(marker.position.y-marker_home.y)<0.05 or absf(marker.position.y-marker_home.y)>0.121 or not is_equal_approx(marker.position.z,marker_home.z):
        _fail("Destination marker hover is not bounded and vertical")
        return
    settings.set_option("reduced_motion",true)
    room.call("_update_destination_marker",0.7)
    if not marker.visible or not marker.position.is_equal_approx(marker_home) or not is_equal_approx((objective.get("card") as Control).modulate.a,1.0):
        _fail("Reduced motion must keep a stationary destination marker")
        return
    for key in ["hud_visible","interaction_hints","tutorial_hints"]:
        settings.set_option(key,false)
        if marker.visible or (objective.get("card") as Control).visible:
            _fail("Destination guidance ignored "+key)
            return
        settings.set_option(key,true)
        if not marker.visible or not (objective.get("card") as Control).visible:
            _fail("Destination guidance did not restore after "+key)
            return
    paused = true
    objective.call("_process",0.0)
    if (objective.get("card") as Control).visible:
        paused = false
        _fail("Objective HUD remained visible during pause")
        return
    paused = false
    objective.call("_process",0.0)
    if not (objective.get("card") as Control).visible:
        _fail("Objective HUD did not restore after pause")
        return
    room.call("_open_conversation")
    if marker.visible or (objective.get("card") as Control).visible:
        _fail("Destination guidance remained visible during repeated dialogue")
        return
    dialogue.call("close_conversation")
    if not marker.visible or not (objective.get("card") as Control).visible:
        _fail("Repeated dialogue lost destination guidance")
        return
    if model_installed:
        var idle_tree := desk.get("_animation_tree") as AnimationTree
        if not is_equal_approx(float(idle_tree.get("parameters/Speech/blend_amount")), 0.0):
            _fail("The facial overlay must stop after dialogue while idle continues")
            return
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
    # Test the actual live scene's alternate conversation configuration,
    # including the extra recognition question and normal objective flow.
    var state := root.get_node_or_null("LoopState")
    var previous_returning := bool(state.get("returning_guest"))
    state.set("returning_guest",true)
    settings.set_option("language","de")
    var returning_room := INTRO.instantiate() as Node3D
    root.add_child(returning_room)
    await process_frame
    var returning_dialogue := returning_room.get_node("CroupierDialogue")
    returning_room.call("_open_conversation")
    var returning_response := returning_dialogue.get("response_label") as Label
    var returning_buttons: Dictionary = returning_dialogue.get("buttons")
    if not returning_response.text.contains("Du schon wieder") or not returning_buttons.has("recognition"):
        _fail("Returning profile did not receive the alternate dialogue")
        return
    settings.set_option("language","en")
    if not returning_response.text.contains("You again"):
        _fail("Returning greeting failed to localize")
        return
    returning_dialogue.call("_on_choice","recognition")
    if not returning_response.text.contains("start over"):
        _fail("Returning guest recognition topic missing")
        return
    returning_dialogue.call("_next_page")
    if not returning_response.text.contains("remember every visit"):
        _fail("Returning guest recognition topic could not advance")
        return
    returning_dialogue.call("close_conversation")
    if bool(returning_room.get("has_spoken")):
        _fail("Recognition alone unlocked the destination without directions")
        return
    returning_room.call("_open_conversation")
    returning_dialogue.call("_next_page")
    returning_dialogue.call("close_conversation")
    var returning_objective := returning_room.get_node("Player/ObjectiveHUD")
    if not bool(returning_room.get("has_spoken")) or str(returning_objective.get("objective_id"))!="enter_main_casino":
        _fail("Returning guest could not unlock the ordinary objective")
        return
    returning_room.queue_free()
    await process_frame
    state.set("returning_guest",previous_returning)
    for key in guidance_options:
        settings.set_option(key,guidance_options[key])
    settings.set_option("language", prior)
    print("Casino Anomaly croupier welcome desk and dialogue QA PASS")
    root.get_node("AudioDirector").call("request_quit")


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
    # Imported FBX mesh bind-pose AABBs point along Z even though the animated
    # skinned character stands upright. Their world-space mesh AABB therefore
    # measures a lying *bind pose*, not the character seen in the game.
    # Instead inspect the displayed rig's shoulders, face and feet after the
    # corrected root-scale has been applied.
    var skeleton := _find_skeleton(character)
    if skeleton == null:
        return "The imported character has no skeleton for proportions QA"
    var anchor := character.get_parent() as Node3D
    for name in ["Upper_Arm_L_027", "Upper_Arm_R_046",
            "Head_06", "Face_011", "Foot_L_065", "Foot_R_069"]:
        if skeleton.find_bone(name) < 0:
            return "Missing bone for body proportion QA: " + name
    var left_shoulder := _bone_anchor_position(skeleton, anchor, "Upper_Arm_L_027")
    var right_shoulder := _bone_anchor_position(skeleton, anchor, "Upper_Arm_R_046")
    var head := _bone_anchor_position(skeleton, anchor, "Head_06")
    var face := _bone_anchor_position(skeleton, anchor, "Face_011")
    var left_foot := _bone_anchor_position(skeleton, anchor, "Foot_L_065")
    var right_foot := _bone_anchor_position(skeleton, anchor, "Foot_R_069")
    var feet := (left_foot + right_foot) * 0.5
    var height := head.y - feet.y
    var shoulder_width := absf(left_shoulder.x - right_shoulder.x)
    var depth := face.z - head.z
    var foot_width := absf(left_foot.x - right_foot.x)
    print("CROUPIER_ANIMATED_PROPORTIONS: standing_height=", height,
            " shoulder_width=", shoulder_width, " face_depth=", depth,
            " feet_distance=", foot_width, " model_scale=", character.scale)
    if height < 1.60 or height > 1.86:
        return "Animated croupier height is implausible: %.2f" % height
    # The figure's X and Y proportions are deliberately editable in Godot.
    # Test a plausible shoulder-to-height ratio instead of hard-coding the
    # width from an earlier art-direction pass. This still catches a paper-
    # thin or heavily distorted character without rejecting user edits.
    var shoulder_ratio := shoulder_width / maxf(height, 0.01)
    if shoulder_ratio < 0.34 or shoulder_ratio > 0.65:
        return "Croupier shoulder-to-height ratio is implausible: %.3f (width %.2f, height %.2f)" % [
            shoulder_ratio, shoulder_width, height]
    if depth < 0.11 or depth > 0.35:
        return "Croupier face depth is implausible: %.2f" % depth
    if foot_width < 0.22 or foot_width > 1.08:
        return "Croupier leg spacing is implausible: %.2f" % foot_width
    return ""


func _hand_positions(anchor: Node3D, character: Node3D) -> PackedVector3Array:
    if character == null:
        return PackedVector3Array()
    var skeleton := _find_skeleton(character)
    if skeleton == null:
        return PackedVector3Array()
    var points := PackedVector3Array()
    for name in ["Hand_L_029", "Hand_R_048"]:
        if skeleton.find_bone(name) < 0:
            return PackedVector3Array()
        points.append(_bone_anchor_position(skeleton, anchor, name))
    return points
