shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled;

void fragment() {
	vec3 n = normalize(NORMAL);
	if (abs(n.z) < 0.5) { discard; }
	float ratio = 1.0 - UV.y;
	vec3 green  = vec3(0.1, 1.0, 0.2);
	vec3 yellow = vec3(1.0, 1.0, 0.0);
	vec3 red    = vec3(1.0, 0.1, 0.0);
	vec3 col = (ratio < 0.5)
		? mix(green, yellow, ratio * 2.0)
		: mix(yellow, red, (ratio - 0.5) * 2.0);
	ALBEDO = col;
	ALPHA = 0.7;
}
