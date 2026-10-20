shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaves_texture : source_color,filter_linear_mipmap;
uniform vec4 foliage_color : source_color = vec4(0.92,0.53,0.24,1.0);
void fragment(){
 vec4 leaf=texture(leaves_texture,UV);
 ALBEDO=foliage_color.rgb*(0.70+leaf.g*0.35);
 ALPHA=leaf.a;ALPHA_SCISSOR_THRESHOLD=.45;
 ROUGHNESS=1.0;BACKLIGHT=foliage_color.rgb*.2;
}
