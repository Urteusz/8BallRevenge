shader_type spatial;

render_mode blend_mix, depth_draw_never, cull_back;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 object_position;
uniform float visible_distance : hint_range(0.0, 20.0) = 3.0;
uniform float invisible_distance : hint_range(0.0, 20.0) = 8.0;

varying vec3 v_world_pos;

void vertex() {
  v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
  ALBEDO = albedo_color.rgb;

  float dist = distance(object_position, v_world_pos);

  float fade_alpha = smoothstep(invisible_distance, visible_distance, dist);

  ALPHA = albedo_color.a * fade_alpha;
}
