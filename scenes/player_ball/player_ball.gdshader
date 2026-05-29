shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

uniform float edge_size : hint_range(0.0, 1.0) = 0.05;
uniform sampler2D curve_texture;
uniform sampler2D noise_texture;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 edge_color : source_color;
uniform float object_radius = 8.0;

varying vec3 model_pos;

void vertex() {
    UV = UV * uv1_scale.xy + uv1_offset.xy;
    model_pos = VERTEX;
}

void fragment() {
    vec2 base_uv = UV;
    vec4 albedo_tex = texture(texture_albedo, base_uv);
    
    float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
    METALLIC = metallic_tex * metallic;
    SPECULAR = specular;
    
    vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
    float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
    ROUGHNESS = roughness_tex * roughness;

    float dist = length(model_pos);
    float normalized_dist = dist / object_radius;

    vec2 auto_uv = model_pos.xz / object_radius * 5.0;
    float noise_value = texture(noise_texture, auto_uv * 0.1).r;
    float remapped_noise = texture(curve_texture, vec2(noise_value, 0.0)).r;

    float progress = mix(-edge_size, 1.0 + edge_size, u_progress);
    float threshold_val = normalized_dist * remapped_noise;

    if (threshold_val < progress) {
        discard;
    }
    
    ALBEDO = albedo.rgb * albedo_tex.rgb;

    if (threshold_val < progress + edge_size) {
        ALBEDO = edge_color;
    }
}