extends RefCounted
## Render the actual animated human mesh once into an isolated transparent
## viewport. No person, collision or extra light exists in the casino.
const MODEL_PATH := "res://models/croupier/scene.gltf"
const PROJECTOR := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D silhouette : filter_linear, repeat_disable;
void fragment() {
    // A broad penumbra and slightly softer distant end. The underlying
    // illuminated carpet remains visible through the darkened projection.
    vec2 pixel = vec2(1.0 / 512.0, 1.0 / 768.0);
    vec2 blur = pixel * mix(12.0, 4.0, UV.y);
    float mask = texture(silhouette, UV).a * 0.20;
    mask += texture(silhouette, UV + vec2(blur.x, 0.0)).a * 0.12;
    mask += texture(silhouette, UV - vec2(blur.x, 0.0)).a * 0.12;
    mask += texture(silhouette, UV + vec2(0.0, blur.y)).a * 0.12;
    mask += texture(silhouette, UV - vec2(0.0, blur.y)).a * 0.12;
    mask += texture(silhouette, UV + blur).a * 0.08;
    mask += texture(silhouette, UV - blur).a * 0.08;
    mask += texture(silhouette, UV + vec2(blur.x, -blur.y)).a * 0.08;
    mask += texture(silhouette, UV + vec2(-blur.x, blur.y)).a * 0.08;
    ALBEDO = vec3(0.008, 0.006, 0.005);
    ALPHA = mask * mix(0.52, 0.86, UV.y);
}
"""


static func available() -> bool:
    return ResourceLoader.exists(MODEL_PATH, "PackedScene")


static func install(floor_mesh: MeshInstance3D) -> Node3D:
    if not available():
        return null
    var packed := ResourceLoader.load(MODEL_PATH, "PackedScene") as PackedScene
    if packed == null:
        return null
    var figure := packed.instantiate() as Node3D
    if figure == null:
        return null

    var root := Node3D.new()
    root.name = "AnomalyHorrorMark"
    floor_mesh.add_child(root)
    var capture := SubViewport.new()
    capture.name = "SilhouetteCapture"
    capture.size = Vector2i(512, 768)
    capture.own_world_3d = true
    capture.transparent_bg = true
    capture.msaa_3d = Viewport.MSAA_4X
    capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
    root.add_child(capture)
    var stage := Node3D.new()
    capture.add_child(stage)
    figure.name = "ShadowPose"
    figure.scale = Vector3(2.32, 1.16, 2.38)
    stage.add_child(figure)

    # Use the same source idle pose and proportions as the intro NPC,
    # rather than relying on the misleading skinned bind-pose mesh AABB.
    var posed := false
    for item in figure.find_children("*", "AnimationPlayer", true, false):
        var animator := item as AnimationPlayer
        for clip in animator.get_animation_list():
            if str(clip).to_lower().contains("idle"):
                animator.play(clip)
                animator.advance(0.0)
                animator.seek(0.35, true)
                animator.pause()
                posed = true
                break
        if posed:
            break
    var center := Vector3(0.0, 0.9, -0.5)
    var view_size := 2.45
    for item in figure.find_children("*", "Skeleton3D", true, false):
        var skeleton := item as Skeleton3D
        var head_index := skeleton.find_bone("Head_06")
        var left_index := skeleton.find_bone("Foot_L_065")
        var right_index := skeleton.find_bone("Foot_R_069")
        if head_index < 0 or left_index < 0 or right_index < 0:
            continue
        skeleton.force_update_all_bone_transforms()
        var head := stage.to_local(skeleton.to_global(skeleton.get_bone_global_pose(head_index).origin))
        var left := stage.to_local(skeleton.to_global(skeleton.get_bone_global_pose(left_index).origin))
        var right := stage.to_local(skeleton.to_global(skeleton.get_bone_global_pose(right_index).origin))
        var feet := (left + right) * 0.5
        center = (head + feet) * 0.5 + Vector3(0, 0.08, 0)
        view_size = maxf(2.25, (head.y - feet.y) * 1.35)
        break

    var mask_material := StandardMaterial3D.new()
    mask_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mask_material.albedo_color = Color.WHITE
    mask_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    var mesh_count := 0
    for item in figure.find_children("*", "MeshInstance3D", true, false):
        var mesh := item as MeshInstance3D
        if mesh.mesh == null:
            continue
        mesh.material_override = mask_material
        mesh_count += 1
    if not posed or mesh_count == 0:
        root.free()
        return null

    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = view_size
    stage.add_child(camera)
    camera.position = center + Vector3(1.25, 0.24, 4.0)
    camera.look_at(center, Vector3.UP)
    camera.make_current()

    var projection := MeshInstance3D.new()
    projection.name = "ShadowProjection"
    var plane := PlaneMesh.new()
    plane.size = Vector2(2.1, 4.6)
    projection.mesh = plane
    projection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var shader := Shader.new()
    shader.code = PROJECTOR
    var material := ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("silhouette", capture.get_texture())
    projection.material_override = material
    root.add_child(projection)
    var bounds := floor_mesh.get_aabb()
    var midpoint := bounds.get_center()
    projection.position = Vector3(midpoint.x, bounds.end.y + 0.006, midpoint.z)
    projection.rotation.y = deg_to_rad(-7.0)
    capture.render_target_update_mode = SubViewport.UPDATE_ONCE
    return root
