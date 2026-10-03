shader_type spatial;
render_mode cull_disabled, unshaded;
uniform vec3 impact_point=vec3(0.0);
uniform vec3 impact_normal=vec3(0.0);
uniform float impact_strength=0.0;
uniform float impact_age=10.0;
void vertex() {
 float distance_to_impact=length(VERTEX-impact_point);
 float age=max(0.0,impact_age-distance_to_impact*0.025);
 float wave=sin(age*16.0)*exp(-age*5.5);
 float anchors=smoothstep(0.0,0.5,VERTEX.x)*smoothstep(0.0,0.45,VERTEX.y);
 VERTEX+=impact_normal*wave*impact_strength*0.9*exp(-distance_to_impact*distance_to_impact/4.0)*anchors;
}
void fragment() {
 ALBEDO=vec3(0.44,0.65,0.71);
}
