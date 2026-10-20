shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture,filter_linear_mipmap;
void fragment(){
 vec4 tint=COLOR;
 vec3 blurred=textureLod(screen_texture,SCREEN_UV,3.0).rgb;
 float border=smoothstep(0.4,0.7,max(tint.r,max(tint.g,tint.b)));
 vec3 frost=mix(blurred,vec3(0.025,0.075,0.055),0.74);
 COLOR=vec4(mix(frost,tint.rgb,border),tint.a);
}
