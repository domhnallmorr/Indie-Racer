shader_type spatial;
render_mode cull_disabled;

void fragment() {
	vec2 grid = UV / vec2(0.1016, 0.2159);
	grid.y += mod(floor(grid.x), 2.0) * 0.5;
	vec2 cell = floor(grid);
	vec2 edge = min(fract(grid), 1.0-fract(grid));
	vec2 aa = max(fwidth(grid), vec2(0.001));
	vec2 fill = smoothstep(vec2(0.035,0.018)-aa, vec2(0.035,0.018)+aa, edge);
	float variation = fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);
	vec3 brick = mix(vec3(0.25,0.105,0.062),vec3(0.53,0.28,0.16),variation);
	ALBEDO = mix(vec3(0.53,0.49,0.42),brick,fill.x*fill.y);
	ROUGHNESS = 0.95;
}
