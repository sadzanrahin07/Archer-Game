shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float wind_speed = 1.6;
uniform float wind_strength = 0.08;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.4;
uniform vec3 transmission_color : source_color = vec3(0.15, 0.2, 0.05);

void vertex() {
	// Upper vertices sway more
	float height_weight = clamp(VERTEX.y * 0.25, 0.0, 1.0);
	float wave = sin(TIME * wind_speed + (NODE_POSITION_WORLD.x + VERTEX.x) * 0.6) * 
	             cos(TIME * wind_speed * 0.7 + (NODE_POSITION_WORLD.z + VERTEX.z) * 0.6);
	VERTEX.x += wave * wind_strength * height_weight;
	VERTEX.z += wave * wind_strength * 0.7 * height_weight;
}

void fragment() {
	vec4 tex_color = texture(texture_albedo, UV);
	vec4 final_color = tex_color * color_tint;
	
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = 0.8;
	SPECULAR = 0.15;
	BACKLIGHT = transmission_color;
}
