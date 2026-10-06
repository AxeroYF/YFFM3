shader_type sky;
render_mode use_debanding;
uniform float galaxy=0.0;

float hash(vec3 p) { p=fract(p*0.3183099+vec3(0.1,0.2,0.3)); p*=17.0; return fract(p.x*p.y*p.z*(p.x+p.y+p.z)); }
float noise3(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p) { float v=0.0,a=0.5; for(int i=0;i<5;i++){v+=noise3(p)*a;p=p*2.05+7.2;a*=0.5;} return v; }
void sky() {
 vec3 d=EYEDIR;
 float band=exp(-pow((d.y+0.22+d.x*0.28)*3.6,2.0));
 float mist=fbm(d*5.0+vec3(8,2,6));
 float clouds=pow(mist,2.8)*band;
 vec3 c=vec3(0.004,0.008,0.019);
 c+=mix(vec3(0.025,0.055,0.11),vec3(0.12,0.047,0.13),fbm(d*3.0+50.0))*clouds*1.8;
 c+=vec3(0.018,0.047,0.064)*pow(fbm(d*12.0),4.0)*band;
 c*=0.32;
 float river=exp(-pow((d.y+0.60+d.x*0.28)*7.0,2.0));
 float cloud=fbm(d*8.0+vec3(24,7,13));
 float dust=fbm(d*23.0+vec3(1,40,8));
 c+=galaxy*river*mix(vec3(0.045,0.10,0.26),vec3(0.42,0.16,0.40),cloud)*pow(cloud,1.5)*0.65;
 c+=galaxy*pow(river,4.0)*pow(dust,3.0)*vec3(0.10,0.16,0.20);
 for(int layer=0;layer<3;layer++) {
  float scale=160.0+float(layer)*120.0;
  vec3 p=d*scale; vec3 cell=floor(p); vec3 f=fract(p)-0.5;
  float h=hash(cell+float(layer)*71.0);
  float star=exp(-dot(f,f)*(layer==0?210.0:430.0))*step(0.976,h);
  vec3 tint=mix(vec3(0.52,0.7,1.0),vec3(1.0,0.8,0.52),hash(cell+8.0));
  c+=tint*star*(0.9+float(layer)*0.4);
 }
 COLOR=c;
}
