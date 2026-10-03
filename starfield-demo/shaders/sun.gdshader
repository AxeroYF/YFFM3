shader_type spatial;
render_mode unshaded;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*vec2(180.0,90.0);
 float v=n(p+vec2(TIME*0.025,0))*0.55+n(p*2.0)*0.25+n(p*0.15)*0.2;
 float edge=pow(max(dot(normalize(NORMAL),normalize(VIEW)),0.0),0.4);
 ALBEDO=mix(vec3(1.0,0.25,0.018),vec3(1.0,0.76,0.24),v*0.6+edge*0.4);
 EMISSION=ALBEDO*3.0;
}
