shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 tone : source_color = vec4(0.6,1.0,0.8,1.0);
uniform float strength : hint_range(0.0,1.0) = 0.0;
void fragment() {
 float rim=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),1.6);
 ALBEDO=tone.rgb;
 ALPHA=strength*(0.12+0.88*rim);
}
