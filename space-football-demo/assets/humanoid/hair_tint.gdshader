shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D hair_texture : source_color;
uniform vec4 hair_tint : source_color = vec4(0.08,0.06,0.04,1.0);
void fragment() {
 vec4 tex=texture(hair_texture,UV);
 float light=clamp(dot(tex.rgb,vec3(0.2126,0.7152,0.0722))*2.4,0.25,1.55);
 ALBEDO=hair_tint.rgb*light;
 ALPHA=tex.a;
 ALPHA_SCISSOR_THRESHOLD=0.42;
 ROUGHNESS=0.86;
 SPECULAR=0.18;
}
