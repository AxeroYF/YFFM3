shader_type canvas_item;
uniform vec3 tint:source_color=vec3(1.0);
void fragment(){
 vec4 tex=texture(TEXTURE,UV);
 float fade=1.0-smoothstep(0.66,0.78,SCREEN_UV.y);
 vec3 col=tex.rgb*tint;
 COLOR=vec4(col,tex.a*fade);
}
