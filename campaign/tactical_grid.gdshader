shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.043, 0.063, 0.090, 0.96);
uniform vec4 line_color : source_color = vec4(0.15, 0.28, 0.40, 0.25);
uniform float grid_size = 44.0;
uniform float line_width = 1.0;

void fragment() {
	vec2 coord = FRAGCOORD.xy;
	vec2 grid = mod(coord, vec2(grid_size));
	float is_line = step(grid.x, line_width) + step(grid.y, line_width);
	COLOR = mix(bg_color, line_color, clamp(is_line, 0.0, 1.0));
}
