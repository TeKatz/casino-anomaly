shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform float cutoff = 1.0;
varying float world_y;
void vertex() {
    world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
    if (world_y < cutoff) {
        discard;
    }
    ALBEDO = vec3(0.003, 0.004, 0.006);
}
