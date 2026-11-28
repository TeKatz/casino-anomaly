extends Node3D
## A moving, solid section of the actual wall reveals an upside-down copy
## of the casino. Only visual instances enter the private World3D; no
## gameplay, player, colliders, scripts, portals, GI rigs or audio are cloned.
const PORTAL_SHADER = preload("res://gameplay/anomalies/other_side_portal.gdshader")
## Clear approach between lounge groups 02 and 03, away from the card table.
const CENTER_X := -26.40
const OPEN_WIDTH := 2.40
const SLIDE := 4.08
const POCKET_DEPTH := 0.42
const OPEN_TIME := 6.0
const HOLD_TIME := 26.0
const CLOSE_TIME := 6.0
const REST_TIME := 8.0
const ACTIVATION_RADIUS := 14.0
const SECTIONS := ["Architecture","RedCarpet","SlotMachines","GamingTables","CornerBar","Lounge","Decor","ModelInteriors","SketchfabFurniture","Lighting","StreamingPortals"]
const CARD_PATH := "res://models/playing_cards/individual/card_%02d.gltf"
const CARD_IDS := [12,1,14,6,19,32,40,51]
var hall: Node3D
var panel: Node3D
var portal: MeshInstance3D
var capture: SubViewport
var virtual_camera: Camera3D
var inverted: Node3D
var objects: Node3D
var portal_material: ShaderMaterial
var saved: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var wall_bounds: AABB
var portal_z := 0.84
var elapsed := 0.0
var frame_clock := 0.0
var settings_clock := 0.0
var debris_clock := 0.0
var phase := "waiting"
var configured := false
var reduced := false
var quality := "original"
var cloned_meshes := 0
var cloned_lights := 0
var shadow_lights := 0
var last_eye := Vector3.ZERO
var has_rendered := false
var open_fraction := 0.0


func configure(room: Node3D, wall: MeshInstance3D) -> bool:
    hall = room
    # Sample the eye after the player/controller updates its transform.
    process_priority = 100
    wall_bounds = _local_bounds(wall)
    var left := CENTER_X-OPEN_WIDTH*0.5
    var right := CENTER_X+OPEN_WIDTH*0.5
    if wall_bounds.position.x>left or wall_bounds.end.x<right or wall_bounds.size.y<4.8:
        push_warning("Other Side: authored wall does not contain the aperture")
        return false
    var trim := _find_wainscoting(wall,left,right)
    if trim == null:
        push_warning("Other Side: no matching lower wall cladding")
        return false
    portal_z = wall_bounds.end.z+POCKET_DEPTH+0.07
    # Build from the original unmodified room before replacing its wall.
    _build_world()
    if cloned_meshes<30:
        push_warning("Other Side: not enough visible source geometry (%d meshes)" % cloned_meshes)
        return false
    panel = Node3D.new()
    panel.name = "SlidingWallSection"
    add_child(panel)
    _split(wall,left,right,"Wall")
    _split(trim,left,right,"Wainscoting")
    _build_aperture()
    _read_settings()
    _set_open_fraction(0.0)
    configured = true
    return true


func _find_wainscoting(wall: MeshInstance3D, left: float, right: float) -> MeshInstance3D:
    # In the saved gameplay/casino/main.tscn, repeated WoodWainscoting names become
    # @MeshInstance3D@N. Match the lower cladding's actual geometry,
    # not an editor-generated name (or a particular generated number).
    var best: MeshInstance3D
    var best_score := INF
    for item in wall.get_parent().get_children():
        var candidate := item as MeshInstance3D
        if candidate == null or candidate == wall or not candidate.visible or not (candidate.mesh is BoxMesh):
            continue
        var b := _local_bounds(candidate)
        if b.size.x<=OPEN_WIDTH or b.position.x>left or b.end.x<right:
            continue
        if b.size.z>0.35 or b.size.y<0.8 or b.size.y>2.8:
            continue
        if absf(b.position.y-wall_bounds.position.y)>0.30 or absf(b.get_center().z-wall_bounds.position.z)>0.30:
            continue
        var score := absf(b.get_center().z-wall_bounds.position.z)+absf(b.position.y-wall_bounds.position.y)+absf(b.size.y-2.0)*0.25
        if score<best_score:
            best_score = score
            best = candidate
    return best


func _local_bounds(mesh: MeshInstance3D) -> AABB:
    return (hall.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()


func _source_visible(node: Node3D, section: Node3D) -> bool:
    # Staged halls can be invisible as a whole; keep their authored local
    # visibility but do not confuse streaming visibility with hidden props.
    var current: Node = node
    while current != null:
        if current is Node3D and not (current as Node3D).visible:
            return false
        if current == section:
            break
        current = current.get_parent()
    return true


func _build_world() -> void:
    capture = SubViewport.new()
    capture.name = "OtherSideViewport"
    capture.own_world_3d = true
    capture.size = Vector2i(2560,1440)
    capture.use_hdr_2d = false
    capture.scaling_3d_scale = 1.0
    capture.use_taa = false
    capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
    add_child(capture)
    var environment_node := WorldEnvironment.new()
    environment_node.name = "InvertedEnvironment"
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#080b10")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#8896a9")
    env.ambient_light_energy = 0.19
    env.ambient_light_sky_contribution = 0.0
    # Independent post-processing; avoid the flat full-room fill of the
    # first version. Forward+ calculates contact shadows and reflections
    # directly from the inverted geometry, without the real hall's GI.
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 0.86
    env.ssao_enabled = true
    env.ssao_radius = 0.84
    env.ssao_intensity = 1.45
    env.ssao_light_affect = 0.28
    env.ssil_enabled = true
    env.ssil_radius = 2.2
    env.ssil_intensity = 0.70
    env.ssr_enabled = true
    env.ssr_max_steps = 48
    env.glow_enabled = true
    env.glow_intensity = 0.25
    env.glow_bloom = 0.012
    env.glow_hdr_threshold = 1.15
    env.volumetric_fog_enabled = true
    env.volumetric_fog_density = 0.013
    env.volumetric_fog_albedo = Color("#8396ac")
    env.volumetric_fog_length = 30.0
    env.volumetric_fog_ambient_inject = 0.02
    environment_node.environment = env
    capture.add_child(environment_node)
    inverted = Node3D.new()
    inverted.name = "InvertedCasino"
    capture.add_child(inverted)
    # The current aperture is on the south wall (interior at -Z).
    # Invert about its horizontal tangent, not the former north-wall
    # viewing axis. Source inward -Z maps to portal inward +Z; X stays
    # registered to the same bay. Y flips about the actual wall midpoint.
    var source_anchor := Vector3(CENTER_X,wall_bounds.get_center().y,wall_bounds.position.z)
    var destination_anchor := Vector3(CENTER_X,wall_bounds.get_center().y,portal_z)
    var turn := Basis(Vector3.RIGHT,PI)
    inverted.transform = Transform3D(turn,destination_anchor-turn*source_anchor)
    var inverse := hall.global_transform.affine_inverse()
    for section_name in SECTIONS:
        var section := hall.get_node_or_null(str(section_name)) as Node3D
        if section == null:
            continue
        var group := Node3D.new()
        group.name = str(section_name)
        inverted.add_child(group)
        for item in section.find_children("*","MeshInstance3D",true,false):
            var source := item as MeshInstance3D
            if source.mesh == null or not _source_visible(source,section):
                continue
            var bounds := _local_bounds(source)
            # The near wall is the actual source aperture's south wall.
            # Clip only its flat cladding, not the original room or its
            # columns, opposite wall, signs, or streamed exit corridors.
            if section_name!="StreamingPortals" and bounds.position.z>=wall_bounds.position.z-0.30 and bounds.size.z<=0.65 and bounds.size.x>2.0:
                continue
            var copy := MeshInstance3D.new()
            copy.name = "Mesh_%04d_%s" % [cloned_meshes,str(source.name).replace("@","_")]
            copy.mesh = source.mesh
            copy.material_override = source.material_override
            copy.material_overlay = source.material_overlay
            for i in range(source.mesh.get_surface_count()):
                var mat := source.get_surface_override_material(i)
                if mat != null:
                    copy.set_surface_override_material(i,mat)
            copy.cast_shadow = source.cast_shadow
            copy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
            group.add_child(copy)
            copy.transform = inverse*source.global_transform
            cloned_meshes += 1
        for item in section.find_children("*","Label3D",true,false):
            var source := item as Label3D
            if not _source_visible(source,section):
                continue
            var label := Label3D.new()
            label.text = source.text
            label.font = source.font
            label.font_size = source.font_size
            label.pixel_size = source.pixel_size
            label.modulate = source.modulate
            label.outline_modulate = source.outline_modulate
            label.outline_size = source.outline_size
            label.double_sided = source.double_sided
            group.add_child(label)
            label.transform = inverse*source.global_transform
        for item in section.find_children("*","Light3D",true,false):
            var source := item as Light3D
            if not _source_visible(source,section) or source.light_energy<=0.0:
                continue
            _copy_light(source,group,inverse)
    # Cool, low-key fill from the inverted ceiling/floor. Original light
    # fixtures and emissive materials remain recognizable, but colder.
    for offset in [-9.0,0.0,9.0]:
        var fill := OmniLight3D.new()
        fill.name = "OtherworldFill"
        fill.light_color = Color("#8faac7")
        fill.light_energy = 0.24
        fill.omni_range = 8.5
        fill.omni_attenuation = 1.4
        fill.shadow_enabled = false
        capture.add_child(fill)
        fill.position = Vector3(CENTER_X+offset,3.8,portal_z+7.0)
    # A low cool pool at the base of the inverted chandelier emphasizes
    # its silhouette; the original fixtures remain the primary lights.
    var accent := OmniLight3D.new()
    accent.name = "InvertedChandelierAccent"
    accent.light_color = Color("#9db8db")
    accent.light_energy = 0.48
    accent.omni_range = 5.0
    accent.shadow_enabled = true
    accent.light_volumetric_fog_energy = 0.28
    capture.add_child(accent)
    accent.position = Vector3(CENTER_X,1.7,portal_z+6.6)
    virtual_camera = Camera3D.new()
    virtual_camera.name = "OtherSideCamera"
    capture.add_child(virtual_camera)
    virtual_camera.make_current()
    _build_debris()


func _copy_light(source: Light3D, group: Node3D, inverse: Transform3D) -> void:
    var light: Light3D
    if source is OmniLight3D:
        var omni := OmniLight3D.new()
        omni.omni_range = source.omni_range
        omni.omni_attenuation = source.omni_attenuation
        light = omni
    elif source is SpotLight3D:
        var spot := SpotLight3D.new()
        spot.spot_range = source.spot_range
        spot.spot_angle = source.spot_angle
        spot.spot_attenuation = source.spot_attenuation
        spot.spot_angle_attenuation = source.spot_angle_attenuation
        light = spot
    else:
        return
    light.name = "InvertedLight_%03d" % cloned_lights
    light.light_color = source.light_color.lerp(Color("#a7cfeb"),0.32)
    light.light_energy = source.light_energy*0.95
    light.light_specular = source.light_specular
    var local_position := (inverse*source.global_transform).origin
    # Limit extra shadow maps to a small number of relevant interior lights.
    light.shadow_enabled = source.shadow_enabled and shadow_lights<8 and absf(local_position.x-CENTER_X)<14.0 and local_position.z<wall_bounds.position.z
    if light.shadow_enabled:
        shadow_lights += 1
    light.light_volumetric_fog_energy = minf(source.light_volumetric_fog_energy,0.42)
    group.add_child(light)
    light.transform = inverse*source.global_transform
    cloned_lights += 1


func _split(source: MeshInstance3D, left: float, right: float, label: String) -> void:
    var bounds := _local_bounds(source)
    saved.append({"node":source,"visible":source.visible})
    # Rebuild only the visible cladding, preserving the original collider.
    # Match the existing texture density and offset on each cut section.
    _piece(source,bounds,bounds.position.x,left,self,label+"Left")
    _piece(source,bounds,right,bounds.end.x,self,label+"Right")
    _piece(source,bounds,left,right,panel,label+"Moving")
    source.hide()


func _piece(source: MeshInstance3D, bounds: AABB, left: float, right: float, parent: Node3D, label: String) -> void:
    if right-left<0.001:
        return
    # Crop the original box vertices and face UVs instead of scaling a new
    # atlas-mapped BoxMesh. On the long faces this preserves the exact
    # position, density, seam alignment and normal maps of the wall fabric.
    var arrays := source.mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var original_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
    var uv := original_uv.duplicate()
    var original_vertices := vertices.duplicate()
    var mesh_bounds := source.mesh.get_aabb()
    var begin := (left-bounds.position.x)/bounds.size.x
    var finish := (right-bounds.position.x)/bounds.size.x
    var local_center := mesh_bounds.position.x+mesh_bounds.size.x*(begin+finish)*0.5
    for i in range(vertices.size()):
        var v := original_vertices[i]
        var old_t := (v.x-mesh_bounds.position.x)/mesh_bounds.size.x
        var new_t := lerpf(begin,finish,old_t)
        if original_uv.size()==vertices.size() and normals.size()==vertices.size() and absf(normals[i].x)<0.5:
            # Find the matching vertex at the opposite X edge of this face.
            for j in range(original_vertices.size()):
                var other := original_vertices[j]
                if absf(other.y-v.y)>0.0001 or absf(other.z-v.z)>0.0001 or normals[i].dot(normals[j])<0.99:
                    continue
                var other_t := (other.x-mesh_bounds.position.x)/mesh_bounds.size.x
                if absf(other_t-old_t)<0.5:
                    continue
                uv[i] = original_uv[i].lerp(original_uv[j],(new_t-old_t)/(other_t-old_t))
                break
        v.x = mesh_bounds.position.x+mesh_bounds.size.x*new_t-local_center
        vertices[i] = v
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_TEX_UV] = uv
    var cropped := ArrayMesh.new()
    cropped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = cropped
    part.material_override = source.get_active_material(0)
    part.material_overlay = source.material_overlay
    part.cast_shadow = source.cast_shadow
    part.gi_mode = source.gi_mode
    parent.add_child(part)
    part.transform = hall.global_transform.affine_inverse()*source.global_transform*Transform3D(Basis.IDENTITY,Vector3(local_center,0,0))


func _build_aperture() -> void:
    # The screen is slightly behind the moving wall. The remaining real
    # opaque wall pieces and their thickness form the aperture naturally.
    var quad := QuadMesh.new()
    quad.size = Vector2(7.8,wall_bounds.size.y)
    portal = MeshInstance3D.new()
    portal.name = "OtherSideAperture"
    portal.mesh = quad
    portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    portal.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    portal_material = ShaderMaterial.new()
    portal_material.shader = PORTAL_SHADER
    portal_material.set_shader_parameter("other_view",capture.get_texture())
    portal_material.set_shader_parameter("aperture_size",quad.size)
    portal.material_override = portal_material
    add_child(portal)
    portal.position = Vector3(CENTER_X-0.65,wall_bounds.get_center().y,portal_z)
    # A narrow, dark sill gives the non-traversable aperture physical depth
    # while the original collision remains exactly where it was.
    var sill := MeshInstance3D.new()
    sill.name = "Threshold"
    var box := BoxMesh.new()
    box.size = Vector3(OPEN_WIDTH,0.07,portal_z-wall_bounds.position.z)
    sill.mesh = box
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color("#251d18")
    dark.roughness = 0.84
    sill.material_override = dark
    add_child(sill)
    sill.position = Vector3(CENTER_X,wall_bounds.position.y+0.035,(portal_z+wall_bounds.position.z)*0.5)


func _build_debris() -> void:
    objects = Node3D.new()
    objects.name = "ReverseGravityObjects"
    capture.add_child(objects)
    var rng := RandomNumberGenerator.new()
    rng.seed = 320412
    for i in range(CARD_IDS.size()+6):
        var body := Node3D.new()
        body.name = "FallingDebris_%02d" % i
        objects.add_child(body)
        if i<CARD_IDS.size():
            var packed := ResourceLoader.load(CARD_PATH % int(CARD_IDS[i]),"PackedScene") as PackedScene
            if packed != null:
                var card := packed.instantiate() as Node3D
                if card != null:
                    body.add_child(card)
                    card.scale = Vector3.ONE*0.17
        else:
            var chip := MeshInstance3D.new()
            var disk := CylinderMesh.new()
            disk.top_radius = 0.033
            disk.bottom_radius = 0.033
            disk.height = 0.008
            disk.radial_segments = 24
            var mat := StandardMaterial3D.new()
            mat.albedo_color = [Color("#b34e44"),Color("#cbbba2"),Color("#3e6562")][i%3]
            mat.roughness = 0.60
            disk.material = mat
            chip.mesh = disk
            body.add_child(chip)
        debris.append({"node":body,"x":CENTER_X+rng.randf_range(-2.4,2.4),"z":portal_z+rng.randf_range(2.0,8.0),
            "delay":rng.randf_range(0.0,5.0),"period":rng.randf_range(3.8,6.2),"spin":rng.randf_range(-2.0,2.0)})
    _update_debris(0.0)


func _update_debris(delta: float) -> void:
    if not reduced:
        debris_clock += delta
    for data in debris:
        var body := data["node"] as Node3D
        body.visible = not reduced
        if reduced:
            continue
        var age := fposmod(debris_clock+float(data["delay"]),float(data["period"]))
        var progress := clampf(age/(float(data["period"])*0.78),0.0,1.0)
        var fall := progress*progress
        var fade := smoothstep(0.0,0.12,progress)*(1.0-smoothstep(0.94,1.0,progress))
        body.scale = Vector3.ONE*maxf(0.001,fade)
        body.position = Vector3(float(data["x"])+sin(age*1.7+float(data["delay"]))*0.16,wall_bounds.end.y-0.30-fall*(wall_bounds.size.y-0.55),float(data["z"])+cos(age*0.9)*0.19)
        body.rotation = Vector3(age*float(data["spin"]),age*0.78,age*0.63)


func _read_settings() -> void:
    var settings := get_node_or_null("/root/GameSettings")
    reduced = settings != null and bool(settings.call("get_option","reduced_motion"))
    # Independent of reflection enablement: the view itself is an anomaly,
    # not a reflection. Use that quality preference only to cap resolution.
    quality = str(settings.call("get_option","reflection_quality")) if settings != null else "original"
    var msaa := Viewport.MSAA_DISABLED
    if quality in ["medium","original"]:
        msaa = Viewport.MSAA_2X
    elif quality in ["high","ultra"]:
        msaa = Viewport.MSAA_4X
    if capture.msaa_3d != msaa:
        capture.msaa_3d = msaa
    var env := (capture.get_node("InvertedEnvironment") as WorldEnvironment).environment
    var fog_quality := str(settings.call("get_option","fog_quality")) if settings != null else "original"
    var ao_quality := str(settings.call("get_option","ssao_quality")) if settings != null else "original"
    env.volumetric_fog_enabled = fog_quality!="off"
    env.ssao_enabled = ao_quality!="off"
    env.ssil_enabled = bool(settings.call("get_option","ssil")) if settings != null else true
    env.ssr_enabled = quality!="off"
    env.ssr_max_steps = 24 if quality in ["off","low"] else 48
    env.glow_enabled = bool(settings.call("get_option","bloom")) if settings != null else true


func _set_open_fraction(value: float) -> void:
    open_fraction = clampf(value,0.0,1.0)
    var retreat := smoothstep(0.0,0.18,open_fraction)
    var slide := smoothstep(0.10,1.0,open_fraction)
    # Tiny initial seam, then retreat into a pocket and slide sideways.
    panel.position = Vector3(-SLIDE*slide,0.0,POCKET_DEPTH*retreat+0.008)
    portal.visible = open_fraction>0.08


func _advance(delta: float, near: bool) -> void:
    if reduced:
        if near or phase!="waiting":
            phase = "open"
            elapsed = 0.0
            _set_open_fraction(1.0)
        return
    match phase:
        "waiting":
            if near:
                phase = "opening"
                elapsed = 0.0
        "opening":
            elapsed += delta
            _set_open_fraction(elapsed/OPEN_TIME)
            if elapsed>=OPEN_TIME:
                elapsed = 0.0
                phase = "open"
        "open":
            elapsed += delta
            if elapsed>=HOLD_TIME:
                elapsed = 0.0
                phase = "closing"
        "closing":
            elapsed += delta
            _set_open_fraction(1.0-elapsed/CLOSE_TIME)
            if elapsed>=CLOSE_TIME:
                elapsed = 0.0
                phase = "rest"
        "rest":
            elapsed += delta
            if elapsed>=REST_TIME:
                phase = "waiting"
                elapsed = 0.0


func _render_view(camera: Camera3D, delta: float) -> void:
    if phase not in ["opening","open","closing"]:
        return
    var eye := hall.to_local(camera.get_camera_transform().origin)
    var center := portal.position
    if eye.z>=wall_bounds.position.z or eye.distance_to(center)>20.0:
        return
    var screen := camera.get_viewport().get_visible_rect().size
    if screen.x<2.0 or screen.y<2.0:
        return
    var wanted := _portal_capture_size(screen)
    var size_changed := capture.size!=wanted
    frame_clock += delta
    var rate := 30.0 if quality in ["off","low"] else 60.0
    # Looking around does not change a wall-aligned capture. Translation
    # does; refresh immediately, including very small head movements.
    # Never freeze a screen-space image just because the eye looks aside.
    if has_rendered and not size_changed and eye.is_equal_approx(last_eye) and frame_clock<1.0/rate:
        return
    frame_clock = 0.0
    if size_changed:
        capture.size = wanted
    _sync_portal_camera(eye,camera.far)
    last_eye = eye
    capture.render_target_update_mode = SubViewport.UPDATE_ONCE
    if not has_rendered:
        has_rendered = true
        portal_material.set_shader_parameter("view_ready",true)


func _portal_capture_size(screen: Vector2) -> Vector2i:
    var aperture_size := (portal.mesh as QuadMesh).size
    # Match the physical image plane, not the player's screen aspect.
    # Preserve the existing quality tiers and their resolution caps.
    var aspect := aperture_size.x/aperture_size.y
    var target := _capture_size(Vector2(screen.x,screen.x/aspect))
    return Vector2i(target.x,maxi(2,roundi(float(target.x)/aspect)))


func _sync_portal_camera(eye: Vector3, far_clip: float) -> void:
    var center := portal.position
    var aperture_size := (portal.mesh as QuadMesh).size
    var depth := center.z-eye.z
    # Off-axis perspective: the near plane is the physical portal quad.
    # Its normal is +Z, so the camera's right axis is -X. The projection
    # depends only on the eye's position relative to the wall, not its yaw,
    # pitch or FOV. Geometry in front of the portal is clipped naturally.
    virtual_camera.global_transform = Transform3D(Basis(Vector3.LEFT,Vector3.UP,Vector3.FORWARD),eye)
    virtual_camera.keep_aspect = Camera3D.KEEP_HEIGHT
    var offset := Vector2(eye.x-center.x,center.y-eye.y)
    virtual_camera.set_frustum(aperture_size.y,offset,depth,maxf(far_clip,depth+60.0))


func _capture_size(screen: Vector2) -> Vector2i:
    # Shared quality policy for a requested image aspect. Supersample
    # normal/high settings instead of enlarging a 1600px image.
    var cap := 2560.0
    var sample_scale := 1.25
    match quality:
        "off","low":
            cap = 1280.0
            sample_scale = 0.85
        "medium":
            cap = 1920.0
            sample_scale = 1.0
        "high":
            cap = 3200.0
            sample_scale = 1.5
        "ultra":
            cap = 3840.0
            sample_scale = 1.75
    var factor := minf(sample_scale,cap/maxf(screen.x,screen.y))
    return Vector2i(maxi(2,roundi(screen.x*factor)),maxi(2,roundi(screen.y*factor)))


func _process(delta: float) -> void:
    if not configured or not is_instance_valid(hall):
        return
    if hall.has_meta("_streaming_standby"):
        capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
        return
    var player := hall.get_node_or_null("Player") as Node3D
    if player == null:
        return
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    if camera == null:
        return
    settings_clock += delta
    if settings_clock>=0.35:
        settings_clock = 0.0
        _read_settings()
    var local := hall.to_local(player.global_position)
    var near := Vector2(local.x-CENTER_X,local.z-wall_bounds.position.z).length()<ACTIVATION_RADIUS
    _advance(delta,near)
    if phase in ["opening","open","closing"]:
        _update_debris(delta)
        _render_view(camera,delta)


func _exit_tree() -> void:
    for record in saved:
        var source := record["node"] as MeshInstance3D
        if is_instance_valid(source):
            source.visible = bool(record["visible"])
    saved.clear()
