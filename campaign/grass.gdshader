shader_type spatial;
render_mode cull_disabled;
uniform vec4 blade_color : source_color = vec4(0.24,0.59,0.31,1.0);
void vertex() {
 vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 float bend = pow(max(VERTEX.y,0.0),2.0);
 VERTEX.x += sin(TIME*1.45 + world.x*0.7 + world.z*0.25)*bend*0.27;
 VERTEX.z += cos(TIME*1.1 + world.z*0.6)*bend*0.15;
}
void fragment() {
 ALBEDO = blade_color.rgb * mix(0.70,1.2,UV.y);
 ROUGHNESS = 1.0;
}
