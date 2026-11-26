extends Node3D
## Major Event 33: five licensed guest models and physically separate actors.
## Staggered offscreen appearances/audio are retained from the original event.
const Actor = preload("res://gameplay/anomalies/silent_audience_actor.gd")
const STOOL = preload("res://models/casino_furniture/gaming_stool.tscn")
const FIRST_APPEARANCE := 5.0
const INTERVAL := 2.65
const FINALE_DELAY := 7.0
const PATHS := [
    ["security_guard","res://models/silent_audience/security_guard/scene.gltf"],
    ["old_man","res://models/silent_audience/old_man/scene.gltf"],
    ["suit_man","res://models/silent_audience/suit_man/scene.gltf"],
    ["guard","res://models/silent_audience/guard/scene.gltf"],
    ["female","res://models/silent_audience/female/scene.gltf"],
]
var hall: Node3D
var scenes: Array[PackedScene] = []
var seat_sites: Array[Dictionary] = []
var guests: Array[Node3D] = []
var target_count := 0
var elapsed := 0.0
var next_guest := FIRST_APPEARANCE
var final_at := 0.0
var finale_started := false
var configured := false
var original_audio: Dictionary = {}
var rng := RandomNumberGenerator.new()

static func models_available() -> bool:
    for entry in PATHS:
        if not ResourceLoader.exists(entry[1],"PackedScene"):
            return false
    return true

func configure(room: Node3D) -> bool:
    if not models_available():
        return false
    hall = room
    rng.seed = 330339
    process_priority = 100
    for entry in PATHS:
        var resource := ResourceLoader.load(entry[1],"PackedScene") as PackedScene
        if resource==null:
            return false
        scenes.append(resource)
    _collect_seats()
    target_count = mini(25,seat_sites.size())
    configured = target_count>=15
    return configured

func _collect_seats() -> void:
    # Ten couch placements, four bar seats, two side stools, four tables.
    for i in range(1,6):
        var sofa := hall.get_node_or_null("ModelInteriors/LoungeSofa_%02d" % i) as Node3D
        _place_on(sofa,"sofa",0.0,-0.46)
        _place_on(sofa,"sofa",0.0,0.46)
    for i in [1,3,5,7]:
        _place_on(hall.get_node_or_null("ModelInteriors/CounterStool_%02d" % i) as Node3D,"bar",PI)
    for i in [1,3]:
        _place_on(hall.get_node_or_null("ModelInteriors/SideStool_%02d" % i) as Node3D,"bar",PI*0.5)
    for x in [-13.6,-20.3,-27.2,-41.1]:
        seat_sites.append({"anchor":Vector3(x,0.73,-8.68),"yaw":PI,
            "kind":"table","stool":Vector3(x,0.005,-8.68)})

func _place_on(prop: Node3D,kind: String,yaw: float,lateral: float=0.0) -> void:
    if prop==null or not prop.visible:
        return
    var cushion: MeshInstance3D
    if kind!="sofa":
        cushion = prop.find_child("SoftSeatCrown",true,false) as MeshInstance3D
    if cushion==null:
        for item in prop.find_children("*","MeshInstance3D",true,false):
            if str(item.name).to_lower().contains("seat"):
                cushion = item as MeshInstance3D
                break
    if cushion==null or cushion.mesh==null:
        return
    var bounds := (prop.global_transform.affine_inverse()*cushion.global_transform)*cushion.get_aabb()
    var center := bounds.get_center()
    var hip := Vector3(center.x+lateral,bounds.end.y+0.08,center.z-(0.08 if kind=="sofa" else 0.0))
    var facing := yaw
    if kind=="sofa":
        facing = (hall.global_transform.affine_inverse()*prop.global_transform).basis.orthonormalized().get_euler().y+lateral*0.12
    seat_sites.append({"anchor":hall.to_local(prop.to_global(hip)),"yaw":facing,"kind":kind})

func _hidden(camera: Camera3D,player: CollisionObject3D,site: Dictionary) -> bool:
    var location := hall.to_global((site["anchor"] as Vector3)+Vector3(0,0.55,0))
    if camera.global_position.distance_to(location)<1.7:
        return false
    if camera.is_position_behind(location):
        return true
    var screen := camera.unproject_position(location)
    var size := camera.get_viewport().get_visible_rect().size
    if screen.x < -70 or screen.x>size.x+70 or screen.y < -70 or screen.y>size.y+70:
        return true
    var query := PhysicsRayQueryParameters3D.create(camera.global_position,location)
    query.exclude = [player.get_rid()]
    var hit := hall.get_world_3d().direct_space_state.intersect_ray(query)
    return not hit.is_empty() and (hit["position"] as Vector3).distance_to(location)>0.20

func _find_unseen(camera: Camera3D,player: CollisionObject3D) -> int:
    var choices: Array[int] = []
    for i in range(seat_sites.size()):
        if _hidden(camera,player,seat_sites[i]):
            choices.append(i)
    return -1 if choices.is_empty() else choices[rng.randi_range(0,choices.size()-1)]

func _new_stool(spot: Vector3) -> Node3D:
    var stool := STOOL.instantiate() as Node3D
    if stool==null:
        return null
    for body in stool.find_children("*","CollisionObject3D",true,false):
        (body as CollisionObject3D).free()
    stool.name = "AudienceTableStool"
    add_child(stool)
    stool.position = spot
    return stool

func _spawn(index: int) -> bool:
    if index<0 or index>=seat_sites.size():
        return false
    var site := seat_sites[index]
    var serial := guests.size()
    # Round-robin through the five unique source faces and silhouettes.
    var model_index: int = [2,4,0,1,3][serial%5]
    var actor := Actor.new()
    actor.name = "AudienceGuest_%02d" % serial
    add_child(actor)
    if not actor.configure(scenes[model_index],str(PATHS[model_index][0]),site,serial):
        actor.free()
        return false
    if str(site["kind"])=="table":
        _new_stool(site["stool"] as Vector3)
    guests.append(actor)
    seat_sites.remove_at(index)
    return true

func _silence(level: float) -> void:
    var director := get_node_or_null("/root/AudioDirector")
    if director!=null:
        var tone := director.get("room_player") as AudioStreamPlayer
        if tone!=null and tone.playing:
            if not original_audio.has(tone):
                original_audio[tone] = tone.volume_db
            tone.volume_db = lerpf(float(original_audio[tone]),-58.0,level)
    var soundscape := hall.get_node_or_null("RoomSoundscape")
    if soundscape==null:
        return
    var sources: Array = soundscape.get("_sources")
    var levels: Array = soundscape.get("_target_db")
    for i in range(mini(sources.size(),levels.size())):
        var emitter := sources[i] as AudioStreamPlayer3D
        if emitter==null or not emitter.playing:
            continue
        if not original_audio.has(emitter):
            original_audio[emitter] = levels[i]
        emitter.volume_db = lerpf(float(original_audio[emitter]),-58.0,level)

func _process(delta: float) -> void:
    if not configured or hall==null or hall.has_meta("_streaming_standby"):
        return
    var player := hall.get_node_or_null("Player") as CollisionObject3D
    if player==null:
        return
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    if camera==null:
        return
    elapsed += delta
    if not finale_started and guests.size()<target_count and elapsed>=next_guest:
        var hidden := _find_unseen(camera,player)
        if hidden>=0 and _spawn(hidden):
            next_guest=elapsed+INTERVAL+rng.randf_range(-0.35,0.40)
        else:
            next_guest=elapsed+0.3
    for actor in guests:
        actor.set("visible_player",player)
    _silence(smoothstep(0.10,1.0,float(guests.size())/float(maxi(1,target_count))))
    if guests.size()==target_count and not finale_started:
        if final_at==0.0:
            final_at=elapsed+FINALE_DELAY
        if elapsed>=final_at:
            finale_started=true
            var offset := 0.0
            for actor in guests:
                actor.call("start_standing",offset)
                offset=fmod(offset+0.14,0.62)

func _exit_tree() -> void:
    for source in original_audio:
        if is_instance_valid(source):
            source.volume_db = original_audio[source]
    original_audio.clear()
