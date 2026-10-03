shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;
void fragment(){
 float r=UV.x;
 float bands=0.62+0.16*sin(r*230.0)+0.08*sin(r*670.0);
 float gap=1.0-smoothstep(0.018,0.027,abs(r-0.62));
 vec3 c=mix(vec3(0.29,0.23,0.17),vec3(0.82,0.71,0.5),sin(r*18.0)*0.3+0.5);
 ALBEDO=c; ROUGHNESS=1.0; ALPHA=clamp(bands-gap*0.60,0.03,0.9)*smoothstep(0.0,0.025,r)*(1.0-smoothstep(0.96,1.0,r));
}
