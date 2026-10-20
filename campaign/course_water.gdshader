shader_type spatial;
render_mode cull_disabled;
uniform vec4 water_color : source_color = vec4(0.11,0.67,0.79,1.0);
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=sin(TIME*1.1+world.z*.42)*.035;}
void fragment(){
 float wave=pow(max(0.0,sin(world.x*1.8+world.z*.52-TIME*1.2)),18.0);
 ALBEDO=water_color.rgb+vec3(.26,.3,.27)*wave;
 ROUGHNESS=.2;SPECULAR=.6;
}
