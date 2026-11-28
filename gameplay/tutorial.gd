extends Node3D
## Single live tutorial: the existing dialogue and casino handoff.
const Controls = preload("res://gameplay/input_bindings.gd")
const Loc = preload("res://gameplay/localization.gd")
const Conversation = preload("res://gameplay/croupier_dialogue.gd")
const DoorPrompt = preload("res://ui/door_prompt.gd")
const ObjectiveHUD = preload("res://ui/objective_hud.gd")

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/Camera3D
@onready var door: Node3D = $SideGalleries/EastGallery/AccessBays/MainCasinoEntrance
@onready var croupier: Node3D = $CroupierStation
@onready var door_leaf: StaticBody3D = door.get_node("ClosedLeaf")
@onready var door_shape: CollisionShape3D = door_leaf.get_node("CollisionShape3D")
@onready var npc_body: StaticBody3D = croupier.get_node("CroupierCollision")
@onready var model_anchor: Node3D = croupier.get_node("CharacterPivot/ModelAnchor")
@onready var destination_marker: Node3D = door.get_node("DestinationMarker")
@onready var marker_home: Vector3 = destination_marker.position

var door_prompt: CanvasLayer
var conversation: CanvasLayer
var objective_hud: CanvasLayer
var _pending_objectives: Dictionary = {}
var changing := false
# Guidance is local to this entrance visit, not a progression requirement.
var has_spoken := false
var marker_phase := 0.0

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    door_prompt = DoorPrompt.new()
    door_prompt.name = "DoorInteractionHUD"
    add_child(door_prompt)
    conversation = Conversation.new()
    conversation.name = "CroupierDialogue"
    add_child(conversation)
    conversation.closed.connect(_on_conversation_closed)
    conversation.objective_discovered.connect(_on_objective_discovered)
    objective_hud = ObjectiveHUD.new()
    objective_hud.name = "ObjectiveHUD"
    player.add_child(objective_hud)
    var settings = get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_settings_changed)
    _refresh_hint()

func _exit_tree() -> void:
    # This marks the old scene leaving the SceneTree, not completion of
    # native renderer resource destruction (which can be deferred).
    if changing:
        var journal := get_node_or_null("/root/CrashJournal")
        if journal != null:
            journal.call("record", "tutorial_tree_exit", {"path": scene_file_path})


func _refresh_hint() -> void:
    door_prompt.call("set_prompt_text", Loc.t("tutorial.enter", self))
    for gallery in $SideGalleries.get_children():
        for bay in gallery.get_node("AccessBays").get_children():
            var sign := bay.get_node("TemporarySign") as Label3D
            sign.text = Loc.t("tutorial.main_casino" if bay == door else "tutorial.under_construction", self)

func _on_settings_changed(key: String) -> void:
    if key == "language":
        _refresh_hint()
    if key in ["hud_visible", "interaction_hints", "tutorial_hints", "reduced_motion"]:
        _update_destination_marker(0.0)

func _loader_active() -> bool:
    var loader := get_node_or_null("/root/SceneLoader")
    return loader != null and bool(loader.get("active"))

func _process(delta: float) -> void:
    # A failed load keeps the retry/cancel overlay open; do not unlock
    # until it is dismissed. A successful handoff frees this scene.
    if changing and not _loader_active():
        changing = false
        player.call("set_interaction_locked", false)
    var can_interact := not changing and not _loader_active() and not is_dialogue_open() and not get_tree().paused and bool(Controls.pref(self, "hud_visible", true)) and bool(Controls.pref(self, "interaction_hints", true)) and bool(Controls.pref(self, "tutorial_hints", true))
    croupier.call("set_hint_visible", can_interact and _is_looking_at_croupier())
    door_prompt.call("set_prompt_visible", can_interact and _is_looking_at_door())
    _update_destination_marker(delta)

func _update_destination_marker(delta: float) -> void:
    var show_marker := has_spoken and not changing and not _loader_active() and not is_dialogue_open() and not get_tree().paused and bool(Controls.pref(self, "hud_visible", true)) and bool(Controls.pref(self, "interaction_hints", true)) and bool(Controls.pref(self, "tutorial_hints", true))
    destination_marker.visible = show_marker
    if objective_hud != null:
        objective_hud.call("set_context_visible",show_marker)
    if not show_marker or bool(Controls.pref(self, "reduced_motion", false)):
        marker_phase = 0.0
        destination_marker.position = marker_home
        return
    marker_phase = fposmod(marker_phase + delta * TAU / 2.8, TAU)
    destination_marker.position = marker_home + Vector3.UP * (sin(marker_phase) * 0.12)

func _ray_to(target: Vector3) -> Dictionary:
    var exclude: Array[RID] = [player.get_rid()]
    var query := PhysicsRayQueryParameters3D.create(camera.global_position, target, 1, exclude)
    return get_world_3d().direct_space_state.intersect_ray(query)

func _is_looking_at_door() -> bool:
    # Use the actual rotated leaf and its collision dimensions.
    var eye := door.to_local(camera.global_position)
    var face := door.to_local(door_shape.global_position)
    var half := (door_shape.shape as BoxShape3D).size * 0.5
    var surface_z := face.z + half.z
    if eye.z < surface_z + 0.04 or eye.z > 3.8:
        return false
    var forward := door.to_local(camera.global_position - camera.global_basis.z) - eye
    if forward.z >= -0.10:
        return false
    var hit := eye + forward * ((surface_z-eye.z)/forward.z)
    if absf(hit.x-face.x)>half.x-0.01 or hit.y<face.y-half.y+0.04 or hit.y>face.y+half.y-0.02:
        return false
    var ray := _ray_to(door.to_global(hit+forward*0.08))
    return not ray.is_empty() and ray.get("collider") == door_leaf

func _is_looking_at_croupier() -> bool:
    var center := model_anchor.to_global(Vector3(0,1.53,0))
    var towards := center-camera.global_position
    var distance := towards.length()
    var local_eye := croupier.to_local(camera.global_position)
    if distance<0.2 or distance>3.35 or local_eye.z<1.17 or absf(local_eye.x)>3.20:
        return false
    if (-camera.global_basis.z).dot(towards/distance)<0.925:
        return false
    var hit := _ray_to(center)
    return hit.is_empty() or hit.get("collider")==npc_body

func is_dialogue_open() -> bool:
    return conversation != null and bool(conversation.get("active"))

func _open_conversation() -> void:
    if changing or _loader_active() or is_dialogue_open():
        return
    player.call("interaction_vibration")
    player.call("set_interaction_locked", true)
    croupier.call("set_hint_visible", false)
    door_prompt.call("set_prompt_visible", false)
    croupier.call("set_talking", true)
    var journal := get_node_or_null("/root/CrashJournal")
    if journal != null:
        journal.call("record", "croupier_conversation_opened")
    conversation.call("show_conversation")
    _update_destination_marker(0.0)

func _on_objective_discovered(id: String, text_key: String) -> void:
    # Receiving a page is not the same as closing the conversation.
    # Defer the objective announcement until the player returns to gameplay.
    _pending_objectives[id] = text_key


func _on_conversation_closed() -> void:
    if changing:
        return
    croupier.call("set_talking", false)
    player.call("set_interaction_locked", false)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if _pending_objectives.has("enter_main_casino"):
        has_spoken = true
        objective_hud.call("set_objective","enter_main_casino",str(_pending_objectives["enter_main_casino"]))
    _pending_objectives.clear()
    var journal := get_node_or_null("/root/CrashJournal")
    if journal != null:
        journal.call("record", "croupier_conversation_closed", {"objective_unlocked": has_spoken})
    _update_destination_marker(0.0)

func _unhandled_input(event: InputEvent) -> void:
    if changing or _loader_active() or is_dialogue_open() or get_tree().paused:
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
    var journal := get_node_or_null("/root/CrashJournal")
    if journal != null:
        journal.call("record", "casino_door_interacted", {"conversation_completed": has_spoken})
    var loader := get_node_or_null("/root/SceneLoader")
    if loader == null or not loader.travel_to("res://main.tscn", true):
        push_warning("Could not show the casino loading screen.")
        return
    player.call("interaction_vibration")
    changing = true
    _update_destination_marker(0.0)
    player.call("set_interaction_locked", true)
    door_prompt.call("set_prompt_visible", false)
    croupier.call("set_hint_visible", false)
