shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D other_view : filter_linear, repeat_disable;
uniform bool view_ready = false;

// The non-HDR SubViewport supplies display-encoded color. Spatial ALBEDO
// in Forward+ expects linear light. Decode explicitly to avoid the washed
// out second gamma pass on the aperture.
vec3 srgb_to_linear(vec3 color) {
    return mix(color/12.92, pow((color+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),color));
}

void fragment() {
    vec3 sampled = texture(other_view, SCREEN_UV).rgb;
    ALBEDO = view_ready ? (OUTPUT_IS_SRGB ? sampled : srgb_to_linear(sampled)) : vec3(0.008,0.011,0.015);
}
