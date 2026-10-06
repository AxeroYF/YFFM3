shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;
uniform float intensity=0.0;
void fragment() {
 ALBEDO=vec3(0.55,0.72,1.0);
 ALPHA=intensity;
}
