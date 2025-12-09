shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always; 

uniform vec3 base_color : source_color = vec3(0.2, 0.6, 1.0);
uniform float fresnel_power : hint_range(0.1, 10.0) = 2.0;
uniform float fresnel_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float opacity : hint_range(0.0, 1.0) = 0.5; 

void vertex() {
}

void fragment() {
    vec3 flat_normal = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));

    float fresnel_term = pow(clamp(1.0 - dot(flat_normal, VIEW), 0.0, 1.0), fresnel_power);

    ALBEDO = base_color;
    
    EMISSION = base_color * fresnel_term * fresnel_intensity;

    NORMAL = flat_normal;
    
    ALPHA = opacity;
}