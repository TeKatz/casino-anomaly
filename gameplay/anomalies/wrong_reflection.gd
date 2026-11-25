extends Node3D
## Dedicated eye-level planar mirror. Off-axis frustum is sized to the
## actual mirror, not the player's screen. Near plane lies just inside
## the room, clipping the wall and its trim without modifying wall layers.
const MIRROR_LAYER := 1 << 18
const PHANTOM_LAYER := 1 << 19
const MODEL := "res://models/concrete_cat_statue/concrete_cat_statue_1k.gltf"
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
var configured := false
var panel: MeshInstance3D
const MIRROR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D reflected : filter_linear, repeat_disable;
uniform bool ready_view = false;
void fragment() {
    vec3 reflected_color = texture(reflected, vec2(1.0 - UV.x, UV.y)).rgb;
    ALBEDO = ready_view ? reflected_color * vec3(0.88, 0.91, 0.94) : vec3(0.07, 0.09, 0.10);
}
"""


func configure(room: Node3D, wall: MeshInstance3D) -> bool:
    hall = room
    var packed := ResourceLoader.load(MODEL, "PackedScene") as PackedScene
    if packed == null:
        return false
    phantom = packed.instantiate() as Node3D
    if phantom == null:
        return false
    top_level = true
    global_transform = room.global_transform
    # Between sofa 02 and 03, in front of the wall's wooden trim.
    var bounds: AABB = (room.global_transform.affine_inverse() * wall.global_transform) * wall.get_aabb()
    position = room.to_global(Vector3(-26.05, 1.65, bounds.position.z - 0.48))
    rotation = room.global_rotation + Vector3(0, PI, 0)
    center = global_position
    normal = global_basis.z.normalized()
    capture = SubViewport.new()
    capture.name = "ReflectionViewport"
    capture.size = Vector2i(640, 718)
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
    phantom.name = "ReflectionOnlyCat"
    add_child(phantom)
    phantom.position = Vector3(0, -0.93, 2.7)
    phantom.scale = Vector3.ONE * 2.65
    for item in phantom.find_children("*","MeshInstance3D",true,false):
        _reflection_only(item as MeshInstance3D)
    if phantom is MeshInstance3D:
        _reflection_only(phantom as MeshInstance3D)
    phantom.hide()
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


func _reflection_only(mesh: MeshInstance3D) -> void:
    mesh.layers = PHANTOM_LAYER
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED


func _process(delta: float) -> void:
    if not configured or not is_instance_valid(hall) or hall.has_meta("_streaming_standby"):
        return
    var active_player := hall.get_node_or_null("Player") as Node3D
    var camera := active_player.get_node_or_null("Camera3D") as Camera3D if active_player != null else null
    if camera == null:
        return
    if camera != player_camera:
        _restore_camera()
        player_camera = camera
        original_camera_mask = camera.cull_mask
        camera.cull_mask = (original_camera_mask | MIRROR_LAYER) & ~PHANTOM_LAYER
        phantom.show()
    elapsed += delta
    if elapsed < 0.045:
        return
    elapsed = 0.0
    var pos := player_camera.global_position
    var distance := (pos-center).dot(normal)
    if distance < 0.12 or pos.distance_to(center) > 15.0 or (-player_camera.global_basis.z).dot((center-pos).normalized()) < 0.1:
        return
    var virtual_eye := pos - 2.0 * distance * normal
    reflected_camera.global_position = virtual_eye
    reflected_camera.look_at(virtual_eye + normal, hall.global_basis.y.normalized())
    var offset := center - virtual_eye
    var right := reflected_camera.global_basis.x.normalized()
    var up := reflected_camera.global_basis.y.normalized()
    # Off-axis near-plane rectangle corresponding exactly to the mirror.
    var near_plane := distance + 0.025
    var ratio := near_plane / distance
    reflected_camera.set_frustum(HEIGHT * ratio, Vector2(offset.dot(right),offset.dot(up))*ratio,near_plane,maxf(near_plane+1.0,player_camera.far))
    capture.render_target_update_mode = SubViewport.UPDATE_ONCE
    surface.set_shader_parameter("ready_view",true)


func _restore_camera() -> void:
    if is_instance_valid(player_camera):
        player_camera.cull_mask = original_camera_mask
    player_camera = null


func _exit_tree() -> void:
    _restore_camera()
