shader_type canvas_item;
uniform float clock=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 uv=UV;vec2 p=uv*vec2(1.7778,1.0);
 vec3 c=vec3(0.019,0.029,0.047);
 float mist=noise(p*5.0+vec2(clock*0.003,0))*0.55+noise(p*11.0)*0.3+noise(p*27.0)*0.15;
 c+=vec3(0.035,0.07,0.17)*pow(mist,2.0);
 c+=vec3(0.039,0.025,0.006)*exp(-length((uv-vec2(0.23,0.53))*vec2(6.0,2.8)));
 c+=vec3(0.004,0.045,0.065)*exp(-length((uv-vec2(0.50,0.55))*vec2(7.0,3.0)));
 c+=vec3(0.04,0.02,0.055)*exp(-length((uv-vec2(0.78,0.53))*vec2(6.0,2.8)));
 vec2 st=p*220.0;vec2 cell=floor(st);vec2 f=fract(st)-0.5;
 float star=exp(-dot(f,f)*130.0)*step(0.991,hash(cell));
 c+=vec3(0.4,0.58,0.75)*star*(0.5+0.2*sin(clock*0.6+hash(cell)*20.0));
 c*=0.7+0.3*(1.0-length(uv-0.5));
 COLOR=vec4(c,1.0);
}
