shader_type canvas_item;

uniform sampler2D target_texture : source_color, filter_linear_mipmap;
uniform float movement_speed : hint_range(0.0, 10.0) = 2.0;
uniform float movement_strength : hint_range(0.0, 0.1) = 0.02;
uniform float blur_strength : hint_range(0.0, 5.0) = 2.5;
uniform int quality : hint_range(1, 20) = 8;

void fragment() {
	vec2 distorted_uv = UV;
	
	distorted_uv.x += sin(TIME * movement_speed + UV.y * 5.0) * movement_strength;
	distorted_uv.y += cos(TIME * movement_speed + UV.x * 5.0) * movement_strength;
	
	vec4 color = vec4(0.0);
	float total = 0.0;
	vec2 pixel_size = 1.0 / vec2(textureSize(target_texture, 0));
	
	color += texture(target_texture, distorted_uv);
	total += 1.0;
	
	for (int i = 1; i <= quality; i++) {
		float offset = float(i) * blur_strength;
		
		color += texture(target_texture, distorted_uv + vec2(offset, offset) * pixel_size);
		color += texture(target_texture, distorted_uv + vec2(-offset, offset) * pixel_size);
		color += texture(target_texture, distorted_uv + vec2(-offset, -offset) * pixel_size);
		color += texture(target_texture, distorted_uv + vec2(offset, -offset) * pixel_size);
		
		total += 4.0;
	}
	
	COLOR = color / total;
}