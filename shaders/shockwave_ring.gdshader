shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 ring_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float ring_thickness : hint_range(0.01, 0.3) = 0.08;

void vertex() {
	// Billboard: face camera, preserve per-particle scale
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
	float outer = 0.5;
	float inner = outer - ring_thickness;
	float ring = smoothstep(inner - 0.02, inner, dist) * (1.0 - smoothstep(outer - 0.02, outer, dist));
	ALBEDO = ring_color.rgb;
	ALPHA = ring * COLOR.a;
}
