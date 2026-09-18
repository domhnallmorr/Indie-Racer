shader_type spatial;
varying vec3 sponsor_color;
varying vec3 detail_color;
void vertex() {
	sponsor_color = INSTANCE_CUSTOM.rgb;
	detail_color = COLOR.rgb;
}
void fragment() {
	ALBEDO = mix(detail_color,sponsor_color,UV.x);
	ROUGHNESS = .72;
	SPECULAR = .25;
}
