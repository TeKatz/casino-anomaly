extends Node3D
## Room-local flooding of the authored L-shaped floor. No colliders or
## movement modifiers: the exits and the continuous room handoff are safe.
const WATER_SHADER = preload("res://gameplay/anomalies/flood_water.gdshader")
const Synth = preload("res://gameplay/immersion_synth.gd")
const CARD_PATH := "res://models/playing_cards/individual/card_%02d.gltf"
const DURATION := 48.0
const MAX_HEIGHT := 0.230
const CARD_SCALE := 0.16
const DROP_SOUND_PATH := "res://audio/flood/water_drop_%02d.wav"
const SOURCE := Vector2(3.25,8.0)
const RIPPLE_COUNT := 8
const CARD_IDS := [12,1,14,6,19,25,32,40,46,51]
static var cached_water: AudioStreamWAV
static var cached_drops: Array[AudioStreamWAV] = []
var hall: Node3D
var floor_regions: Array[Rect2] = []
var surface: MeshInstance3D
var material: ShaderMaterial
var floor_height := 0.005
var water_height := 0.023
var front_distance := 1.5
var maximum_distance := 53.0
var bend := Vector2(-6.0,-0.08)
var elapsed := 0.0
var configured := false
var reduced := false
var particle_quality := "original"
var ripple_index := 0
var ripples := PackedVector4Array()
var cards: Array[Dictionary] = []
var ambience: Array[AudioStreamPlayer3D] = []
var splash_pool: Array[CPUParticles3D] = []
var splash_index := 0
var droplet_pool: Array[MeshInstance3D] = []
var drops: Array[Dictionary] = []
var drop_audio: Array[AudioStreamPlayer3D] = []
var drop_audio_index := 0
var next_drop := 0.7
var settings_clock := 0.0
var rng := RandomNumberGenerator.new()


func configure(room: Node3D, main: MeshInstance3D, west: MeshInstance3D) -> bool:
    hall = room
    rng.seed = 53191
    for floor in [main,west]:
        var bounds: AABB = (room.global_transform.affine_inverse()*floor.global_transform)*floor.get_aabb()
        if bounds.size.x < 1.0 or bounds.size.z < 1.0:
            return false
        floor_regions.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)))
        floor_height = maxf(floor_height,bounds.end.y)
    bend = Vector2(floor_regions[1].end.x,floor_regions[1].end.y-0.08)
    maximum_distance = 0.0
    for region in floor_regions:
        for p in [region.position,region.end,Vector2(region.position.x,region.end.y),Vector2(region.end.x,region.position.y)]:
            maximum_distance = maxf(maximum_distance,_path_distance(p))
    maximum_distance += 1.0
    ripples.resize(RIPPLE_COUNT)
    for i in range(RIPPLE_COUNT):
        ripples[i] = Vector4(0,0,-100,0)
    material = ShaderMaterial.new()
    material.shader = WATER_SHADER
    material.render_priority = 2
    material.set_shader_parameter("origin",SOURCE)
    material.set_shader_parameter("bend",bend)
    material.set_shader_parameter("ripples",ripples)
    surface = MeshInstance3D.new()
    surface.name = "FloodSurface"
    surface.mesh = _surface_mesh()
    surface.material_override = material
    surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    surface.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    add_child(surface)
    _build_cards()
    _build_splashes()
    _build_droplets()
    # Prepare the cached streams before handoff; staged rooms stay silent.
    _build_audio()
    _read_settings()
    _update_progress()
    configured = true
    return true


func _surface_mesh() -> ArrayMesh:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for region in floor_regions:
        var a := Vector3(region.position.x,0,region.position.y)
        var b := Vector3(region.end.x,0,region.position.y)
        var c := Vector3(region.end.x,0,region.end.y)
        var d := Vector3(region.position.x,0,region.end.y)
        for corner in [a,c,b,a,d,c]:
            tool.set_normal(Vector3.UP)
            tool.set_uv(Vector2(corner.x,corner.z))
            tool.add_vertex(corner)
    return tool.commit()


func _path_distance(p: Vector2) -> float:
    if p.x < bend.x:
        var cross_z := lerpf(SOURCE.y,p.y,(bend.x-SOURCE.x)/(p.x-SOURCE.x))
        if cross_z > bend.y:
            return SOURCE.distance_to(bend)+p.distance_to(bend)
    return SOURCE.distance_to(p)


func _edge(p: Vector2) -> float:
    var irregular := sin(p.x*0.71+p.y*0.46)*0.37+sin(p.x*1.7-p.y*1.31)*0.18+sin(p.x*3.8+p.y*2.4)*0.065
    return front_distance-_path_distance(p)+irregular


func contains_water(local: Vector3) -> bool:
    if not configured:
        return false
    var p := Vector2(local.x,local.z)
    if not _inside(p) or _edge(p)<0.20:
        return false
    # Early shallow water cannot cover the raised runner edging.
    var carpet := (absf(local.x)<1.57 and local.z>=-6.62 and local.z<=12.7) or (local.x>=-44.9 and local.x<=-1.57 and local.z>=-6.62 and local.z<=-3.48)
    return not carpet or water_height>0.082


func _inside(p: Vector2) -> bool:
    for region in floor_regions:
        if region.has_point(p):
            return true
    return false


func _update_progress() -> void:
    var phase := clampf(elapsed/DURATION,0.0,1.0)
    # A clear opening puddle, then a growing front, then the water rises
    # over the runner. Never reset or drain during the active encounter.
    front_distance = lerpf(1.5,maximum_distance,pow(phase,0.88))
    water_height = lerpf(floor_height+0.018,MAX_HEIGHT,smoothstep(0.03,0.94,phase))
    surface.position.y = water_height
    material.set_shader_parameter("front_distance",front_distance)
    material.set_shader_parameter("water_height",water_height-floor_height)
    material.set_shader_parameter("clock",elapsed)
    _update_cards()


func _read_settings() -> void:
    var settings := get_node_or_null("/root/GameSettings")
    reduced = settings != null and bool(settings.call("get_option","reduced_motion"))
    particle_quality = str(settings.call("get_option","particle_quality")) if settings != null else "original"
    var reflections := str(settings.call("get_option","reflection_quality")) if settings != null else "original"
    var steps := 16
    match reflections:
        "off": steps = 0
        "low": steps = 8
        "medium": steps = 12
        "high": steps = 24
        "ultra": steps = 28
    material.set_shader_parameter("reflection_steps",steps)
    material.set_shader_parameter("motion",0.0 if reduced else 1.0)
    if reduced or particle_quality == "off":
        for burst in splash_pool:
            burst.emitting = false
            burst.hide()
        for drop in droplet_pool:
            drop.hide()
        drops.clear()


func _build_cards() -> void:
    var points := [Vector2(3.0,7.7),Vector2(2.4,4.1),Vector2(-2.7,-2.0),
        Vector2(3.4,-7.1),Vector2(-8.3,-5.2),Vector2(-15.5,-4.2),
        Vector2(-22.2,-7.6),Vector2(-28.4,-4.5),Vector2(-36.4,-8.2),Vector2(-43.0,-5.2)]
    var group := Node3D.new()
    group.name = "FloatingCards"
    add_child(group)
    for i in range(points.size()):
        var packed := ResourceLoader.load(CARD_PATH % int(CARD_IDS[i]),"PackedScene") as PackedScene
        if packed == null:
            continue
        var card := packed.instantiate() as Node3D
        if card == null:
            continue
        card.name = "FloatingCard_%02d" % i
        group.add_child(card)
        card.scale = Vector3.ONE*CARD_SCALE
        card.hide()
        cards.append({"node":card,"anchor":points[i],"yaw":rng.randf_range(-PI,PI),"phase":rng.randf_range(0.0,TAU)})


func _update_cards() -> void:
    for data in cards:
        var card := data["node"] as Node3D
        var anchor: Vector2 = data["anchor"]
        var phase := float(data["phase"])
        var time := 0.0 if reduced else elapsed
        var drift := Vector2(sin(time*0.17+phase),cos(time*0.13+phase))*0.18
        var p := anchor+drift
        card.visible = water_height>0.062 and _inside(p) and _edge(p)>0.45
        if card.visible:
            card.position = Vector3(p.x,water_height+0.004+sin(time*1.7+phase)*0.002,p.y)
            card.rotation = Vector3(sin(time*1.2+phase)*0.018,float(data["yaw"])+sin(time*0.21+phase)*0.19,cos(time*1.4+phase)*0.018)


func _build_splashes() -> void:
    var drop_mesh := SphereMesh.new()
    drop_mesh.radius = 0.012
    drop_mesh.height = 0.024
    drop_mesh.radial_segments = 8
    drop_mesh.rings = 4
    var drop_material := StandardMaterial3D.new()
    drop_material.albedo_color = Color(0.44,0.57,0.54,0.76)
    drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    drop_material.render_priority = 3
    drop_material.roughness = 0.15
    drop_material.metallic = 0.28
    drop_mesh.material = drop_material
    for i in range(4):
        var burst := CPUParticles3D.new()
        burst.name = "StepSplash_%02d" % i
        burst.emitting = false
        burst.one_shot = true
        burst.explosiveness = 1.0
        burst.amount = 20
        burst.lifetime = 0.42
        burst.local_coords = false
        burst.mesh = drop_mesh
        burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        burst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        burst.direction = Vector3.UP
        burst.spread = 72.0
        burst.gravity = Vector3(0,-8.6,0)
        burst.initial_velocity_min = 0.55
        burst.initial_velocity_max = 1.65
        burst.scale_amount_min = 0.38
        burst.scale_amount_max = 1.0
        add_child(burst)
        splash_pool.append(burst)


func _build_droplets() -> void:
    var shape := _teardrop_mesh()
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.63,0.76,0.74,0.83)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.render_priority = 3
    mat.roughness = 0.10
    mat.metallic = 0.2
    for i in range(6):
        var drop := MeshInstance3D.new()
        drop.name = "CeilingDroplet_%02d" % i
        drop.mesh = shape
        drop.material_override = mat
        drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        drop.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        add_child(drop)
        drop.hide()
        droplet_pool.append(drop)


func _teardrop_mesh() -> ArrayMesh:
    # Rounded lower body and a narrow upper tip, rather than an elongated
    # sphere. Deformation below stretches the drop as it accelerates.
    const RINGS := 12
    const SIDES := 16
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for row in range(RINGS+1):
        var t := float(row)/float(RINGS)
        var y := lerpf(-0.035,0.050,t)
        var radius := 0.027*pow(maxf(sin(PI*t),0.0001),0.66)*(1.18-0.78*t)
        for side in range(SIDES+1):
            var angle := TAU*float(side)/float(SIDES)
            tool.add_vertex(Vector3(cos(angle)*radius,y,sin(angle)*radius))
    for row in range(RINGS):
        for side in range(SIDES):
            var a := row*(SIDES+1)+side
            var b := a+SIDES+1
            for index in [a,b,b+1,a,b+1,a+1]:
                tool.add_index(index)
    tool.generate_normals()
    return tool.commit()


func _build_audio() -> void:
    if not ambience.is_empty():
        return
    if cached_water == null:
        cached_water = Synth.water_ambience()
    if cached_drops.is_empty():
        for i in range(1,4):
            var path := DROP_SOUND_PATH % i
            if ResourceLoader.exists(path,"AudioStreamWAV"):
                var sample := ResourceLoader.load(path,"AudioStreamWAV") as AudioStreamWAV
                if sample != null:
                    cached_drops.append(sample)
        if cached_drops.is_empty():
            cached_drops.append(Synth.water_drop())
    for p in [Vector3(3.0,0.30,7.5),Vector3(1.0,0.30,-5.5),Vector3(-15.0,0.30,-6.5),Vector3(-28.0,0.30,-6.5),Vector3(-41.0,0.30,-6.5)]:
        var emitter := AudioStreamPlayer3D.new()
        emitter.name = "WaterAmbience_%02d" % ambience.size()
        emitter.stream = cached_water
        emitter.bus = "AMBIENCE"
        emitter.unit_size = 2.4
        emitter.max_distance = 15.0
        emitter.volume_db = -60.0
        add_child(emitter)
        emitter.position = p
        ambience.append(emitter)
    for i in range(4):
        var emitter := AudioStreamPlayer3D.new()
        emitter.name = "WaterDropAudio_%02d" % i
        emitter.stream = cached_drops[i%cached_drops.size()]
        emitter.bus = "AMBIENCE"
        emitter.unit_size = 1.1
        emitter.max_distance = 11.0
        emitter.volume_db = -15.0
        add_child(emitter)
        drop_audio.append(emitter)


func _update_audio() -> void:
    _build_audio()
    for i in range(ambience.size()):
        var emitter := ambience[i]
        var strength := smoothstep(-1.0,2.5,_edge(Vector2(emitter.position.x,emitter.position.z)))
        if strength > 0.005 and not emitter.playing:
            emitter.play(float(i)*0.73)
        emitter.volume_db = lerpf(-60.0,-16.5,strength)


func _add_ripple(p: Vector2, amplitude: float) -> void:
    if reduced:
        return
    ripples[ripple_index] = Vector4(p.x,p.y,elapsed,amplitude)
    ripple_index = (ripple_index+1)%RIPPLE_COUNT
    material.set_shader_parameter("ripples",ripples)


func register_step(local: Vector3, sprinting: bool) -> void:
    if not contains_water(local) or hall.has_meta("_streaming_standby"):
        return
    var p := Vector2(local.x,local.z)
    _add_ripple(p,0.19 if sprinting else 0.13)
    if reduced or particle_quality == "off":
        return
    var burst := splash_pool[splash_index]
    splash_index = (splash_index+1)%splash_pool.size()
    burst.position = Vector3(local.x,water_height+0.015,local.z)
    burst.amount = (9 if particle_quality == "low" else 17) if not sprinting else (15 if particle_quality == "low" else 28)
    burst.initial_velocity_max = 1.9 if sprinting else 1.35
    burst.show()
    burst.restart()
    burst.emitting = true


func _spawn_drop(player: Node3D) -> void:
    if reduced or particle_quality == "off" or drops.size()>=droplet_pool.size():
        return
    var local := hall.to_local(player.global_position)
    for attempt in range(7):
        var p := Vector2(local.x,local.z)+Vector2(rng.randf_range(-3.2,3.2),rng.randf_range(-3.2,3.2))
        if not _inside(p) or _edge(p)<0.5:
            continue
        for drop in droplet_pool:
            if drop.visible:
                continue
            drop.position = Vector3(p.x,5.65,p.y)
            var size := rng.randf_range(0.86,1.20)
            drop.scale = Vector3.ONE*size
            drop.show()
            drops.append({"node":drop,"speed":0.35,"size":size})
            return


func _update_drops(delta: float, player: Node3D) -> void:
    if elapsed>=next_drop:
        next_drop = elapsed+rng.randf_range(0.75,1.7)
        _spawn_drop(player)
    for i in range(drops.size()-1,-1,-1):
        var data := drops[i]
        var drop := data["node"] as MeshInstance3D
        var speed := minf(float(data["speed"])+delta*6.2,4.6)
        data["speed"] = speed
        var size := float(data["size"])
        var stretch := lerpf(1.0,1.40,speed/4.6)
        drop.scale = Vector3(size/sqrt(stretch),size*stretch,size/sqrt(stretch))
        drop.position.y -= speed*delta
        if drop.position.y<=water_height:
            var p := Vector2(drop.position.x,drop.position.z)
            _add_ripple(p,0.075)
            if not drop_audio.is_empty():
                var audio := drop_audio[drop_audio_index]
                drop_audio_index = (drop_audio_index+1)%drop_audio.size()
                audio.position = Vector3(p.x,water_height,p.y)
                audio.stream = cached_drops[rng.randi_range(0,cached_drops.size()-1)]
                audio.pitch_scale = rng.randf_range(0.94,1.06)
                audio.play()
            drop.hide()
            drops.remove_at(i)


func _process(delta: float) -> void:
    if not configured or not is_instance_valid(hall):
        return
    if hall.has_meta("_streaming_standby"):
        for emitter in ambience:
            if emitter.playing:
                emitter.stop()
        return
    var player := hall.get_node_or_null("Player") as Node3D
    if player == null:
        return
    elapsed += delta
    settings_clock += delta
    if settings_clock>=0.35:
        settings_clock = 0.0
        _read_settings()
    _update_progress()
    _update_audio()
    _update_drops(delta,player)
