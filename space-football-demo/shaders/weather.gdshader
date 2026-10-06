shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform int kind=0;
uniform float clock_time=0.0;
uniform float wind_strength=0.0;
varying float seed;
void vertex() {
 vec4 r=INSTANCE_CUSTOM;
 seed=r.w;
 vec3 p=VERTEX;
 if(kind==0) {
  float fall=fract(r.z+clock_time*(0.72+r.w*0.30));
  p.x+=r.x*76.0-38.0;
  p.y+=(1.0-fall)*20.0;
  p.z=r.y*46.0-23.0+wind_strength*(fall-0.5)*5.0-p.y*wind_strength*0.06;
 } else if(kind==1) {
  p=vec3(p.x,0.025,p.y);
  p.xz+=vec2(r.x*69.0-34.5,r.y*38.0-19.0);
 } else {
  float drift=fract(r.y+clock_time*(0.16+r.w*0.07));
  p=vec3(p.x,r.z*3.5+0.35,p.y);
  p.x+=r.x*72.0-36.0;
  p.z+=drift*44.0-22.0;
 }
 VERTEX=p;
}
void fragment() {
 float alpha;
 if(kind==1) {
  float phase=fract(seed+clock_time*1.6);
  float radius=length(UV-0.5)*2.0;
  alpha=(1.0-smoothstep(0.03,0.12,abs(radius-phase)))*(1.0-phase)*0.24;
 } else {
  alpha=(1.0-smoothstep(0.1,0.5,abs(UV.x-0.5)))*sin(UV.y*3.14159)*(kind==0?0.32:0.22);
 }
 ALBEDO=vec3(0.54,0.77,0.90);
 ALPHA=alpha;
}
