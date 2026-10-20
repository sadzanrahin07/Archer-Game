shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec4 plume_color : source_color = vec4(0.68, 0.68, 0.62, 1.0);
uniform vec4 stem_color : source_color = vec4(0.38, 0.52, 0.24, 1.0);

uniform float wind_speed : hint_range(0.5, 6.0) = 2.0;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.16;

varying vec3 v_world_pos;
varying float v_height;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y / 2.2, 0.0, 1.0);
	v_height = h;
	float sway = h * h;
	
	// Gentle organic sway in the breeze
	float wave1 = sin(TIME * wind_speed + v_world_pos.x * 0.4 + v_world_pos.z * 0.3) * 0.7;
	float wave2 = cos(TIME * (wind_speed * 1.3) + v_world_pos.z * 0.5) * 0.3;
	float total_wave = wave1 + wave2;
	
	VERTEX.x += total_wave * wind_strength * sway;
	VERTEX.z += (wave1 * 0.5) * wind_strength * sway;
	
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 0.7, 0.3), 0.50));
}

void fragment() {
	// Gradient from green stem to soft feathery silver/cream plume
	float plume_mask = smoothstep(0.35, 0.75, v_height);
	vec3 col = mix(stem_color.rgb, plume_color.rgb, plume_mask);
	
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.0;
	BACKLIGHT = col * 0.12;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float half_lambert = clamp(NdotL * 0.5 + 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ALBEDO * half_lambert * ATTENUATION;
}
