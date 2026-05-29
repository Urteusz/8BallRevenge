shader_type spatial;

render_mode unshaded, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float inner_radius : hint_range(0.0, 0.5) = 0.45;
uniform float outer_radius : hint_range(0.0, 0.5) = 0.5;

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
    
    float outer_edge = smoothstep(outer_radius, outer_radius - edge_softness, dist);
    float inner_edge = smoothstep(inner_radius - edge_softness, inner_radius, dist);
    
    float ring_mask = outer_edge * inner_edge;
    
    ALBEDO = outline_color.rgb;
    
    ALPHA = outline_color.a * ring_mask;
}