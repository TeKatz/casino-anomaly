shader_type spatial;
render_mode cull_back;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 jacket : source_color = vec4(0.25,0.29,0.36,1.0);
uniform float fabric_grain = 0.025;
void fragment() {
    vec3 texel = texture(atlas, UV).rgb;
    float detail = dot(texel, vec3(0.24,0.66,0.10));
    float threads = (sin(UV.x * 920.0) * sin(UV.y * 840.0)) * fabric_grain;
    ALBEDO = jacket.rgb * (0.65 + 0.85 * detail + threads);
    ROUGHNESS = 0.82;
    METALLIC = 0.025;
    SPECULAR = 0.3;
}
