shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float view_sharpness : hint_range(0.1, 10.0) = 3.0;
uniform float base_opacity : hint_range(0.0, 1.0) = 0.0;
uniform float uv_scale : hint_range(0.1, 50.0) = 1.0;

uniform float holo_intensity : hint_range(0.0, 1.0) = 0.5;

vec3 hue_to_rgb(float hue) {
    float r = abs(hue * 6.0 - 3.0) - 1.0;
    float g = 2.0 - abs(hue * 6.0 - 2.0);
    float b = 2.0 - abs(hue * 6.0 - 4.0);
    return clamp(vec3(r, g, b), 0.0, 1.0);
}

void fragment() {
    float fresnel = 1.0 - dot(NORMAL, VIEW);

    vec2 shifted_uv = (UV - 0.5) * uv_scale + 0.5 + (fresnel * 0.1);

    vec4 tex_color = texture(albedo_texture, shifted_uv);
    vec3 base_rgb = tex_color.rgb * tint_color.rgb;

    float rainbow_pos = fract(fresnel);
    vec3 rainbow_color = hue_to_rgb(rainbow_pos);

    vec3 final_color = mix(base_rgb, base_rgb * rainbow_color * 2.0, holo_intensity);

    fresnel = pow(fresnel, view_sharpness);

    ALBEDO = final_color;
    ALPHA = clamp(fresnel + base_opacity, 0.0, 1.0) * tex_color.a;

    METALLIC = 0.8;
    ROUGHNESS = 0.2;

    SPECULAR = holo_intensity;
}