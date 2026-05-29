shader_type sky;

uniform vec4 color_old : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 color_new : source_color = vec4(0.2, 0.4, 0.8, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 grid_density = vec2(16.0, 9.0); 

uniform float phase_1_end : hint_range(0.0, 1.0) = 0.45;
uniform float phase_2_start : hint_range(0.0, 1.0) = 0.55;

uniform vec2 pattern_density = vec2(64.0, 36.0);
uniform float dot_size : hint_range(0.0, 0.5) = 0.15;
uniform float pattern_opacity : hint_range(0.0, 1.0) = 0.1;

void sky() {
    vec2 grid_uv = SCREEN_UV * grid_density;
    ivec2 grid_pos = ivec2(grid_uv);
    bool is_even = (grid_pos.x + grid_pos.y) % 2 == 0;
    vec2 local_uv = fract(grid_uv);
    
    float local_prog = 0.0;
    
    if (is_even) {
        local_prog = clamp(progress / phase_1_end, 0.0, 1.0);
    } else {
        local_prog = clamp((progress - phase_2_start) / (1.0 - phase_2_start), 0.0, 1.0);
    }
    
    float mask = step(local_uv.y, local_prog);
    vec3 base_color = mix(color_old.rgb, color_new.rgb, mask);
    
    vec2 dot_uv = fract(SCREEN_UV * pattern_density) - vec2(0.5);
    float dist = length(dot_uv);
    float dot_mask = step(dist, dot_size);
    
    COLOR = mix(base_color, base_color * 0.8, dot_mask * pattern_opacity);
}