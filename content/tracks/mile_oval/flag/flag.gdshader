shader_type spatial;
render_mode cull_disabled;
uniform sampler2D flag_texture : source_color, filter_linear_mipmap_anisotropic;

void vertex() {
	float u = UV.x;
	float phase = u * 9.0 - TIME * 3.8 + UV.y * 2.0;
	VERTEX.z += u * (0.42 * sin(phase) + 0.12 * sin(u * 21.0 - TIME * 6.0));
	VERTEX.y -= 0.28 * u * u;
	VERTEX.y += 0.07 * u * sin(phase);
}

void fragment() {
	ALBEDO = texture(flag_texture, UV).rgb;
	ROUGHNESS = 0.88;
	// Derivatives keep the light following the animated cloth folds.
	vec3 face_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = FRONT_FACING ? face_normal : -face_normal;
}
