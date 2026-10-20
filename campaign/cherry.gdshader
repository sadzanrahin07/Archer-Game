shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaves_texture : source_color,filter_linear_mipmap;
void fragment(){
 vec4 leaf=texture(leaves_texture,UV);
 ALBEDO=vec3(1.0,0.53,0.72)*(0.72+leaf.g*0.35);
 ALPHA=leaf.a;
 ALPHA_SCISSOR_THRESHOLD=0.45;
 ROUGHNESS=1.0;
}
