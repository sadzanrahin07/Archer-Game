shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float clock = 0.0;
uniform float flow = 1.0;
uniform float strength = 1.0;
varying vec4 energy_color;
void vertex() { energy_color = COLOR; }
void fragment() {
 float stream = 0.80 + 0.20 * sin(UV.x * 32.0 - clock * 22.0 * flow + sin(UV.y * 18.0 + clock * 5.0));
 ALBEDO = energy_color.rgb;
 EMISSION = energy_color.rgb * 0.15;
 float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.35);
 ALPHA = energy_color.a * stream * strength * edge;
}
