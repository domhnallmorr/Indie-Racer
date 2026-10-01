shader_type sky;

uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
// Align the painted city base just below the track horizon.
uniform float horizon_offset = 0.065;
// Compress the painted buildings around their base, leaving the cloud band alone.
uniform float skyline_scale : hint_range(0.25, 1.0) = 0.75;

float skyline_y(float y) {
	const float sky_start = 0.475;
	const float city_top = 0.49;
	const float city_base = 0.574;
	float scaled_top = city_base - (city_base - city_top) * skyline_scale;
	if (y <= sky_start || y >= city_base) {
		return y;
	}
	if (y < scaled_top) {
		// Fill the revealed strip with the existing clear horizon sky.
		return mix(sky_start, city_top, (y - sky_start) / (scaled_top - sky_start));
	}
	return city_base + (y - city_base) / skyline_scale;
}

void sky() {
	vec2 uv = vec2(SKY_COORDS.x, clamp(SKY_COORDS.y + horizon_offset, 0.0, 1.0));
	uv.y = skyline_y(uv.y);
	vec3 painted = texture(panorama, uv).rgb;
	// Feather the generated artwork's two edges over a narrow wrap strip.
	float edge_distance = min(uv.x, 1.0 - uv.x);
	float seam_weight = 0.5 * (1.0 - smoothstep(0.0, 0.012, edge_distance));
	vec3 opposite = texture(panorama, vec2(1.0 - uv.x, uv.y)).rgb;
	COLOR = mix(painted, opposite, seam_weight);
}
