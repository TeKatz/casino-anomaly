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
        if hall.get_node("Interior").is_ancestor_of(body):
            continue # Imported furniture is checked against its real bounds below.
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
    if not _verify_finishes(hall) or not _verify_interior(hall):
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
        [Vector3(-3.2,1.02,12),Vector3(-3.2,1.02,4.5)],
        [Vector3(3.2,1.02,12),Vector3(3.2,1.02,4.5)],
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
    var marker := hall.get_node("SideGalleries/EastGallery/AccessBays/MainCasinoEntrance/DestinationMarker") as Node3D
    for item in hall.find_children("*","MeshInstance3D",true,false):
        var mesh := item as MeshInstance3D
        if hall.get_node("CroupierStation").is_ancestor_of(mesh):
            continue # Imported character materials are not architecture.
        if hall.get_node("Interior").is_ancestor_of(mesh):
            continue # The imported furniture has its own original materials.
        if marker.is_ancestor_of(mesh):
            # Wayfinding geometry is not an architectural PBR surface.
            if mesh.material_override == null or mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
                _fail("Invalid destination marker material or shadow")
                return false
            continue
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
    var logo := hall.get_node_or_null("Architecture/ReceptionBackdrop/BrandLogo") as Sprite3D
    var field := hall.get_node("Architecture/ReceptionBackdrop/CentralField") as MeshInstance3D
    if logo == null or logo.texture == null or logo.texture.resource_path != "res://branding/casino_anomaly_logo.png" or logo.texture.get_size() != Vector2(1739,856) or not logo.scale.is_equal_approx(Vector3.ONE) or logo.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC:
        _fail("Reception must display the original undistorted high-resolution logo")
        return false
    var field_bounds: AABB = field.global_transform * field.get_aabb()
    var half_logo := logo.texture.get_size() * logo.pixel_size * 0.5
    if absf(logo.global_position.x-field_bounds.get_center().x)>0.01 or logo.global_position.x-half_logo.x<=field_bounds.position.x or logo.global_position.x+half_logo.x>=field_bounds.end.x or logo.global_position.y-half_logo.y<=2.1 or logo.global_position.y+half_logo.y>=field_bounds.end.y or logo.global_position.z<=field_bounds.end.z+0.005:
        _fail("Reception logo is out of bounds, behind NPC, or coplanar with the wall")
        return false
    if marker.visible or not marker.find_children("*","CollisionObject3D",true,false).is_empty() or marker.position.z<0.7 or marker.position.y<2.6:
        _fail("Destination marker must initially be hidden and not obstruct the door")
        return false
    var runner := hall.get_node("Architecture/CentralAxis/BurgundyRunner") as MeshInstance3D
    var bounds: AABB = runner.global_transform * runner.get_aabb()
    if bounds.position.y<=0.0 or bounds.end.y>0.02 or bounds.position.x<=-2.46 or bounds.end.x>=2.46:
        _fail("Runner clips the floor or inlays")
        return false
    return true


func _model_bounds(model: Node3D) -> AABB:
    var result := AABB()
    var found := false
    for part in model.find_children("*","MeshInstance3D",true,false):
        var mesh := part as MeshInstance3D
        if mesh.mesh == null:
            continue
        var piece := mesh.global_transform * mesh.get_aabb()
        result = result.merge(piece) if found else piece
        found = true
    return result


func _verify_interior(hall: Node3D) -> bool:
    var interior := hall.get_node("Interior")
    var lounges := interior.get_node("Lounges")
    if lounges.get_child_count()!=4:
        _fail("Expected four coherent, separately editable waiting zones")
        return false
    var sofas := 0
    var tables := 0
    for item in lounges.find_children("*","StaticBody3D",true,false):
        var body := item as StaticBody3D
        var model := body.get_node_or_null("Model") as Node3D
        var collider := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if model==null or collider==null or collider.disabled or body.collision_layer==0 or body.owner!=hall or model.owner!=hall or collider.owner!=hall:
            _fail("Furniture is not an editable solid scene instance")
            return false
        var bounds := _model_bounds(model)
        if absf(bounds.position.y-0.014)>0.045 or bounds.size.y<0.45 or bounds.size.y>1.10 or absf(bounds.get_center().x)<4.0:
            _fail("Floating, ungrounded or incorrectly sized lounge furniture: "+str(body.name)+" "+str(bounds))
            return false
        var shape_bounds := AABB()
        if collider.shape is BoxShape3D:
            var size := (collider.shape as BoxShape3D).size
            shape_bounds = collider.global_transform * AABB(-size*0.5,size)
            sofas+=1
        elif collider.shape is CylinderShape3D:
            var cylinder := collider.shape as CylinderShape3D
            var size := Vector3(cylinder.radius*2.0,cylinder.height,cylinder.radius*2.0)
            shape_bounds = collider.global_transform * AABB(-size*0.5,size)
            tables+=1
        else:
            _fail("Unexpected furniture collision")
            return false
        if bounds.position.distance_to(shape_bounds.position)>0.12 or bounds.end.distance_to(shape_bounds.end)>0.12:
            _fail("Furniture collision does not follow the original model: "+str(body.name)+" "+str(bounds)+" "+str(shape_bounds))
            return false
    if sofas!=6 or tables!=4:
        _fail("Missing imported lounge furniture")
        return false
    for title_value in ["WestConversationLounge","EastConversationLounge"]:
        var lounge := lounges.get_node(title_value)
        var table := lounge.get_node("ConversationTable")
        var prop_node := table.get_node("ChessSet" if title_value.begins_with("West") else "GuestReading") as Node3D
        var top := _model_bounds(table.get_node("Model") as Node3D)
        var prop := _model_bounds(prop_node)
        if absf(prop.position.y-top.end.y)>0.025 or prop.position.x<top.position.x or prop.end.x>top.end.x or prop.position.z<top.position.z or prop.end.z>top.end.z:
            _fail("Lounge tabletop decoration is floating or overhanging: "+str(prop))
            return false
    var reception := interior.get_node("ReceptionDressing")
    for title_value in ["ServiceBell","OpenGuestBook"]:
        var model := reception.get_node(title_value) as Node3D
        var bounds := _model_bounds(model)
        if absf(bounds.position.y-1.09)>0.025 or bounds.position.x< -3.25 or bounds.end.x>3.25 or bounds.position.z< -6.94 or bounds.end.z> -5.96:
            _fail("Reception prop is not resting fully on the countertop: "+str(bounds))
            return false
    for side in ["West","East"]:
        var plant := reception.get_node(side+"ReceptionPlant") as StaticBody3D
        var model := plant.get_node("Model") as Node3D
        var bounds := _model_bounds(model)
        if absf(bounds.position.y)>0.06 or bounds.size.y<1.6 or bounds.size.y>2.1 or absf(bounds.get_center().x)<5.5 or plant.get_node_or_null("CollisionShape3D")==null:
            _fail("Reception plant is ungrounded or blocks the future stairs")
            return false
    var fixtures := interior.get_node("CeilingFixtures")
    for index in range(1,5):
        var fixture := fixtures.get_node("Chandelier"+str(index)) as Node3D
        var model := fixture.get_node("OriginalFixture") as Node3D
        var bounds := _model_bounds(model)
        if absf(bounds.end.y-8.6)>0.07 or bounds.position.y<6.6 or bounds.size.x<1.4 or bounds.size.x>1.8:
            _fail("Chandelier is not attached to its ceiling field: "+str(bounds))
            return false
    var light_count := 0
    var shadow_count := 0
    for item in hall.find_children("*","Light3D",true,false):
        var light := item as Light3D
        light_count += 1
        if light.shadow_enabled:
            shadow_count += 1
    if light_count>22 or shadow_count>2:
        _fail("Lobby lighting exceeded its dynamic light/shadow budget")
        return false
    print("HALL_INTERIOR_BUDGET: meshes=",hall.find_children("*","MeshInstance3D",true,false).size()," lights=",light_count," shadow_lights=",shadow_count)
    return true
