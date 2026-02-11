shader_type canvas_item;

uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float brightness : hint_range(0.0, 5.0) = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
}

void fragment() {
    vec2 scaled_uv = UV * uv_scale + vec2(TIME * 0.2, TIME * 0.2);
    vec4 color = texture(TEXTURE, scaled_uv);
    COLOR = color * tint;
    COLOR.rgb *= brightness;
}