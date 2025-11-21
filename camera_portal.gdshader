shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D viewport_texture : source_color;

void fragment() {
    vec3 portal_view = texture(viewport_texture, SCREEN_UV).rgb;
    
    ALBEDO = portal_view;
}