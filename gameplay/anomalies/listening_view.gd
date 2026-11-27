extends CanvasLayer
## Screen-space effect below HUD and pause menu; never consumes input.
const EFFECT := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity = 0.0;
uniform float blur_amount = 1.0;
void fragment() {
    vec2 p = SCREEN_UV - vec2(0.5);
    float blur = intensity * 1.65 * blur_amount;
    vec3 original = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
    vec3 soft = textureLod(screen_texture, SCREEN_UV, blur).rgb;
    float gray = dot(soft, vec3(0.299, 0.587, 0.114));
    soft = mix(soft, vec3(gray), intensity * 0.22);
    float vignette = smoothstep(0.22, 0.72, length(p * vec2(1.0, 0.85)));
    COLOR = vec4(mix(original, soft * (1.0 - vignette * intensity * 0.40), intensity), 1.0);
}
"""
var surface: ColorRect
var effect: ShaderMaterial


func _ready() -> void:
    layer = 12
    surface = ColorRect.new()
    surface.name = "AnomalyListeningOverlay"
    surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(surface)
    surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shader := Shader.new()
    shader.code = EFFECT
    effect = ShaderMaterial.new()
    effect.shader = shader
    surface.material = effect
    surface.hide()


func set_intensity(value: float, reduced: bool) -> void:
    if surface == null:
        return
    surface.visible = value > 0.005
    effect.set_shader_parameter("intensity", clampf(value,0.0,1.0))
    effect.set_shader_parameter("blur_amount", 0.0 if reduced else 1.0)
