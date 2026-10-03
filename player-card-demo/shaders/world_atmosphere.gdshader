shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec3 tint : source_color = vec3(0.1,0.5,1.0);
void fragment(){float rim=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),4.0);ALBEDO=tint;ALPHA=rim*0.48;}
