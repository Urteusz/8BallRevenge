shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.5, 0.8, 1.0, 0.8);
uniform float flow_speed : hint_range(0.1, 5.0) = 1.5;
uniform float dash_length : hint_range(0.1, 1.0) = 0.3;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.5;

void fragment() {
    vec2 uv = UV;

    // Animowany offset dla efektu przepływu
    float time_offset = TIME * flow_speed;
    float pattern = fract((uv.x + time_offset) / dash_length);

    // Tworzenie pulsującego wzoru (dashed line effect)
    float alpha = smoothstep(0.3, 0.5, pattern) * smoothstep(0.7, 0.5, pattern);

    // Dodanie subtelnego świecenia
    float glow = alpha * glow_strength;

    // Finalne kolory z uwzględnieniem świecenia
    vec3 final_color = line_color.rgb * (1.0 + glow);
    float final_alpha = line_color.a * alpha;

    COLOR = vec4(final_color, final_alpha);
}
