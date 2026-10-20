shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec4 pool_color : source_color = vec4(0.18, 0.76, 0.88, 0.88);
uniform vec4 deep_pool_color : source_color = vec4(0.06, 0.44, 0.72, 0.95);
uniform vec4 foam_color : source_color = vec4(0.96, 0.98, 1.0, 0.92);

uniform vec2 impact_center = vec2(0.5, 0.5);
uniform float ripple_speed : hint_range(0.5, 6.0) = 2.2;
uniform float ripple_frequency : hint_range(5.0, 50.0) = 24.0;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
	float d = distance(UV, impact_center);
	float wave = sin(d * ripple_frequency - TIME * ripple_speed) * exp(-d * 3.5);
	VERTEX.y += wave * 0.035;
	NORMAL = normalize(vec3(
		-cos(d * ripple_frequency - TIME * ripple_speed) * (UV.x - impact_center.x) * 0.4,
		1.0,
		-cos(d * ripple_frequency - TIME * ripple_speed) * (UV.y - impact_center.y) * 0.4
	));
}

void fragment() {
	float d = distance(v_uv, impact_center);
	
	// Expanding concentric foam rings
	float ring = sin(d * ripple_frequency - TIME * ripple_speed);
	float ring_foam = smoothstep(0.65, 0.95, ring) * exp(-d * 2.8);
	
	// Impact splash foam right at center
	float impact_foam = smoothstep(0.18, 0.0, d) * 0.75;
	float total_foam = clamp(ring_foam + impact_foam, 0.0, 1.0);
	
	vec3 base_col = mix(pool_color.rgb, deep_pool_color.rgb, smoothstep(0.1, 0.8, d));
	vec3 final_col = mix(base_col, foam_color.rgb, total_foam);
	
	ALBEDO = final_col;
	ROUGHNESS = 0.10;
	SPECULAR = 0.90;
	ALPHA = mix(pool_color.a, 0.98, total_foam);
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float half_lambert = NdotL * 0.5 + 0.5;
	float diff = smoothstep(0.28, 0.72, half_lambert);
	DIFFUSE_LIGHT += LIGHT_COLOR * mix(ALBEDO * 0.82, ALBEDO * 1.15, diff) * ATTENUATION;
	
	vec3 H = normalize(LIGHT + VIEW);
	float NdotH = max(dot(NORMAL, H), 0.0);
	SPECULAR_LIGHT += LIGHT_COLOR * pow(NdotH, 64.0) * 0.85 * ATTENUATION;
}
