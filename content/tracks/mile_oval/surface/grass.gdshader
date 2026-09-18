shader_type spatial;
// Use the same turf atlas strip and three-metre scale as the backstraight bank.
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 track_origin = vec3(0.0);
varying vec2 ground_position;

void vertex() {
	ground_position = ((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - track_origin).xz;
}

void fragment() {
	vec2 tile = fract(ground_position / 3.0);
	vec2 uv = vec2(mix(0.006, 0.994, tile.x) / 3.0, mix(0.003, 0.997, tile.y));
	// Derive mip gradients before wrapping, avoiding bright seams at tile edges.
	vec2 continuous_uv = ground_position / 3.0 * vec2(0.988 / 3.0, 0.994);
	vec2 dx = dFdx(continuous_uv);
	vec2 dy = dFdy(continuous_uv);
	dx *= min(1.0, 0.0015 / max(length(dx), 0.000001));
	dy *= min(1.0, 0.0015 / max(length(dy), 0.000001));
	vec3 detail = textureGrad(atlas, uv, dx, dy).rgb;
	// The atlas neighbours contain concrete and wood; average inside the turf
	// strip for distant pixels instead of allowing those strips to bleed in.
	vec3 distant = (textureLod(atlas, vec2(0.0833, 0.25), 6.0).rgb
		+ textureLod(atlas, vec2(0.25, 0.25), 6.0).rgb
		+ textureLod(atlas, vec2(0.0833, 0.75), 6.0).rgb
		+ textureLod(atlas, vec2(0.25, 0.75), 6.0).rgb) * 0.25;
	float footprint = max(length(dFdx(ground_position)), length(dFdy(ground_position)));
	ALBEDO = mix(detail, distant, smoothstep(0.025, 0.25, footprint));
	ROUGHNESS = 1.0;
}
