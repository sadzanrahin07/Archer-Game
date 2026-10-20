shader_type spatial;
render_mode cull_front, unshaded;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 outline_color : source_color = vec4(0.12, 0.10, 0.14, 1.0);
uniform float outline_width : hint_range(0.0, 0.02) = 0.004;
uniform bool use_alpha_scissor = false;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	if (use_alpha_scissor) {
		vec4 tex_col = texture(albedo_texture, UV);
		if (tex_col.a < alpha_scissor_threshold) {
			discard;
		}
	}
	ALBEDO = outline_color.rgb;
}
