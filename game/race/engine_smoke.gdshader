shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

void vertex() {
	// Face the camera while preserving each CPU particle's growth.
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	facing[0].xyz *= length(MODEL_MATRIX[0].xyz);
	facing[1].xyz *= length(MODEL_MATRIX[1].xyz);
	facing[2].xyz *= length(MODEL_MATRIX[2].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}

void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	float feather = 1.0 - smoothstep(0.0, 1.0, radius);
	ALBEDO = vec3(0.48, 0.48, 0.50);
	ALPHA = COLOR.a * feather * feather;
}
