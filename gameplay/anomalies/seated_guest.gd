extends RefCounted
## Reuse the licensed character's actual seated animation (no procedural
## humanoid proxy or interaction/collision nodes).
const MODEL := "res://models/croupier/scene.gltf"


static func available() -> bool:
    return ResourceLoader.exists(MODEL, "PackedScene")


static func install(sofa: Node3D, parent: Node3D) -> Node3D:
    var packed := ResourceLoader.load(MODEL, "PackedScene") as PackedScene
    if packed == null:
        return null
    var figure := packed.instantiate() as Node3D
    if figure == null:
        return null
    figure.name = "SeatedGuest"
    figure.scale = Vector3(1.88, 1.12, 1.84)
    parent.add_child(figure)
    var posed := false
    for item in figure.find_children("*", "AnimationPlayer", true, false):
        var animator := item as AnimationPlayer
        for clip in animator.get_animation_list():
            if str(clip).to_lower().contains("sitting_idle"):
                animator.play(clip)
                animator.advance(0.0)
                animator.seek(0.4, true)
                animator.pause()
                posed = true
                break
        if posed:
            break
    if not posed:
        figure.free()
        return null
    var seat: MeshInstance3D
    for item in sofa.find_children("*", "MeshInstance3D", true, false):
        if str(item.name).to_lower().contains("seat"):
            seat = item as MeshInstance3D
            break
    if seat == null:
        figure.free()
        return null
    var seat_box: AABB = (sofa.global_transform.affine_inverse() * seat.global_transform) * seat.get_aabb()
    var hip := Vector3.ZERO
    var found_hip := false
    var head_y := 0.0
    for item in figure.find_children("*", "Skeleton3D", true, false):
        var skeleton := item as Skeleton3D
        var idx := skeleton.find_bone("Hips_01")
        if idx < 0:
            continue
        skeleton.force_update_all_bone_transforms()
        hip = parent.to_local(skeleton.to_global(skeleton.get_bone_global_pose(idx).origin))
        var head_index := skeleton.find_bone("Head_06")
        if head_index >= 0:
            head_y = skeleton.to_global(skeleton.get_bone_global_pose(head_index).origin).y
        found_hip = true
        break
    if not found_hip:
        figure.free()
        return null
    # Sofa and seated model both face +Z in their own coordinates.
    # Align the animated pelvis slightly above the actual cushion.
    var anchor := sofa.to_global(Vector3(seat_box.get_center().x + 0.08, seat_box.end.y + 0.10, seat_box.get_center().z - 0.10))
    var adjustment := parent.to_local(anchor) - hip
    figure.position += adjustment
    head_y += (parent.global_basis * adjustment).y
    var mask_shader := Shader.new()
    mask_shader.code = """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform float cutoff = 1.0;
varying float height_world;
void vertex() { height_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).y; }
void fragment() {
    if (height_world < cutoff) { discard; }
    ALBEDO = vec3(0.002,0.002,0.003);
}
"""
    var face_mask := ShaderMaterial.new()
    face_mask.shader = mask_shader
    face_mask.set_shader_parameter("cutoff", head_y - 0.13)
    face_mask.render_priority = 2
    for item in figure.find_children("*", "MeshInstance3D", true, false):
        var mesh := item as MeshInstance3D
        if mesh.mesh == null:
            continue
        mesh.material_overlay = face_mask
        # Preserve source suit and skin textures but damp diffuse response
        # so the face stays in shadow rather than looking like the intro NPC.
        for surface in range(mesh.mesh.get_surface_count()):
            var original := mesh.get_active_material(surface) as StandardMaterial3D
            if original != null:
                var dark := original.duplicate() as StandardMaterial3D
                dark.albedo_color *= Color(0.36, 0.36, 0.39, 1.0)
                dark.metallic = 0.0
                dark.metallic_texture = null
                dark.roughness = 0.85
                dark.roughness_texture = null
                dark.metallic_specular = 0.15
                dark.normal_scale = minf(dark.normal_scale, 0.65)
                dark.emission_enabled = false
                mesh.set_surface_override_material(surface, dark)
    return figure
