shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0,1.0) = 0.0;
uniform float magnification : hint_range(1.0,1.4) = 1.12;
void fragment() {
 vec2 size = vec2(textureSize(screen_texture,0));
 vec2 point = (SCREEN_UV-vec2(0.5))*size;
 float radius = min(size.y*0.215,size.x*0.43);
 float distance_to_center = length(point);
 float inside = 1.0-smoothstep(radius-2.0,radius+2.0,distance_to_center);
 vec3 original = textureLod(screen_texture,SCREEN_UV,0.0).rgb;
 vec2 lens_uv = vec2(0.5)+(SCREEN_UV-vec2(0.5))/mix(1.0,magnification,strength);
 vec3 lens = textureLod(screen_texture,lens_uv,0.0).rgb;
 vec3 outside = mix(original,textureLod(screen_texture,SCREEN_UV,1.6).rgb,0.38)*0.96;
 vec3 focused = mix(outside,lens,inside);
 vec3 color = mix(original,focused,strength);
 float ring = 1.0-smoothstep(0.8,2.2,abs(distance_to_center-radius));
 color = mix(color,vec3(0.93,0.99,1.0),ring*strength*0.82);
 COLOR = vec4(color,1.0);
}
