extends SceneTree
## Headless validation of the semantic rig and seamless non-root-motion poses.
## Uses the already licensed croupier glTF; the five premium source binaries
## are installed separately from the downloadable optimized pack.
const Actor = preload("res://gameplay/anomalies/silent_audience_actor.gd")
const Premium = preload("res://gameplay/anomalies/silent_audience_premium.gd")
const MODEL = preload("res://models/croupier/scene.gltf")

func _initialize() -> void:
    create_timer(240.0, true, false, true).timeout.connect(func(): _fail("QA watchdog expired"))
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("Silent Audience premium actor QA: "+reason)
    quit(1)

func _run() -> void:
    var guest := Actor.new()
    root.add_child(guest)
    var site := {"anchor":Vector3(0.0,0.76,0.0),"kind":"sofa","yaw":0.0}
    if not guest.configure(MODEL,"croupier_test",site,2):
        _fail("Neutral humanoid rig cannot be mapped to seated roles")
        return
    var roles: Dictionary = guest.roles
    for name in ["hip","head","left_thigh","right_thigh","left_calf","right_calf"]:
        if not roles.has(name):
            _fail("Missing role: "+name)
            return
    if guest.physical==null or guest.physical.collision_layer!=1:
        _fail("Character must have actual player-blocking collision")
        return
    var figure := guest.figure as Node3D
    var original_xz := Vector2(figure.position.x,figure.position.z)
    guest.call("_process",0.10)
    guest.call("_process",0.30)
    if not guest.start_standing(0.1):
        _fail("Sofa guest did not begin to stand")
        return
    guest.call("_process",5.6)
    var new_xz := Vector2(figure.position.x,figure.position.z)
    if original_xz.distance_to(new_xz)>0.00001:
        _fail("Horizontal root-motion sliding came back")
        return
    if not bool(guest.standing) or not (guest.collider.shape is CapsuleShape3D):
        _fail("Standing pose or collision shape invalid")
        return
    guest.free()
    var bar := Actor.new()
    root.add_child(bar)
    var bar_site := {"anchor":Vector3(0,0.72,0),"kind":"bar","yaw":PI}
    if not bar.configure(MODEL,"croupier_test",bar_site,3):
        _fail("Bar seating failed")
        return
    if bar.start_standing(0.0):
        _fail("Bar character must not rise through the counter and stool")
        return
    bar.free()
    # This CI checkout has no separate premium binaries by design.
    # Installing the five optimized models activates Premium automatically.
    if Premium.models_available():
        var asset := ResourceLoader.load("res://models/silent_audience/female/scene.gltf")
        if asset==null:
            _fail("Premium model pack is present but not importable")
            return
    print("Casino Anomaly silent audience actor QA PASS")
    quit(0)
