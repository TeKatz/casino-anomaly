shader_type canvas_item;
render_mode unshaded;

void fragment() {
    vec2 uv = UV;
    vec2 p = (uv - vec2(0.5)) * vec2(1.8, 1.0);
    float t = TIME * 0.16;
    vec3 base = mix(vec3(0.018, 0.028, 0.045), vec3(0.045, 0.037, 0.063), uv.y);
    float d1 = length((p - vec2(-0.40 + sin(t * 0.53) * 0.055, 0.11)) * vec2(0.9, 1.25));
    float d2 = length((p - vec2(0.52, -0.14 + cos(t * 0.31) * 0.07)) * vec2(0.70, 1.0));
    base += vec3(0.20, 0.075, 0.17) * exp(-d1 * d1 * 5.0) * 0.55;
    base += vec3(0.07, 0.26, 0.29) * exp(-d2 * d2 * 6.0) * 0.33;
    float radius = length((p - vec2(-0.23, 0.06)) * vec2(0.9, 1.55));
    float orbit = exp(-pow((radius - (0.46 + 0.023 * sin(t))) * 83.0, 2.0));
    float orbit2 = exp(-pow((radius - 0.60) * 95.0, 2.0));
    float arc_mask = smoothstep(-0.85, -0.18, p.x) * (1.0 - smoothstep(0.19, 0.62, p.x));
    base += vec3(0.42, 0.27, 0.40) * orbit * arc_mask * 0.24;
    base += vec3(0.19, 0.37, 0.42) * orbit2 * arc_mask * 0.13;
    float thin = exp(-abs((p.y + 0.10) - 0.19 * sin(p.x * 2.5 + t * 0.6)) * 95.0);
    base += vec3(0.40, 0.22, 0.27) * thin * 0.045;
    float noise = fract(sin(dot(floor(uv * vec2(1024.0, 768.0)), vec2(12.9898, 78.233))) * 43758.5453);
    base += (noise - 0.5) * 0.009;
    float vignette = 1.0 - smoothstep(0.22, 1.20, length(p * vec2(0.83, 1.1)));
    COLOR = vec4(max(base * (0.65 + 0.35 * vignette), vec3(0.0)), 1.0);
}
