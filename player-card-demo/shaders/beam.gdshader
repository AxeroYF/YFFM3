shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 tint:source_color=vec3(0.15,0.7,1.0);
uniform float clock=0.0;
void fragment(){
 float edge=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
 float scan=pow(max(sin(UV.y*110.0-clock*2.0),0.0),18.0);
 ALBEDO=tint;
 ALPHA=(edge*0.04+scan*0.016)*(0.4+UV.y*0.6);
}
