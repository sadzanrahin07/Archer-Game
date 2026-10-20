shader_type spatial;
render_mode cull_disabled;
uniform vec4 field_color : source_color = vec4(0.5,0.86,0.38,1.0);
uniform vec4 path_color : source_color = vec4(0.68,0.70,0.41,1.0);
uniform float winding = 1.8;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float path_x=sin(world.z*.058)*winding;
 float trail=1.0-smoothstep(.85,2.0,abs(world.x-path_x));
 float fleck=sin(world.x*.4+cos(world.z*.19))*sin(world.z*.32)*.035;
 ALBEDO=mix(field_color.rgb, path_color.rgb,trail*.43)+fleck;
 ROUGHNESS=1.0;SPECULAR=0.0;
}
