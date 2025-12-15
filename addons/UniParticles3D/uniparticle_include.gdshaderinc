#ifdef POINT_FILTERING
uniform sampler2D albedo_texture : source_color, repeat_disable, filter_nearest;
#else
uniform sampler2D albedo_texture : source_color, repeat_disable, filter_linear_mipmap;
#endif

uniform sampler2D gradient_texture : source_color, hint_default_white, repeat_disable;

uniform int billboard_mode = 0;
uniform int align_to_velocity = 0;
uniform int particles_anim_h_frames : hint_range(1, 128) = 1;
uniform int particles_anim_v_frames : hint_range(1, 128) = 1;
uniform vec4 tint_color:source_color = vec4(1.0);

vec3 hue_change(vec3 input_color, float shift_hue) {
	vec3 color_hsv;
	{
		vec3 c = input_color;
		vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
		vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
		vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
		float d = q.x - min(q.w, q.y);
		float e = 1.0e-10;
		color_hsv=vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
	}
	color_hsv.x = mod((color_hsv.x + shift_hue), 1.0f);
	vec3 color_rgb;
	{
		vec3 c = color_hsv;
		vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
		vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
		color_rgb=c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
	}
	return color_rgb.rgb;
}

mat4 vertex_common(mat4 _MODEL_MATRIX, mat4 _INV_VIEW_MATRIX, mat4 _VIEW_MATRIX, vec4 _COLOR, vec4 instance_custom, vec2 _UV, vec2 particles_anim, out vec2 final_uv) {
	// Get the direction of motion from the model matrix's forward vector (Z axis)
	vec3 velocity_dir = normalize(_MODEL_MATRIX[2].xyz);
	// Get custom scales and parameters
	float scale_x = instance_custom.y;
	float scale_y = instance_custom.z;
	float angle = instance_custom.x;
	float stretch = instance_custom.w;
	mat4 return_modelview_matrix;
	// Get view direction (from object to camera)
	vec3 view_dir = normalize(_INV_VIEW_MATRIX[2].xyz);

	// Calculate how parallel the view is to the velocity
	float parallel_factor = abs(dot(velocity_dir, view_dir));

	// Setup billboard orientation vectors
	vec3 billboard_right = normalize(_INV_VIEW_MATRIX[0].xyz);
	vec3 billboard_up = normalize(_INV_VIEW_MATRIX[1].xyz);

	// Keep track of the rotation we need to apply
	float total_angle = angle;

	if (billboard_mode == 2) {
		// NO BILLBOARD WANTED
		// Instead of rotating UVs, apply rotation to the model matrix
		float cos_a = cos(angle);
		float sin_a = sin(angle);

		// Create rotation matrix around Z axis
		mat4 rot_mat = mat4(
			vec4(cos_a, -sin_a, 0.0, 0.0),
			vec4(sin_a, cos_a, 0.0, 0.0),
			vec4(0.0, 0.0, 1.0, 0.0),
			vec4(0.0, 0.0, 0.0, 1.0)
		);

		// Use the original model matrix but apply custom scaling and rotation
		mat4 scale_mat = mat4(
			vec4(length(_MODEL_MATRIX[0].xyz) * scale_x, 0.0, 0.0, 0.0),
			vec4(0.0, length(_MODEL_MATRIX[1].xyz) * scale_y, 0.0, 0.0),
			vec4(0.0, 0.0, length(_MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));

		return_modelview_matrix = _VIEW_MATRIX * _MODEL_MATRIX * rot_mat * scale_mat;
	} else if (billboard_mode == 0) { // STANDARD BILLBOARDING
		float vel_angle = 0.0;
		if (align_to_velocity == 1){
			// Calculate rotation to align with velocity
			vel_angle = atan(dot(velocity_dir, billboard_right), dot(velocity_dir, billboard_up));
			// Rotate the billboard vectors to align with velocity
			vec3 new_up = (billboard_up * cos(vel_angle) + billboard_right * sin(vel_angle));
			vec3 new_right = (-billboard_up * sin(vel_angle) + billboard_right * cos(vel_angle));
			// Apply scaling
			billboard_right = new_right * scale_x;
			billboard_up = new_up * scale_y;
		} else {
			billboard_right *= scale_x;
			billboard_up *= scale_y;
		}

		// Apply rotation to the billboard
		float cos_a = cos(angle);
		float sin_a = sin(angle);
		vec3 rotated_right = billboard_right * cos_a - billboard_up * sin_a;
		vec3 rotated_up = billboard_right * sin_a + billboard_up * cos_a;
		billboard_right = rotated_right;
		billboard_up = rotated_up;

		// Simple billboard matrix
		mat4 mat_world = mat4(vec4(billboard_right, 0.0), vec4(billboard_up, 0.0), vec4(view_dir, 0.0), _MODEL_MATRIX[3]);
		// Preserve original scale
		mat4 scale_mat = mat4(vec4(length(_MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(_MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(_MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		return_modelview_matrix = _VIEW_MATRIX * mat_world * scale_mat;
	} else if (billboard_mode == 3) {
		// VERTICAL BILLBOARDING - Y-axis constrained
		// Get world up vector (assuming Y is up)
		vec3 world_up = vec3(0.0, 1.0, 0.0);
		// Get direction to camera (in world space)
		vec3 to_camera = normalize(_INV_VIEW_MATRIX[3].xyz - _MODEL_MATRIX[3].xyz);
		// Project camera direction onto the XZ plane
		to_camera.y = 0.0;
		to_camera = normalize(to_camera);
		// Construct right vector perpendicular to world up and to_camera
		vec3 right = normalize(cross(world_up, to_camera));
		// Apply custom scales
		right *= scale_x;
		world_up *= scale_y;

		// Apply rotation to the billboard
		float cos_a = cos(angle);
		float sin_a = sin(angle);
		vec3 rotated_right = right * cos_a - world_up * sin_a;
		vec3 rotated_up = right * sin_a + world_up * cos_a;
		right = rotated_right;
		world_up = rotated_up;

		// Construct vertical billboard matrix
		mat4 mat_world = mat4(
			vec4(right, 0.0),
			vec4(world_up, 0.0),
			vec4(to_camera, 0.0),
			_MODEL_MATRIX[3]);
		// Preserve original scale
		mat4 scale_mat = mat4(
			vec4(length(_MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(_MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(_MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		return_modelview_matrix = _VIEW_MATRIX * mat_world * scale_mat;
	} else if (billboard_mode == 1) { // STRETCHED BILLBOARDING
		// Project velocity onto view plane
		vec3 projected_vel = velocity_dir - view_dir * dot(velocity_dir, view_dir);
		float proj_length = length(projected_vel);

		// Improved stretch factor calculation
		float view_aligned_factor = smoothstep(0.0, 0.3, proj_length);
		float effective_stretch = mix(stretch, stretch * 0.25, parallel_factor * parallel_factor);
		effective_stretch = mix(effective_stretch, stretch, view_aligned_factor);

		// Calculate stretch direction
		vec3 stretch_dir = normalize(mix(velocity_dir, projected_vel, view_aligned_factor));

		// Calculate angle between up vector and stretch direction
		float vel_angle = atan(dot(stretch_dir, billboard_right), dot(stretch_dir, billboard_up));

		// Apply custom scales to the billboard vectors
		billboard_right *= scale_x;
		billboard_up *= scale_y;

		// Rotate and stretch the vectors
		vec3 new_up = (billboard_up * cos(vel_angle) + billboard_right * sin(vel_angle));
		vec3 new_right = (-billboard_up * sin(vel_angle) + billboard_right * cos(vel_angle));

		float abs_stretch = (effective_stretch);
		billboard_up = new_up * abs_stretch;
		billboard_right = new_right * (1.0 / sqrt(abs_stretch));

		// Apply particle rotation
		float additional_angle = angle + (align_to_velocity == 0 ? vel_angle : 0.0);
		float cos_a = cos(additional_angle);
		float sin_a = sin(additional_angle);
		vec3 rotated_right = billboard_right * cos_a - billboard_up * sin_a;
		vec3 rotated_up = billboard_right * sin_a + billboard_up * cos_a;
		billboard_right = rotated_right;
		billboard_up = rotated_up;

		// Construct final billboard matrix
		mat4 mat_world = mat4(
			vec4(billboard_right, 0.0),
			vec4(billboard_up, 0.0),
			vec4(view_dir, 0.0),
			_MODEL_MATRIX[3]);

		// Preserve original scale
		mat4 scale_mat = mat4(
			vec4(length(_MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(_MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(_MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));

		return_modelview_matrix = _VIEW_MATRIX * mat_world * scale_mat;
	} else if (billboard_mode == 4) { // STRETCHED BILLBOARDING VERTICAL
		// Project velocity onto view plane
		vec3 projected_vel = velocity_dir - view_dir * dot(velocity_dir, view_dir);
		// Calculate stretch direction
		// Get world up vector (assuming Y is up)
		billboard_up = vec3(0.0, 1.0, 0.0);
		// Get direction to camera (in world space)
		vec3 to_camera = normalize(_INV_VIEW_MATRIX[3].xyz - _MODEL_MATRIX[3].xyz);
		// Project camera direction onto the XZ plane
		to_camera.y = 0.0;
		to_camera = normalize(to_camera);
		// Construct right vector perpendicular to world up and to_camera
		vec3 billboard_right = normalize(cross(billboard_up, to_camera));
		// Apply custom scales to the billboard vectors
		billboard_right *= scale_x;
		billboard_up *= scale_y;
		// Rotate and stretch the vectors
		billboard_up *= stretch;
		billboard_right *= (1.0 / sqrt(stretch));

		// Calculate stretch direction
		vec3 stretch_dir = normalize(mix(velocity_dir, projected_vel, 0.5));

		// Calculate angle between up vector and stretch direction
		float vel_angle = atan(dot(stretch_dir, billboard_right), dot(stretch_dir, billboard_up));

		// Apply particle rotation
		float additional_angle = angle + (align_to_velocity == 1 ? vel_angle : 0.0);
		float cos_a = cos(additional_angle);
		float sin_a = sin(additional_angle);
		vec3 rotated_right = billboard_right * cos_a - billboard_up * sin_a;
		vec3 rotated_up = billboard_right * sin_a + billboard_up * cos_a;
		billboard_right = rotated_right;
		billboard_up = rotated_up;

		// Construct final billboard matrix
		mat4 mat_world = mat4(vec4(billboard_right, 0.0), vec4(billboard_up, 0.0), vec4(view_dir, 0.0), _MODEL_MATRIX[3]);

		// Preserve original scale
		mat4 scale_mat = mat4(vec4(length(_MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(_MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(_MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));

		return_modelview_matrix = _VIEW_MATRIX * mat_world * scale_mat;
	}

	// Now we use unmodified UVs for animation
	final_uv = _UV;

	// Animation frames handling
	if  (_COLOR.a > -0.5) {
		float h_frames = particles_anim.x;
		float v_frames = particles_anim.y;
		float particle_total_frames = float(particles_anim.x * particles_anim.y);

		if  (_COLOR.a >= 1.0) {
			// Single row mode
			// Extract row and frame progress
			float row = floor (_COLOR.a);
			float frame_progress = fract (_COLOR.a);

			// Calculate frame within row
			float particle_frame = floor(frame_progress * h_frames);

			// Apply UV transformation
			final_uv /= vec2(h_frames, v_frames);
			final_uv += vec2(
				mod(particle_frame, h_frames) / h_frames,
				row / v_frames
			);
		} else {
			// Whole sheet mode
			float frame = _COLOR.a * particle_total_frames;
			float current_frame = floor(frame);

			// Apply UV transformation
			final_uv /= vec2(h_frames, v_frames);
			final_uv += vec2(
				mod(current_frame, h_frames) / h_frames,
				floor(current_frame / h_frames) / v_frames
			);
		}
	}
	return return_modelview_matrix;
}
