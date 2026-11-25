extends Node3D
## Anomaly-only planar mirror in an existing painting frame. Uses the
## live hall world, reflected camera, and a reflection-exclusive mesh.
const MIRROR_LAYER := 1 << 18
const PHANTOM_LAYER := 1 << 19
const MODEL := "res://models/concrete_cat_statue/concrete_cat_statue_1k.gltf"
const MIRROR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D reflected : filter_linear, repeat_disable;
uniform bool ready_view = false;
void fragment() {
    vec3 image = texture(reflected, vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y)).rgb;
    ALBEDO = ready_view ? image * vec3(0.82, 0.87, 0.91) : vec3(0.12, 0.14, 0.16);
}
"""
var hall: Node3D
var canvas: MeshInstance3D
var wall: MeshInstance3D
var original_mat: Material
var original_canvas_layers: int
var original_wall_layers: int
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


func configure(room: Node3D, painting: MeshInstance3D, backing: MeshInstance3D) -> bool:
    hall = room
    canvas = painting
    wall = backing
    var packed := ResourceLoader.load(MODEL, "PackedScene") as PackedScene
    if packed == null:
        return false
    phantom = packed.instantiate() as Node3D
    if phantom == null:
        return false
    original_mat = canvas.material_override
    original_canvas_layers = canvas.layers
    original_wall_layers = wall.layers
    center = canvas.to_global(canvas.get_aabb().get_center())
    normal = canvas.global_basis.z.normalized()
    # The painting faces the public side of the south-west wall.
    if normal.dot(-hall.global_basis.z) < 0.0:
        normal = -normal
    capture = SubViewport.new()
    capture.name = "ReflectionViewport"
    capture.size = Vector2i(640, 360)
    capture.world_3d = hall.get_world_3d()
    capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
    add_child(capture)
    reflected_camera = Camera3D.new()
    reflected_camera.name = "ReflectedCamera"
    reflected_camera.cull_mask = (1048575 & ~MIRROR_LAYER) | PHANTOM_LAYER
    capture.add_child(reflected_camera)
    reflected_camera.make_current()
    var shader := Shader.new()
    shader.code = MIRROR_SHADER
    surface = ShaderMaterial.new()
    surface.shader = shader
    surface.set_shader_parameter("reflected", capture.get_texture())
    canvas.material_override = surface
    canvas.layers = MIRROR_LAYER
    # Exclude the mirror backing wall from the behind-plane camera only.
    wall.layers = MIRROR_LAYER
    phantom.name = "ReflectionOnlyCat"
    add_child(phantom)
    phantom.global_position = center + normal * 2.3 - hall.global_basis.y.normalized() * (center.y - hall.global_position.y - 0.02)
    phantom.scale = Vector3.ONE * 3.0
    phantom.hide()
    for item in phantom.find_children("*", "MeshInstance3D", true, false):
        var mesh := item as MeshInstance3D
        mesh.layers = PHANTOM_LAYER
        mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    if phantom is MeshInstance3D:
        var mesh_root := phantom as MeshInstance3D
        mesh_root.layers = PHANTOM_LAYER
        mesh_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mesh_root.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    configured = true
    return true


func _process(delta: float) -> void:
    if not configured or not is_instance_valid(hall):
        return
    if hall.has_meta("_streaming_standby"):
        return
    var active_player := hall.get_node_or_null("Player") as Node3D
    var active_camera := active_player.get_node_or_null("Camera3D") as Camera3D if active_player != null else null
    if active_camera == null:
        return
    if active_camera != player_camera:
        _restore_camera()
        player_camera = active_camera
        original_camera_mask = player_camera.cull_mask
        player_camera.cull_mask = (original_camera_mask | MIRROR_LAYER) & ~PHANTOM_LAYER
        phantom.show()
    elapsed += delta
    if elapsed < 0.067:
        return
    elapsed = 0.0
    var pos := player_camera.global_position
    var distance := (pos - center).dot(normal)
    if distance < 0.1 or pos.distance_to(center) > 14.0:
        return
    var reflected_pos := pos - 2.0 * distance * normal
    var forward := -player_camera.global_basis.z.normalized()
    var up := player_camera.global_basis.y.normalized()
    forward = forward - 2.0 * forward.dot(normal) * normal
    up = up - 2.0 * up.dot(normal) * normal
    reflected_camera.global_position = reflected_pos
    reflected_camera.look_at(reflected_pos + forward, up)
    reflected_camera.fov = player_camera.fov
    reflected_camera.keep_aspect = player_camera.keep_aspect
    reflected_camera.near = maxf(0.05, distance - 0.30)
    reflected_camera.far = player_camera.far
    var screen := player_camera.get_viewport().get_visible_rect().size
    if screen.y > 0.0:
        var desired := Vector2i(640, clampi(roundi(640.0 * screen.y / screen.x), 240, 640))
        if capture.size != desired:
            capture.size = desired
    capture.render_target_update_mode = SubViewport.UPDATE_ONCE
    surface.set_shader_parameter("ready_view", true)


func _restore_camera() -> void:
    if is_instance_valid(player_camera):
        player_camera.cull_mask = original_camera_mask
    player_camera = null


func _exit_tree() -> void:
    _restore_camera()
    if configured:
        if is_instance_valid(canvas):
            canvas.material_override = original_mat
            canvas.layers = original_canvas_layers
        if is_instance_valid(wall):
            wall.layers = original_wall_layers
