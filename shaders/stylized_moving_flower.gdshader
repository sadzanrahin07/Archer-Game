shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_custom_color = false;

// Wind animation parameters
uniform float wind_speed : hint_range(0.1, 10.0) = 2.0;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.16;
uniform float wind_scale : hint_range(0.01, 1.0) = 0.15;
uniform vec2 wind_direction = vec2(1.0, 0.35);

// Progressive Detail Reveal & Player Interaction
global uniform vec3 player_pos;
uniform float player_radius : hint_range(0.4, 3.0) = 1.35;
uniform float player_push_strength : hint_range(0.0, 2.0) = 0.70;

varying vec3 v_world_pos;
varying float v_height;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y / 1.0, 0.0, 1.0);
	v_height = h;
	float sway = h * h;

	// Gentle, organic anime wind waves
	vec2 w_dir = normalize(wind_direction);
	float wave1 = sin(TIME * wind_speed + (v_world_pos.x * w_dir.x + v_world_pos.z * w_dir.y) * wind_scale);
	float wave2 = cos(TIME * (wind_speed * 1.3) + v_world_pos.x * 0.25 - v_world_pos.z * 0.2) * 0.35;
	float total_wave = wave1 + wave2;
	
	VERTEX.x += w_dir.x * total_wave * wind_strength * sway;
	VERTEX.z += w_dir.y * total_wave * wind_strength * sway;
	VERTEX.y -= abs(total_wave) * (wind_strength * 0.2) * sway;

	// Interactive Player Trampling
	if (length(player_pos) > 0.1) {
		vec3 diff = v_world_pos - player_pos;
		float dist_xz = length(vec2(diff.x, diff.z));
		if (dist_xz < player_radius && abs(diff.y) < 2.0) {
			float push_factor = (1.0 - (dist_xz / player_radius)) * sway;
			vec2 push_dir = normalize(vec2(diff.x, diff.z) + vec2(0.0001, 0.0001));
			VERTEX.x += push_dir.x * push_factor * player_push_strength;
			VERTEX.z += push_dir.y * push_factor * player_push_strength;
			VERTEX.y -= push_factor * (player_push_strength * 0.40);
		}
	}

	// Smooth upward normals for gentle petals
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.78));
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	if (tex.a < 0.2) {
		discard;
	}

	if (use_custom_color) {
		ALBEDO = color_tint.rgb;
	} else {
		ALBEDO = tex.rgb * color_tint.rgb;
	}
	ROUGHNESS = 0.90;
	SPECULAR = 0.0;
	BACKLIGHT = ALBEDO * 0.30;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float half_lambert = NdotL * 0.5 + 0.5;
	float toon = smoothstep(0.28, 0.70, half_lambert);
	vec3 lit_color = mix(ALBEDO * 0.75, ALBEDO * 1.12, toon);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit_color * ATTENUATION;
}
