shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void fragment(){
 float r=length(UV-0.5)*2.0;
 float halo=exp(-r*r*8.0)*0.7;
 float glow=exp(-r*r*2.0)*0.07;
 ALBEDO=vec3(1.0,0.29,0.045);
 ALPHA=(halo+glow)*(1.0-smoothstep(0.7,1.0,r));
}
