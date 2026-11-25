shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D other_view : filter_linear, repeat_disable;
uniform bool view_ready = false;

void fragment() {
    // The second camera has the exact pose/projection of the player, in
    // the isolated world. Screen-space lookup preserves true parallax
    // even when viewing the opening from an acute angle or up close.
    ALBEDO = view_ready ? texture(other_view, SCREEN_UV).rgb : vec3(0.008,0.011,0.015);
}
