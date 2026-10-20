shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
void fragment() {
 vec2 size = vec2(textureSize(screen_texture,0));
 vec2 point = (SCREEN_UV-vec2(0.5))*size;
 float radius = size.y*0.215;
 float outside = smoothstep(radius-3.0,radius+8.0,length(point));
 vec4 sharp = textureLod(screen_texture,SCREEN_UV,0.0);
 vec4 blurred = textureLod(screen_texture,SCREEN_UV,2.0);
 vec3 color = mix(sharp.rgb,blurred.rgb,outside*strength*0.65);
 float ring = 1.0-smoothstep(0.8,2.1,abs(length(point)-radius));
 color = mix(color,vec3(1.0),ring*strength*0.8);
 COLOR = vec4(color,1.0);
}
