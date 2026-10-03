shader_type canvas_item;
uniform int theme_id=0;
uniform float clock=0.0;
uniform vec2 pointer=vec2(0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float n=0.0,a=0.5;for(int i=0;i<5;i++){n+=noise(p)*a;p=p*2.03+7.0;a*=0.5;}return n;}
void fragment(){
 vec2 u=UV; vec2 p=(u-vec2(0.5,0.40))*vec2(1.0,1.5)+pointer*0.016;
 float d=length(p);float nebula=fbm(p*4.0+clock*0.006);
 vec3 col=vec3(0.023,0.037,0.057);
 if(theme_id==0){
  col=mix(vec3(0.017,0.030,0.040),vec3(0.25,0.15,0.045),pow(nebula,2.0)*1.2);
  float arc=exp(-abs(d-0.29)*170.0)+exp(-abs(d-0.335)*240.0)*0.32;
  col+=vec3(0.80,0.49,0.12)*arc*0.65;
  col+=vec3(0.39,0.22,0.06)*exp(-d*5.0)*0.7;
  float rays=pow(abs(sin(atan(p.y,p.x)*23.0+clock*0.025)),30.0);
  col+=vec3(0.18,0.105,0.025)*rays*exp(-abs(d-0.31)*15.0);
 }else if(theme_id==1){
  col=mix(vec3(0.012,0.04,0.068),vec3(0.05,0.23,0.29),pow(nebula,2.3));
  float diagonal=pow(max(sin((u.x*0.75+u.y)*24.0+0.5),0.0),18.0);
  col+=vec3(0.025,0.11,0.16)*diagonal;
  vec2 g=abs(fract(u*vec2(12.0,18.0))-0.5);
  float grid=1.0-smoothstep(0.004,0.018,min(g.x,g.y));
  col+=vec3(0.065,0.26,0.3)*grid*0.17;
  col+=vec3(0.04,0.38,0.52)*exp(-abs(u.x-u.y*0.7-0.1)*90.0)*0.6;
 }else{
  vec3 spectral=0.5+0.5*cos(vec3(0.0,2.1,4.2)+u.y*4.0+u.x*3.0+clock*0.13+pointer.x*0.7);
  col=mix(vec3(0.035,0.050,0.08),vec3(0.12,0.17,0.24),nebula);
  float ribbons=pow(max(sin(d*48.0-clock*0.12+atan(p.y,p.x)*2.0),0.0),22.0);
  col+=spectral*ribbons*0.095;
  col+=spectral*exp(-abs(d-0.34)*120.0)*0.45;
 }
 vec2 sp=u*vec2(110,165);vec2 cell=floor(sp);vec2 f=fract(sp)-0.5;
 col+=vec3(0.75,0.86,1.0)*exp(-dot(f,f)*100.0)*step(0.982,hash(cell))*0.75;
 col*=mix(1.0,0.25,smoothstep(0.60,0.98,u.y));
 float cut=step(0.035,u.x+u.y)*step(0.035,(1.0-u.x)+u.y)*step(0.035,u.x+(1.0-u.y))*step(0.035,2.0-u.x-u.y);
 COLOR=vec4(col,cut);
}
