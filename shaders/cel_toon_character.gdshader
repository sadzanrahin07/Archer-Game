shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 shadow_color : source_color = vec4(0.55, 0.52, 0.65, 1.0);
uniform bool use_alpha_scissor = false;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float brightness_multiplier : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 tex_col = texture(albedo_texture, UV);
	if (use_alpha_scissor && tex_col.a < alpha_scissor_threshold) {
		discard;
	}
	ALBEDO = tex_col.rgb * brightness_multiplier;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	// Stepped light cut-off for anime cel look
	float NdotL = dot(NORMAL, LIGHT);
	float light_intensity = smoothstep(0.0, 0.05, NdotL);
	DIFFUSE_LIGHT += mix(shadow_color.rgb, vec3(1.0), light_intensity) * LIGHT_COLOR * ATTENUATION;
}
