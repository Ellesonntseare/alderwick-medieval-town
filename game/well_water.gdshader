shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float ripple=sin(length(UV-vec2(.5))*42.0-TIME*1.5)*.5+.5;
	ALBEDO=mix(vec3(.045,.20,.25),vec3(.18,.47,.54),.18+ripple*.16);
	ROUGHNESS=.16;
	METALLIC=.25;
	SPECULAR=.8;
}
