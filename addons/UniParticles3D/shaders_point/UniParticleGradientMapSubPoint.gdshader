shader_type spatial;
render_mode unshaded, blend_sub, 	depth_draw_never, cull_disabled, diffuse_burley, specular_disabled, shadows_disabled;

#define POINT_FILTERING
#include "../uniparticle_include.gdshaderinc"

varying vec2 rotated_uv;

void vertex() {
	vec2 get_rotated_uv = UV;
	MODELVIEW_MATRIX = vertex_common(MODEL_MATRIX, INV_VIEW_MATRIX, VIEW_MATRIX, COLOR, INSTANCE_CUSTOM, UV, vec2(float(particles_anim_h_frames), float(particles_anim_v_frames)), get_rotated_uv);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	rotated_uv = get_rotated_uv;
}

void fragment() {
	vec4 input_color = texture(albedo_texture, rotated_uv);
	float value = (input_color.r + input_color.g + input_color.b) / 3.0;
	vec4 output_color = texture(gradient_texture, vec2(COLOR.g, 0.1)) * vec4(input_color.rgb,1.0);

	ALBEDO = hue_change(output_color.rgb * tint_color.rgb, COLOR.r);
	ALPHA = min(min(min(input_color.a * output_color.a, value),output_color.a),tint_color.a);
}