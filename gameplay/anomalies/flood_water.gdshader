shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D scene_color : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec2 origin = vec2(3.25, 8.0);
uniform vec2 bend = vec2(-6.0, -0.08);
uniform float front_distance = 1.5;
uniform float water_height = 0.023;
uniform float clock = 0.0;
uniform float motion = 1.0;
uniform int reflection_steps = 16;
uniform vec4 ripples[8];
varying vec2 room_xz;

float path_distance(vec2 p) {
    if (p.x < bend.x) {
        float cross_z = mix(origin.y, p.y, (bend.x-origin.x)/(p.x-origin.x));
        if (cross_z > bend.y) {
            return length(origin-bend)+length(p-bend);
        }
    }
    return length(p-origin);
}
float irregularity(vec2 p) {
    return sin(p.x*0.71+p.y*0.46)*0.37+sin(p.x*1.7-p.y*1.31)*0.18+sin(p.x*3.8+p.y*2.4)*0.065;
}
vec3 view_position(vec2 uv, float depth, mat4 inverse_projection) {
    vec4 v = inverse_projection * vec4(uv*2.0-1.0,depth,1.0);
    return v.xyz/v.w;
}
float geometry_depth(vec2 uv, mat4 inverse_projection) {
    return -view_position(uv,textureLod(scene_depth,uv,0.0).r,inverse_projection).z;
}
bool on_screen(vec2 uv) {
    return all(greaterThan(uv,vec2(0.002))) && all(lessThan(uv,vec2(0.998)));
}
vec2 wave_gradient(vec2 p) {
    float t = clock*motion;
    vec2 d1 = normalize(vec2(0.85,0.44));
    vec2 d2 = normalize(vec2(-0.42,0.91));
    vec2 d3 = normalize(vec2(0.71,-0.72));
    vec2 g = d1*cos(dot(p,d1)*8.7+t*1.85)*0.046;
    g += d2*cos(dot(p,d2)*15.2-t*2.35)*0.028;
    g += d3*cos(dot(p,d3)*30.0+t*3.10)*0.016;
    for (int i=0; i<8; i++) {
        vec4 r = ripples[i];
        float age = clock-r.z;
        if (age >= 0.0 && age < 3.5 && r.w>0.0 && motion>0.0) {
            vec2 offset = p-r.xy;
            float dist = length(offset);
            float shell = dist-age*1.65;
            if (abs(shell)<0.9 && dist>0.025) {
                float weight = exp(-shell*shell*9.0)*exp(-age*1.25);
                g += normalize(offset)*cos(shell*26.0)*weight*r.w*motion;
            }
        }
    }
    return g;
}
vec4 screen_reflection(vec3 start, vec3 direction, mat4 projection, mat4 inverse_projection) {
    if (reflection_steps <= 0) { return vec4(0.0); }
    float previous = 0.05;
    float distance_along = 0.10;
    for (int i=0; i<28; i++) {
        if (i>=reflection_steps) { break; }
        vec3 ray = start+direction*distance_along;
        if (ray.z>=-0.075) { break; }
        vec4 clip = projection*vec4(ray,1.0);
        vec2 uv = clip.xy/clip.w*0.5+0.5;
        if (!on_screen(uv)) { break; }
        float gap = -ray.z-geometry_depth(uv,inverse_projection);
        if (gap>=0.0 && gap<max(0.32,distance_along*0.19)) {
            float low=previous;
            float high=distance_along;
            for (int j=0; j<4; j++) {
                float middle=(low+high)*0.5;
                vec3 test_ray=start+direction*middle;
                vec4 test_clip=projection*vec4(test_ray,1.0);
                vec2 test_uv=test_clip.xy/test_clip.w*0.5+0.5;
                if (-test_ray.z>geometry_depth(test_uv,inverse_projection)) { high=middle; }
                else { low=middle; }
            }
            vec3 hit=start+direction*high;
            vec4 hit_clip=projection*vec4(hit,1.0);
            vec2 hit_uv=hit_clip.xy/hit_clip.w*0.5+0.5;
            float edge=min(min(hit_uv.x,1.0-hit_uv.x),min(hit_uv.y,1.0-hit_uv.y));
            float confidence=smoothstep(0.0,0.095,edge)*(1.0-smoothstep(11.0,23.0,high));
            return vec4(textureLod(scene_color,hit_uv,0.75).rgb,confidence);
        }
        previous=distance_along;
        distance_along+=max(0.12,distance_along*0.24);
    }
    return vec4(0.0);
}
void vertex() {
    room_xz = VERTEX.xz;
}
void fragment() {
    float edge = front_distance-path_distance(room_xz)+irregularity(room_xz);
    if (edge < -0.18) { discard; }
    float covered = smoothstep(-0.18,0.26,edge);
    vec2 gradient = wave_gradient(room_xz);
    vec3 normal_local = normalize(vec3(-gradient.x,1.0,-gradient.y));
    vec3 water_normal = normalize(mat3(VIEW_MATRIX*MODEL_MATRIX)*normal_local);
    vec3 view_ray = normalize(VERTEX);
    float facing = clamp(dot(-view_ray,water_normal),0.0,1.0);
    float fresnel = 0.025+0.84*pow(1.0-facing,4.5);
    float depth_here=geometry_depth(SCREEN_UV,INV_PROJECTION_MATRIX);
    float optical_depth=max(0.0,depth_here+VERTEX.z);
    float thickness=min(optical_depth*max(facing,0.10),water_height*1.8);
    vec3 flat_normal=normalize(mat3(VIEW_MATRIX*MODEL_MATRIX)*vec3(0.0,1.0,0.0));
    vec2 distortion=(water_normal-flat_normal).xy*min(0.052,0.015+thickness*0.22);
    vec2 refracted_uv=clamp(SCREEN_UV+distortion,vec2(0.002),vec2(0.998));
    if (geometry_depth(refracted_uv,INV_PROJECTION_MATRIX)<-VERTEX.z-0.025) { refracted_uv=SCREEN_UV; }
    vec3 floor_color=textureLod(scene_color,refracted_uv,0.10+thickness*2.0).rgb;
    vec3 transmission=exp(-vec3(2.8,1.45,1.15)*thickness);
    vec3 tint=vec3(0.020,0.041,0.037);
    vec3 through=floor_color*transmission+tint*(1.0-transmission);
    vec4 hit=vec4(0.0);
    if (fresnel>0.055 && reflection_steps>0) {
        hit=screen_reflection(VERTEX+water_normal*0.055,reflect(view_ray,water_normal),PROJECTION_MATRIX,INV_PROJECTION_MATRIX);
    }
    vec3 reflection=mix(vec3(0.075,0.081,0.069),hit.rgb,hit.a);
    vec3 color=mix(through,reflection,fresnel);
    float shoreline=(1.0-smoothstep(0.04,0.28,abs(edge)))*covered;
    float lacing=0.5+0.5*sin(room_xz.x*12.0+sin(room_xz.y*8.1)*2.7-clock*motion*0.6);
    color+=vec3(0.17,0.19,0.16)*shoreline*lacing*0.23;
    // Narrow menisci around submerged furniture, never an opaque foam sheet.
    float contact=(1.0-smoothstep(0.008,0.045,optical_depth))*smoothstep(0.001,0.008,optical_depth);
    color+=vec3(0.10,0.12,0.11)*contact*0.22;
    ALBEDO=color;
    ALPHA=covered*0.96;
}
