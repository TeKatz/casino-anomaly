extends Node3D
## Dedicated eye-level planar mirror. Off-axis frustum is sized to the
## actual mirror, not the player's screen. Near plane lies just inside
## the room, clipping the wall and its trim without modifying wall layers.
const MIRROR_LAYER := 1 << 18
const PHANTOM_LAYER := 1 << 19
const MODEL := "res://models/silent_audience/security_guard/scene.gltf"
const Cache = preload("res://gameplay/runtime_asset_cache.gd")
const WIDTH := 1.65
const HEIGHT := 1.85
var hall: Node3D
var capture: SubViewport
var reflected_camera: Camera3D
var player_camera: Camera3D
var original_camera_mask: int
var phantom: Node3D
var surface: ShaderMaterial
var center: Vector3
var normal: Vector3
var elapsed := 0.0
var last_eye := Vector3.ZERO
var last_plane := Transform3D.IDENTITY
var has_rendered := false
var settings_clock := 0.0
var configured := false
var panel: MeshInstance3D
const MIRROR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D reflected : filter_linear, repeat_disable;
uniform bool ready_view = false;
// Match the existing portal's display-to-linear conversion. The
// non-HDR capture is already display encoded, not scene-linear radiance.
vec3 srgb_to_linear(vec3 color) {
    return mix(color/12.92,pow((color+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),color));
}
void fragment() {
    vec3 sampled = texture(reflected, vec2(1.0 - UV.x, UV.y)).rgb;
    ALBEDO = ready_view ? (OUTPUT_IS_SRGB ? sampled : srgb_to_linear(sampled)) : vec3(0.025,0.030,0.035);
}
"""


func configure(room: Node3D, wall: MeshInstance3D) -> bool:
    hall = room
    process_priority = 100
    var packed := Cache.packed_scene(MODEL)
    if packed == null:
        return false
    phantom = packed.instantiate() as Node3D
    if phantom == null:
        return false
    # Follow the hall when streamed or repositioned.
    global_transform = room.global_transform
    # Between sofa 02 and 03. Seat the backing on the actual wall,
    # accounting for the 7 cm protrusion of the existing wainscoting.
    var bounds: AABB = (room.global_transform.affine_inverse() * wall.global_transform) * wall.get_aabb()
    global_transform = room.global_transform * Transform3D(Basis(Vector3.UP,PI),Vector3(-26.05,1.65,bounds.position.z-0.12))
    center = global_position
    normal = global_basis.z.normalized()
    capture = SubViewport.new()
    capture.name = "ReflectionViewport"
    # Preserve the physical mirror aspect ratio at roughly 5x the pixels.
    capture.size = Vector2i(1440, 1615)
    capture.use_hdr_2d = false
    capture.use_taa = false
    capture.msaa_3d = Viewport.MSAA_2X
    capture.world_3d = hall.get_world_3d()
    capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
    add_child(capture)
    reflected_camera = Camera3D.new()
    reflected_camera.name = "ReflectedCamera"
    reflected_camera.keep_aspect = Camera3D.KEEP_HEIGHT
    reflected_camera.cull_mask = (1048575 & ~MIRROR_LAYER) | PHANTOM_LAYER
    capture.add_child(reflected_camera)
    reflected_camera.make_current()
    var shape := QuadMesh.new()
    shape.size = Vector2(WIDTH, HEIGHT)
    panel = MeshInstance3D.new()
    panel.name = "MirrorSurface"
    panel.mesh = shape
    panel.layers = MIRROR_LAYER
    panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var shader := Shader.new()
    shader.code = MIRROR_SHADER
    surface = ShaderMaterial.new()
    surface.shader = shader
    surface.set_shader_parameter("reflected", capture.get_texture())
    panel.material_override = surface
    add_child(panel)
    var frame := StandardMaterial3D.new()
    frame.albedo_color = Color("#685238")
    frame.metallic = 0.62
    frame.roughness = 0.47
    for side in [-1.0,1.0]:
        _frame(Vector3(WIDTH+0.14,0.07,0.10),Vector3(0,side*(HEIGHT*0.5+0.035),0.018),frame)
        _frame(Vector3(0.07,HEIGHT,0.10),Vector3(side*(WIDTH*0.5+0.035),0,0.018),frame)
    # Closed backing meets the wall behind the decorative frame.
    _frame(Vector3(WIDTH+0.14,HEIGHT+0.14,0.12),Vector3(0,0,-0.065),frame)
    var body := StaticBody3D.new()
    body.name = "MirrorCollision"
    add_child(body)
    var collider := CollisionShape3D.new()
    collider.name = "Shape"
    var collision_box := BoxShape3D.new()
    collision_box.size = Vector3(WIDTH+0.14,HEIGHT+0.14,0.19)
    collider.shape = collision_box
    body.add_child(collider)
    collider.position = Vector3(0,0,-0.03)
    phantom.name = "ReflectionOnlyGuest"
    add_child(phantom)
    phantom.position = Vector3(0,-1.65,2.7)
    phantom.rotation.y = PI
    if not _pose_phantom():
        return false
    for item in phantom.find_children("*","MeshInstance3D",true,false):
        _reflection_only(item as MeshInstance3D)
    if phantom is MeshInstance3D:
        _reflection_only(phantom as MeshInstance3D)
    phantom.hide()
    _read_settings()
    configured = true
    return true


func _frame(dimensions: Vector3, at: Vector3, mat: Material) -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = dimensions
    mesh.mesh = box
    mesh.material_override = mat
    mesh.layers = MIRROR_LAYER
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mesh)
    mesh.position = at


func _pose_phantom() -> bool:
    # The imported security guard has its own native standing idle.
    var posed := false
    for item in phantom.find_children("*","AnimationPlayer",true,false):
        var animator := item as AnimationPlayer
        for clip in animator.get_animation_list():
            if str(clip).to_lower().get_file()=="idle":
                animator.play(clip)
                animator.advance(0.0)
                animator.seek(0.65,true)
                animator.pause()
                posed = true
                break
        if posed:
            break
    if not posed:
        return false
    var rig: Skeleton3D
    for item in phantom.find_children("*","Skeleton3D",true,false):
        rig = item as Skeleton3D
        break
    if rig == null:
        return false
    rig.force_update_all_bone_transforms()
    var head_index := -1
    var toes: Array[int] = []
    for i in range(rig.get_bone_count()):
        var key := str(rig.get_bone_name(i)).to_lower()
        if "headtop_end" in key:
            head_index = i
        elif "toebase" in key:
            toes.append(i)
    if head_index<0 or toes.size()!=2:
        return false
    var head := to_local(rig.to_global(rig.get_bone_global_pose(head_index).origin)).y
    var sole := INF
    for toe in toes:
        sole = minf(sole,to_local(rig.to_global(rig.get_bone_global_pose(toe).origin)).y)
    var height := head-sole
    if height<0.001:
        return false
    phantom.scale *= 1.74/height
    rig.force_update_all_bone_transforms()
    sole = INF
    for toe in toes:
        sole = minf(sole,to_local(rig.to_global(rig.get_bone_global_pose(toe).origin)).y)
    var floor_y := to_local(hall.to_global(Vector3(0,0.035,0))).y
    phantom.position.y += floor_y+0.035-sole
    phantom.set_meta("native_idle_pose",true)
    return true


func _reflection_only(mesh: MeshInstance3D) -> void:
    mesh.layers = PHANTOM_LAYER
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED


func _read_settings() -> void:
    var settings := get_node_or_null("/root/GameSettings")
    var quality := str(settings.call("get_option","reflection_quality")) if settings != null else "original"
    var width := 1440
    var aa := Viewport.MSAA_2X
    match quality:
        "off","low":
            width = 1008
            aa = Viewport.MSAA_DISABLED
        "medium":
            width = 1280
        "high":
            width = 1600
        "ultra":
            width = 1920
            aa = Viewport.MSAA_4X
    var wanted := Vector2i(width,roundi(float(width)*HEIGHT/WIDTH))
    if capture.size!=wanted:
        capture.size = wanted
        has_rendered = false
    if capture.msaa_3d!=aa:
        capture.msaa_3d = aa
        has_rendered = false


func _sync_reflected_camera(eye: Vector3, far_clip: float) -> bool:
    center = global_position
    normal = global_basis.z.normalized()
    var distance := (eye-center).dot(normal)
    if distance<=0.015:
        return false
    var virtual_eye := eye-2.0*distance*normal
    reflected_camera.global_position = virtual_eye
    reflected_camera.look_at(virtual_eye+normal,global_basis.y.normalized())
    var offset := center-virtual_eye
    var right := reflected_camera.global_basis.x.normalized()
    var up := reflected_camera.global_basis.y.normalized()
    var near_plane := distance+0.025
    var ratio := near_plane/distance
    reflected_camera.set_frustum(HEIGHT*ratio,Vector2(offset.dot(right),offset.dot(up))*ratio,near_plane,maxf(near_plane+1.0,far_clip))
    return true


func _process(delta: float) -> void:
    if not configured or not is_instance_valid(hall):
        return
    if hall.has_meta("_streaming_standby"):
        phantom.hide()
        _restore_camera()
        return
    var active_player := hall.get_node_or_null("Player") as Node3D
    var camera := active_player.get_node_or_null("Camera3D") as Camera3D if active_player != null else null
    if camera == null:
        phantom.hide()
        _restore_camera()
        return
    if camera != player_camera:
        _restore_camera()
        player_camera = camera
        original_camera_mask = camera.cull_mask
        camera.cull_mask = (original_camera_mask | MIRROR_LAYER) & ~PHANTOM_LAYER
        reflected_camera.cull_mask = (original_camera_mask & ~MIRROR_LAYER) | PHANTOM_LAYER
        phantom.show()
    settings_clock += delta
    if settings_clock>=0.35:
        settings_clock = 0.0
        _read_settings()
    var eye := camera.get_camera_transform().origin
    center = global_position
    normal = global_basis.z.normalized()
    # Do not freeze the image based on player view direction.
    if (eye-center).dot(normal)<=0.015 or eye.distance_to(center)>22.0:
        capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
        surface.set_shader_parameter("ready_view",false)
        has_rendered = false
        return
    elapsed += delta
    # A translated eye always gets a fresh capture that frame. Rotation
    # alone leaves the wall-aligned perspective unchanged. At rest retain
    # the 30 Hz budget for scene motion (dust, etc.).
    if has_rendered and eye.is_equal_approx(last_eye) and global_transform.is_equal_approx(last_plane) and elapsed<1.0/30.0:
        return
    if not _sync_reflected_camera(eye,camera.far):
        return
    elapsed = 0.0
    last_eye = eye
    last_plane = global_transform
    has_rendered = true
    capture.render_target_update_mode = SubViewport.UPDATE_ONCE
    surface.set_shader_parameter("ready_view",true)


func _restore_camera() -> void:
    if is_instance_valid(player_camera):
        player_camera.cull_mask = original_camera_mask
    player_camera = null
    has_rendered = false
    if is_instance_valid(capture):
        capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
    if surface != null:
        surface.set_shader_parameter("ready_view",false)


func _exit_tree() -> void:
    _restore_camera()
