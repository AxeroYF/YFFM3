shader_type spatial;
uniform vec3 base_color : source_color = vec3(0.4,0.2,0.1);
uniform vec3 secondary_color : source_color = vec3(0.8,0.6,0.35);
uniform int kind=0;
uniform float seed=0.0;
float hash(vec3 p){p=fract(p*0.3183099+0.1);p*=17.0;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float n(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 p){float v=0.0,a=0.5;for(int i=0;i<5;i++){v+=n(p)*a;p=p*2.1+3.0;a*=0.5;}return v;}
void fragment(){
 vec3 p=vec3(sin(UV.x*6.283)*sin(UV.y*3.14159),cos(UV.y*3.14159),cos(UV.x*6.283)*sin(UV.y*3.14159));
 float f=fbm(p*5.0+seed);
 vec3 col;
 if(kind==0){
  float bands=sin(p.y*65.0+f*9.0)*0.5+0.5;
  float fine=sin(p.y*175.0+f*8.0)*0.5+0.5;
  col=mix(base_color,secondary_color,clamp(bands*0.5+fine*0.12+f*0.38,0.0,1.0));
 }else if(kind==1){
  float land=smoothstep(0.48,0.55,f);
  col=mix(base_color,secondary_color,land);
  float clouds=smoothstep(0.57,0.72,fbm(p*8.0+vec3(16.0,0,0)));
  col=mix(col,vec3(0.78,0.91,1.0),clouds*0.85);
  col=mix(col,vec3(0.8,0.91,1.0),smoothstep(0.86,0.99,abs(p.y))*0.8);
 }else{ col=mix(base_color,secondary_color,f);col*=0.82+n(p*65.0)*0.25; }
 ALBEDO=col; ROUGHNESS=0.88;
}
