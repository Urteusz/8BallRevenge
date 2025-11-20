shader_type spatial;

// Kolory - domyślnie żółty (Speed) i czerwony (Energy)
uniform vec3 base_color : source_color = vec3(1.0, 0.8, 0.0); 
uniform vec3 energy_color : source_color = vec3(1.0, 0.1, 0.0);

// Ustawienia
uniform float metallic : hint_range(0.0, 1.0) = 0.9;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float energy_speed = 3.0; // Jak szybko pulsuje
uniform float fresnel_power = 2.0; // Świecenie na krawędziach

void fragment() {
	// Podstawowy kolor metaliczny
	ALBEDO = base_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	
	// Obliczanie efektu Fresnel (świecenie na krawędziach, daje efekt "aerodynamiczny")
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
	
	// Dodajemy pulsującą poświatę, która przesuwa się w czasie
	float pulse = sin(TIME * energy_speed) * 0.5 + 0.5;
	
	// Mieszamy kolor bazowy z kolorem energii na krawędziach (EMISSION sprawia, że świeci)
	EMISSION = energy_color * fresnel * (1.0 + pulse);
}