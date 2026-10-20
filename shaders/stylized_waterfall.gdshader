shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec4 water_color : source_color = vec4(0.20, 0.78, 0.92, 0.88);
uniform vec4 deep_water_color : source_color = vec4(0.08, 0.48, 0.78, 0.95);
uniform vec4 foam_color : source_color = vec4(0.96, 0.98, 1.0, 0.95);

uniform float flow_speed : hint_range(0.5, 8.0) = 3.4;
uniform float foam_scale : hint_range(1.0, 30.0) = 12.0;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.42;

varying vec3 v_world_pos;
varying vec2 v_uv;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_uv = UV;
	
	// Gentle organic undulating motion in the water curtain
	float wave = sin(VERTEX.y * 3.0 + TIME * flow_speed * 1.5) * cos(VERTEX.x * 2.5 + TIME * 2.0);
	VERTEX.z += wave * 0.04;
	
	// Smooth upward/outward normals for luminous water shading
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 0.4, 0.9), 0.5));
}

void fragment() {
	// Downward flowing coordinates
	vec2 flow_uv = vec2(v_uv.x * 3.0, v_uv.y * foam_scale - TIME * flow_speed);
	
	// Procedural animated foam streaks
	float n1 = sin(flow_uv.y * 1.8 + sin(flow_uv.x * 3.2)) * cos(flow_uv.x * 2.4);
	float n2 = sin(flow_uv.y * 3.6 - flow_uv.x * 1.8) * cos(flow_uv.y * 2.0);
	float streaks = smoothstep(1.0 - foam_amount, 1.0, n1 * 0.5 + n2 * 0.5 + 0.5);
	
	// Edge and crest foam
	float edge_foam = smoothstep(0.0, 0.15, v_uv.x) * smoothstep(1.0, 0.85, v_uv.x);
	float crest_foam = smoothstep(0.0, 0.12, v_uv.y);
	float bottom_foam = smoothstep(1.0, 0.82, v_uv.y);
	
	float combined_foam = clamp(streaks + (1.0 - edge_foam) * 0.7 + (1.0 - crest_foam) * 0.5 + (1.0 - bottom_foam) * 0.6, 0.0, 1.0);
	
	// Vertical depth gradient
	vec3 base_water = mix(water_color.rgb, deep_water_color.rgb, clamp(v_uv.y * 0.6, 0.0, 1.0));
	vec3 final_color = mix(base_water, foam_color.rgb, combined_foam);
	
	ALBEDO = final_color;
	ROUGHNESS = 0.12;
	SPECULAR = 0.85;
	ALPHA = mix(water_color.a, 0.96, combined_foam);
	BACKLIGHT = water_color.rgb * 0.45;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float half_lambert = NdotL * 0.5 + 0.5;
	float diff = smoothstep(0.25, 0.75, half_lambert);
	vec3 lit = mix(ALBEDO * 0.80, ALBEDO * 1.20, diff);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * ATTENUATION;
	
	// Glistening specular highlight
	vec3 H = normalize(LIGHT + VIEW);
	float NdotH = max(dot(NORMAL, H), 0.0);
	float spec = pow(NdotH, 48.0);
	SPECULAR_LIGHT += LIGHT_COLOR * spec * 0.75 * ATTENUATION;
}
