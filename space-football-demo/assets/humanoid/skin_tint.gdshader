shader_type spatial;
uniform sampler2D skin_texture : source_color;
uniform vec4 skin_tint : source_color = vec4(0.8,0.6,0.4,1.0);
uniform vec4 hair_tint : source_color = vec4(0.1,0.07,0.04,1.0);
uniform int beard_style = 0;
void fragment() {
 vec3 source=texture(skin_texture,UV).rgb;
 float detail=clamp(dot(source,vec3(0.2126,0.7152,0.0722))/0.46,0.30,1.35);
 vec3 skin=skin_tint.rgb*detail;
 float beard=COLOR.r;
 float moustache=COLOR.g;
 if(beard_style==0) { beard=0.0; moustache=0.0; }
 if(beard_style==1) { beard*=0.40; moustache*=0.5; }
 if(beard_style==3) { beard=COLOR.b; }
 if(beard_style==4) { beard=0.0; }
 float grain=0.97+0.03*sin(UV.x*1700.0+sin(UV.y*1100.0))*sin(UV.y*1500.0);
 float coverage=clamp(max(beard,moustache)*grain,0.0,0.98);
 ALBEDO=mix(skin,hair_tint.rgb*0.8,coverage);
 ROUGHNESS=0.88;
 SPECULAR=0.22;
}
