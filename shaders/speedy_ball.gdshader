shader_type spatial;

uniform vec3 base_color : source_color = vec3(1.0, 0.8, 0.0); 
uniform vec3 energy_color : source_color = vec3(1.0, 0.1, 0.0);

uniform float metallic : hint_range(0.0, 1.0) = 0.9;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float energy_speed = 3.0;
uniform float fresnel_power = 2.0;

void fragment() {
	ALBEDO = base_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
	
	float pulse = sin(TIME * energy_speed) * 0.5 + 0.5;
	
	EMISSION = energy_color * fresnel * (1.0 + pulse);
}