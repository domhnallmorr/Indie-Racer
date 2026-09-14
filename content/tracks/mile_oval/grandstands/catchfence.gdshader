shader_type spatial;
render_mode cull_disabled;

void fragment() {
	// Diamond weave in metres, softened at distance to avoid wire shimmer.
	vec2 weave = vec2(UV.x + UV.y, UV.x - UV.y) / 0.16;
	vec2 distance_to_wire = abs(fract(weave + 0.5) - 0.5);
	vec2 footprint = max(fwidth(weave), vec2(0.001));
	vec2 coverage = 1.0 - smoothstep(vec2(0.025) - footprint * 0.5, vec2(0.025) + footprint * 0.5, distance_to_wire);
	float fade = 1.0 - smoothstep(0.4, 1.6, max(footprint.x, footprint.y));
	ALBEDO = vec3(0.32, 0.36, 0.38);
	ROUGHNESS = 0.75;
	ALPHA = mix(0.07, max(coverage.x, coverage.y), fade);
}
