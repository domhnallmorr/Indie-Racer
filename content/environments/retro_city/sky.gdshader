shader_type sky;

uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
// Align the painted city base just below the track horizon.
uniform float horizon_offset = 0.065;

void sky() {
	vec2 uv = vec2(SKY_COORDS.x, clamp(SKY_COORDS.y + horizon_offset, 0.0, 1.0));
	vec3 painted = texture(panorama, uv).rgb;
	// Feather the generated artwork's two edges over a narrow wrap strip.
	float edge_distance = min(uv.x, 1.0 - uv.x);
	float seam_weight = 0.5 * (1.0 - smoothstep(0.0, 0.012, edge_distance));
	vec3 opposite = texture(panorama, vec2(1.0 - uv.x, uv.y)).rgb;
	COLOR = mix(painted, opposite, seam_weight);
}
