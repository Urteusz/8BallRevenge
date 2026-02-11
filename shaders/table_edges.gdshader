shader_type spatial;

render_mode blend_mix, depth_draw_never;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float fade_start_distance : hint_range(0.0, 20.0) = 5.0;
uniform float fade_end_distance : hint_range(0.0, 20.0) = 2.0;

varying vec3 v_world_pos;

void vertex() {
  v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
  ALBEDO = albedo_color.rgb;

  float dist = distance(CAMERA_POSITION_WORLD, v_world_pos);

  float fade_alpha = smoothstep(fade_end_distance, fade_start_distance, dist);

  ALPHA = albedo_color.a * fade_alpha;
}
