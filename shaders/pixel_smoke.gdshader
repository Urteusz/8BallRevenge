shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 smoke_color : source_color = vec4(0.15, 0.15, 0.15, 0.7);

void vertex() {
	// Billboard: replace rotation with inverse view, keep per-particle scale
	float scale_x = length(MODEL_MATRIX[0].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);
	mat4 billboard = mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * scale_x, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * scale_y, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz, 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
}

void fragment() {
	float dist = distance(UV, vec2(0.5));
	float circle = 1.0 - step(0.5, dist);
	ALBEDO = smoke_color.rgb;
	ALPHA = circle * COLOR.a;
}
