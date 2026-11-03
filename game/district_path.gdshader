shader_type spatial;
varying vec3 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 grid = world_point.xz * vec2(1.7, 1.35);
	grid.x += mod(floor(grid.y), 2.0) * 0.5;
	vec2 cell = fract(grid);
	float edge = min(min(cell.x, 1.0-cell.x), min(cell.y, 1.0-cell.y));
	vec3 stone = mix(vec3(0.38,0.34,0.26), vec3(0.52,0.46,0.35), hash(floor(grid)));
	ALBEDO = mix(vec3(0.27,0.26,0.20), stone, smoothstep(0.02,0.065,edge));
	ROUGHNESS = 1.0;
}
