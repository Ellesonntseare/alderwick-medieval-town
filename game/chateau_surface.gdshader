shader_type spatial;
render_mode cull_disabled;
uniform sampler2D scan_texture : source_color, filter_linear_mipmap, repeat_disable;
void fragment() {
	ALBEDO=texture(scan_texture,UV).rgb;
	ROUGHNESS=0.95;
}
