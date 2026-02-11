shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 aura_color : source_color = vec3(0.5, 0.0, 0.5);
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.5;

void vertex() {
	float expand = 0.08 + intensity * 0.25;
	VERTEX *= 1.0 + expand;
}

void fragment() {
	float pulse = sin(TIME * pulse_speed) * 0.2 + 0.8;
	
	// Efekt Fresnela (świecenie na krawędziach)
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float fresnel = pow(edge, 1.5);

	// Obliczanie przezroczystości
	float alpha = fresnel * intensity * 0.8 * pulse;
	
	// Dodatkowe wypełnienie środka przy naładowaniu
	float core = (1.0 - edge) * intensity * intensity * 0.3;
	alpha += core;

	// KOLOR: Bierzemy dokładnie to, co przysłał skrypt (aura_color)
	ALBEDO = aura_color * (1.5 + intensity * 2.0); 
	
	ALPHA = clamp(alpha, 0.0, 1.0);
}