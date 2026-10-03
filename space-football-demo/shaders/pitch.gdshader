shader_type spatial;
uniform vec3 tint : source_color = vec3(0.05,0.6,0.55);
void fragment() {
	vec2 p=UV*vec2(16.0,9.0);
	vec2 edge=abs(fract(p)-0.5);
	float grid=smoothstep(0.477,0.495,max(edge.x,edge.y));
	float bands=step(0.5,fract(UV.x*10.0));
	ALBEDO=mix(vec3(0.013,0.040,0.057),vec3(0.025,0.069,0.08),bands);
	EMISSION=tint*grid*0.18;
	METALLIC=0.55;
	ROUGHNESS=0.38;
}
