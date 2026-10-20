shader_type spatial;
render_mode blend_mix, cull_back;

// Harmonious anime / Ghibli-style terrain palette matching reference video
uniform vec4 grass_color_top : source_color = vec4(0.50, 0.86, 0.38, 1.0);
uniform vec4 grass_color_bottom : source_color = vec4(0.24, 0.60, 0.22, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.68, 0.52, 0.32, 1.0);
uniform vec4 sand_color : source_color = vec4(0.88, 0.82, 0.58, 1.0);
uniform vec4 mountain_rock_color : source_color = vec4(0.72, 0.64, 0.48, 1.0);
uniform vec4 cliff_rock_color : source_color = vec4(0.48, 0.52, 0.54, 1.0);

uniform float rock_slope_threshold : hint_range(0.1, 0.9) = 0.55;
uniform float rock_blend_smoothness : hint_range(0.01, 0.5) = 0.15;
uniform float water_height = 0.0;
uniform float sand_height_range = 0.55;
uniform float mountain_height_start = 9.0;
uniform float mountain_height_full = 22.0;

// Progressive Detail Reveal & Distance LOD
global uniform vec3 player_pos;
uniform float detail_distance : hint_range(1.0, 50.0) = 2.5;
uniform float detail_fade_range : hint_range(0.5, 15.0) = 1.5;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_vertex_color;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_vertex_color = COLOR;
}

void fragment() {
	// Progressive detail factor (1.0 = close full detail within 2.5m, 0.0 = simplified far land)
	vec3 ref_pos = player_pos;
	if (length(ref_pos) < 0.001) {
		ref_pos = CAMERA_POSITION_WORLD;
	}
	float dist_to_player = length(v_world_pos.xz - ref_pos.xz);
	float detail_factor = clamp((detail_distance - dist_to_player) / detail_fade_range, 0.0, 1.0);

	// Slope factor (1.0 = horizontal flat ground, 0.0 = sheer vertical wall)
	float slope = clamp(v_world_normal.y, 0.0, 1.0);
	float steep_factor = 1.0 - smoothstep(rock_slope_threshold - rock_blend_smoothness, rock_slope_threshold + rock_blend_smoothness, slope);
	
	// Height above water (shoreline sand)
	float height_above_water = v_world_pos.y - water_height;
	float sand_factor = 1.0 - smoothstep(0.0, sand_height_range, height_above_water);
	sand_factor = clamp(sand_factor, 0.0, 1.0);
	
	// Altitude factor for distant mountains
	float mountain_factor = smoothstep(mountain_height_start, mountain_height_full, v_world_pos.y);
	
	// 1. TOPOGRAPHIC HILL CONTOURING (from Jen Jell reference video)
	// Soft painterly bands flowing along hill elevation and slope contours
	float hill_contour1 = sin(v_world_pos.y * 1.35 + sin(v_world_pos.x * 0.07 + v_world_pos.z * 0.05) * 1.6);
	float hill_contour2 = cos(v_world_pos.x * 0.05 - v_world_pos.z * 0.04 + v_world_pos.y * 0.4);
	float hill_band = smoothstep(-0.35, 0.65, hill_contour1 * 0.6 + hill_contour2 * 0.4);
	
	// Warm sunlit ridge color vs lush base
	vec3 hill_ridge_color = mix(grass_color_top.rgb, vec3(0.60, 0.92, 0.44), 0.35);
	vec3 hill_base = mix(grass_color_bottom.rgb, hill_ridge_color, hill_band * 0.70 + 0.25);

	// 2. STYLIZED PAINTED GRASS MARKS ON THE GROUND
	// High-frequency stippling and painterly marks across the meadow and hills
	vec2 p_uv = v_world_pos.xz * 1.65;
	float g_mark1 = sin(p_uv.x * 2.8 + sin(p_uv.y * 1.5)) * cos(p_uv.y * 2.8);
	float g_mark2 = cos(p_uv.x * 4.8 - p_uv.y * 3.4) * sin(p_uv.y * 4.4);
	float g_marks = smoothstep(0.40, 0.82, g_mark1 * 0.55 + g_mark2 * 0.45);
	
	// Modulate grass marks: sharper near player, soft painterly impression in distance
	float mark_strength = mix(0.28, 0.42, detail_factor);
	vec3 meadow_with_marks = mix(hill_base, grass_color_top.rgb * 1.10, g_marks * mark_strength);

	// 3. NATURAL CLEARINGS & WARM SAGE/EARTH GLADES
	// Matching the noise clustering where 3D grass is cleared, revealing soft ground
	float clearing_noise = (sin(v_world_pos.x * 0.08 + 0.4) * cos(v_world_pos.z * 0.075 - 0.3)
	                      + sin(v_world_pos.x * 0.16 + v_world_pos.z * 0.12 + 1.2) * 0.6
	                      + cos((v_world_pos.x - 40.0) * 0.28 - (v_world_pos.z + 15.0) * 0.22) * 0.35) / 1.95;
	float clearing_factor = smoothstep(0.12, -0.28, clearing_noise);
	vec3 clearing_color = vec3(0.56, 0.76, 0.40);
	vec3 clearing_soil = mix(clearing_color, dirt_color.rgb * 0.82, 0.25);
	meadow_with_marks = mix(meadow_with_marks, clearing_soil, clearing_factor * 0.38);

	vec3 final_color = meadow_with_marks;
	
	// Blend dirt trail with soft painterly borders
	float dirt_mask = clamp(v_vertex_color.r, 0.0, 1.0);
	final_color = mix(final_color, dirt_color.rgb, dirt_mask * 0.92);
	
	// Coastal cove beach area (Image 2)
	// Extends warm beach sand into the cove opening
	vec2 cove_center = vec2(47.5, -15.0);
	vec2 cove_delta = (v_world_pos.xz - cove_center) * vec2(0.12, 0.14);
	float cove_dist = length(cove_delta);
	float cove_sand = smoothstep(1.15, 0.35, cove_dist);
	float total_sand = clamp(max(sand_factor, cove_sand), 0.0, 1.0);
	final_color = mix(final_color, sand_color.rgb, total_sand * (1.0 - steep_factor));
	
	// Blend mountain rock at high altitudes
	vec3 mountain_col = mix(mountain_rock_color.rgb, cliff_rock_color.rgb, steep_factor * 0.4);
	final_color = mix(final_color, mountain_col, mountain_factor * 0.95);
	
	// Steep cliff rock anywhere that is steep
	final_color = mix(final_color, cliff_rock_color.rgb, steep_factor * (1.0 - mountain_factor * 0.8));
	
	ALBEDO = final_color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.02;
}

// SMOOTH ANIME TOON LIGHTING:
// Soft half-lambert wrap creates velvety, painted rolling hills matching Jen Jell's video
void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float half_lambert = NdotL * 0.5 + 0.5;
	float toon = smoothstep(0.28, 0.72, half_lambert);
	vec3 lit_color = mix(ALBEDO * 0.75, ALBEDO * 1.10, toon);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit_color * ATTENUATION;
}
