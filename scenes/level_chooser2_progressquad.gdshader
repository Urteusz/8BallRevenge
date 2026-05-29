shader_type spatial;

render_mode unshaded, depth_test_disabled;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float max_radius : hint_range(0.0, 0.5) = 0.45;
uniform float edge_softness : hint_range(0.0, 0.05) = 0.005;

void vertex() {
    mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
    mat_world = mat_world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
    MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
    MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
    vec2 centered_uv = UV - vec2(0.5);
    float dist = length(centered_uv);
    float current_radius = progress * max_radius;
    
    float circle = smoothstep(current_radius, current_radius - edge_softness, dist);
    
    ALBEDO = color.rgb;
    ALPHA = color.a * circle;
}