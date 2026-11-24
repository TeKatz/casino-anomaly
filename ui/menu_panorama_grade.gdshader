shader_type canvas_item;
render_mode unshaded;

void fragment() {
    vec2 p = UV;
    float left = 1.0 - smoothstep(0.08, 0.58, p.x);
    float edge = smoothstep(0.35, 0.72, length((p - vec2(0.5)) * vec2(1.0, 0.85)));
    float darkness = 0.10 + left * 0.38 + edge * 0.15;
    COLOR = vec4(vec3(0.018, 0.024, 0.033), darkness) * COLOR;
}
