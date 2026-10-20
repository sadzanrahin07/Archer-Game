shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform vec4 shallow_color : source_color = vec4(0.20, 0.75, 0.85, 0.92);
uniform vec4 deep_color : source_color = vec4(0.06, 0.35, 0.65, 0.98);
uniform vec4 foam_color : source_color = vec4(0.96, 0.98, 1.0, 1.0);

// Lake center and radii for geometric depth and shoreline mapping
uniform vec2 lake_center = vec2(0.0, -34.0);
uniform vec2 lake_radii = vec2(36.5, 25.5);

// Animated wave parameters
uniform float wave_speed : hint_range(0.1, 5.0) = 1.2;
uniform float wave_height : hint_range(0.0, 0.5) = 0.04;
uniform float wave_frequency : hint_range(0.1, 2.0) = 0.45;

uniform float roughness : hint_range(0.0, 1.0) = 0.08;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.85;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Gentle rhythmic bobbing waves
	vec2 p = v_world_pos.xz * wave_frequency;
	float w1 = sin(p.x * 1.2 + p.y * 0.8 + TIME * wave_speed);
	float w2 = cos(p.x * 0.7 - p.y * 1.3 + TIME * (wave_speed * 1.2));
	float wave_offset = (w1 + w2) * 0.5 * wave_height;
	VERTEX.y += wave_offset;
	
	// Perturb normals for glistening specular water highlights
	NORMAL = normalize(vec3(
		-cos(p.x * 1.2 + TIME * wave_speed) * 0.15,
		1.0,
		-sin(p.y * 0.8 + TIME * wave_speed) * 0.15
	));
}

void fragment() {
	// Normalized distance from lake center (0.0 at center, 1.0 at shore)
	vec2 diff = v_world_pos.xz - lake_center;
	float norm_dist = sqrt(pow(diff.x / lake_radii.x, 2.0) + pow(diff.y / lake_radii.y, 2.0));
	
	// Water depth gradient: deep sapphire at center to bright turquoise near shore
	float depth_t = clamp(norm_dist, 0.0, 1.0);
	vec4 water_col = mix(deep_color, shallow_color, depth_t);
	
	// Stylized animated caustic light bands
	vec2 c_pos = v_world_pos.xz * 0.6;
	float c1 = sin(c_pos.x * 1.5 + c_pos.y * 0.8 + TIME * (wave_speed * 0.8));
	float c2 = cos(-c_pos.x * 0.9 + c_pos.y * 1.6 + TIME * wave_speed);
	float caustic = pow(clamp((c1 + c2) * 0.5 + 0.35, 0.0, 1.0), 3.0) * 0.22;
	water_col.rgb += vec3(caustic * 0.8, caustic * 1.0, caustic * 1.1);
	
	// Rhythmic shoreline foam lapping at the beach edge (d >= 0.92)
	float shore_wave = sin(TIME * (wave_speed * 1.4) + atan(diff.y, diff.x) * 6.0) * 0.025;
	float foam_edge = 0.93 + shore_wave;
	float foam = smoothstep(foam_edge, foam_edge + 0.045, norm_dist);
	
	// Blend crisp shoreline foam
	water_col = mix(water_col, foam_color, foam * 0.95);
	
	// Subtle Fresnel reflection on water rim
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	water_col.rgb += vec3(0.2, 0.4, 0.5) * fresnel * 0.4;
	
	ALBEDO = water_col.rgb;
	ALPHA = water_col.a;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
}
