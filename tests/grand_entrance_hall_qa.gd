extends SceneTree
## Authored architecture, collision, finishes and live tutorial integration.
const HALL = preload("res://gameplay/grand_entrance_hall.tscn")
const PLAYER = preload("res://player.gd")
const Catalog = preload("res://gameplay/anomaly_catalog.gd")

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("Grand Entrance Hall QA: " + reason)
    quit(1)


func _run() -> void:
    var hall := HALL.instantiate() as Node3D
    if hall == null:
        _fail("Scene did not instantiate")
        return
    root.add_child(hall)
    await physics_frame
    await physics_frame
    var player := hall.get_node("Player") as CharacterBody3D
    var camera := player.get_node("Camera3D") as Camera3D
    if player.get_script() != PLAYER or not camera.current or not is_equal_approx((player.get("_camera_home") as Vector3).y,0.55):
        _fail("Original player and camera contract lost")
        return
    if Catalog.entries().size() != 49 or ProjectSettings.get_setting("application/run/main_scene") != "res://menu.tscn":
        _fail("Main start or catalog changed")
        return
    var architecture := hall.get_node("Architecture")
    var static_count := 0
    for item in hall.find_children("*","StaticBody3D",true,false):
        var body := item as StaticBody3D
        if hall.get_node("CroupierStation").is_ancestor_of(body):
            continue # NPC capsule is checked by the full croupier suite.
        var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
        var collider := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if mesh == null or collider == null or not mesh.mesh is BoxMesh or not collider.shape is BoxShape3D:
            _fail("Missing editable blockout mesh/shape: " + str(body.get_path()))
            return
        if not (mesh.mesh as BoxMesh).size.is_equal_approx((collider.shape as BoxShape3D).size) or not mesh.transform.is_equal_approx(collider.transform) or collider.disabled or body.collision_layer == 0:
            _fail("Visual/collision mismatch: " + str(body.get_path()))
            return
        if body.owner != hall or mesh.owner != hall or collider.owner != hall:
            _fail("Architecture not serialized as editable scene nodes")
            return
        static_count += 1
    if static_count < 40 or architecture.get_child_count() < 5:
        _fail("Missing authored architecture")
        return
    if not _verify_finishes(hall):
        return
    var space := hall.get_world_3d().direct_space_state
    var exclude: Array[RID] = [player.get_rid()]
    var shape := CapsuleShape3D.new()
    shape.radius = 0.34
    shape.height = 1.87
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    query.exclude = exclude
    query.collision_mask = 1
    # Test the central route, both actual arcade openings and access
    # approaches, plus the staff path and reserved future stair footprint.
    var segments: Array = [
        [Vector3(0,1.02,12),Vector3(0,1.02,-5.1)],
        [Vector3(0,1.02,1),Vector3(-10.2,1.02,1)],
        [Vector3(0,1.02,1),Vector3(10.2,1.02,1)],
        [Vector3(0,1.02,-4),Vector3(-10.2,1.02,-4)],
        [Vector3(0,1.02,-4),Vector3(10.2,1.02,-4)],
        [Vector3(-10.2,1.02,-6.4),Vector3(-10.2,1.02,4.5)],
        [Vector3(10.2,1.02,-6.4),Vector3(10.2,1.02,4.5)],
        [Vector3(-4.1,1.02,-5.0),Vector3(-4.1,1.02,-11.7)],
        [Vector3(4.1,1.02,-5.0),Vector3(4.1,1.02,-11.7)],
        [Vector3(-4.1,1.02,-10.5),Vector3(4.1,1.02,-10.5)],
    ]
    for segment in segments:
        var start: Vector3 = segment[0]
        var finish: Vector3 = segment[1]
        var steps := ceili(start.distance_to(finish)/0.20)
        for i in range(steps+1):
            var p := start.lerp(finish,float(i)/float(steps))
            query.transform = Transform3D(Basis.IDENTITY,p)
            if not space.intersect_shape(query,1).is_empty():
                _fail("Obstructed walkable route at " + str(p))
                return
            var ray := PhysicsRayQueryParameters3D.create(p, p-Vector3.UP*2.0,1,exclude)
            var hit := space.intersect_ray(ray)
            if hit.is_empty() or absf((hit["position"] as Vector3).y)>0.015:
                _fail("Floor gap or uneven floor at " + str(p))
                return
    var doors := 0
    var active := 0
    for gallery in hall.get_node("SideGalleries").get_children():
        for bay in gallery.get_node("AccessBays").get_children():
            var access := bay as Node3D
            doors += 1
            if str(access.name).begins_with("MainCasino"):
                active += 1
            var approach := access.get_node("Approach") as Marker3D
            query.transform = Transform3D(Basis.IDENTITY,approach.global_position+Vector3.UP*1.02)
            if not space.intersect_shape(query,1).is_empty():
                _fail("Door approach blocked: " + str(access.name))
                return
            var ray := PhysicsRayQueryParameters3D.create(access.to_global(Vector3(0,1.45,1.4)),access.to_global(Vector3(0,1.45,-1.0)),1,exclude)
            var hit := space.intersect_ray(ray)
            if hit.is_empty() or hit["collider"] != access.get_node("ClosedLeaf"):
                _fail("Closed access has no matching physical door: " + str(access.name))
                return
    if doors != 4 or active != 1:
        _fail("Expected one future main casino connection and three reserves")
        return
    var sight := PhysicsRayQueryParameters3D.create(Vector3(0,1.57,12),Vector3(0,1.6,-7.6),1,exclude)
    var sight_hit := space.intersect_ray(sight)
    if not sight_hit.is_empty() and sight_hit.get("collider") != hall.get_node("CroupierStation/CroupierCollision"):
        _fail("Central sightline to future NPC is blocked")
        return
    var counter_ray := PhysicsRayQueryParameters3D.create(Vector3(0,0.65,-4.8),Vector3(0,0.65,-7),1,exclude)
    if space.intersect_ray(counter_ray).is_empty():
        _fail("Reception counter is passable")
        return
    # Actual player gravity must settle on the floor, not a decorative slab.
    player.position = Vector3(0,1.35,12)
    for i in range(35):
        await physics_frame
    if not player.is_on_floor() or absf(player.position.y-0.935)>0.06:
        _fail("Player does not stand on the authored floor")
        return
    hall.queue_free()
    await process_frame
    print("Casino Anomaly Grand Entrance Hall blockout QA PASS")
    quit(0)


# Same-facing coplanar rectangles with positive projected overlap flicker.
# Test the reported joints against the actual transformed meshes.
func _has_coplanar_overlap(a: MeshInstance3D, b: MeshInstance3D) -> bool:
    var aa: AABB = a.global_transform * a.get_aabb()
    var bb: AABB = b.global_transform * b.get_aabb()
    for axis in range(3):
        var overlap := true
        for other in range(3):
            if other != axis and minf(aa.end[other],bb.end[other])-maxf(aa.position[other],bb.position[other]) <= 0.002:
                overlap = false
        if overlap and (absf(aa.position[axis]-bb.position[axis])<0.001 or absf(aa.end[axis]-bb.end[axis])<0.001):
            return true
    return false


func _verify_finishes(hall: Node3D) -> bool:
    for item in hall.find_children("*","MeshInstance3D",true,false):
        var mesh := item as MeshInstance3D
        if hall.get_node("CroupierStation").is_ancestor_of(mesh):
            continue # Imported character materials are not architecture.
        var mat := mesh.material_override as StandardMaterial3D
        if mat == null or mat.albedo_texture == null or not mat.normal_enabled or mat.normal_texture == null:
            _fail("Unfinished architectural material: "+str(mesh.get_path()))
            return false
    for side in ["West","East"]:
        var wall := hall.get_node("Architecture/MainWalls/"+side)
        var shell := hall.get_node("SideGalleries/"+side+"Gallery/Shell")
        var ceiling := shell.get_node("Ceiling/Mesh") as MeshInstance3D
        for name_value in ["ClerestoryAboveArcade","ArrivalFlank","ReceptionFlank"]:
            if _has_coplanar_overlap(ceiling,wall.get_node(name_value+"/Mesh") as MeshInstance3D):
                _fail("Gallery ceiling overlaps main wall surface: "+side+"/"+name_value)
                return false
        for pair in [["ArrivalEnd","ArrivalFlank","SolidBay3"],["RearEnd","ReceptionFlank","SolidBay1"]]:
            var end := shell.get_node(pair[0]+"/Mesh") as MeshInstance3D
            if _has_coplanar_overlap(end,wall.get_node(pair[1]+"/Mesh") as MeshInstance3D) or _has_coplanar_overlap(end,shell.get_node("OuterWall/"+pair[2]+"/Mesh") as MeshInstance3D):
                _fail("Gallery end-wall joint has overlapping faces")
                return false
        var counter := hall.get_node("Reception/Counter")
        if _has_coplanar_overlap(counter.get_node("Countertop/Mesh") as MeshInstance3D,counter.get_node(side+"ReturnTop/Mesh") as MeshInstance3D):
            _fail("Reception countertop has overlapping top surfaces")
            return false
    var runner := hall.get_node("Architecture/CentralAxis/BurgundyRunner") as MeshInstance3D
    var bounds: AABB = runner.global_transform * runner.get_aabb()
    if bounds.position.y<=0.0 or bounds.end.y>0.02 or bounds.position.x<=-2.46 or bounds.end.x>=2.46:
        _fail("Runner clips the floor or inlays")
        return false
    return true
