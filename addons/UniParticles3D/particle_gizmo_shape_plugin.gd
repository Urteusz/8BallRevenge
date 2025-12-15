# my_custom_gizmo.gd
extends EditorNode3DGizmoPlugin

#const UniParticles3D = preload("res://addons/UniParticles3D/UniParticles3D.gd")

func _has_gizmo(node):
	return node is UniParticles3D

var done_init:bool = false
func _init():
	create_material("main", Color(0.1, 0.32, 0.64))
	create_handle_material("handles")
	done_init = true

# You can store data in the gizmo itself (more useful when working with handles).
var gizmo_size = 3.0

func _redraw(gizmo):
	gizmo.clear()
	var particle :UniParticles3D = gizmo.get_node_3d()
	if particle == null or (not particle.done_ready) or particle.enable_shape.x == 0:
		return

	# Calculate the transform for the gizmo based on offsets and space settings
	var gizmo_transform := Transform3D()

	# Apply position offset - transform it the same way as in the particle system
	var final_offset = particle.position_offset
	if not particle.use_world_space:
		# Transform offset to local space if needed - gizmo is already in local space
		final_offset = particle.global_transform.basis.inverse() * final_offset
	gizmo_transform.origin = final_offset

	# Apply rotation offset
	var basis = Basis()
	if particle.direction_in_world_space:
		# Apply rotations in world space order
		basis = basis.rotated(Vector3.RIGHT, deg_to_rad(particle.rotation_offset.x))
		basis = basis.rotated(Vector3.UP, deg_to_rad(particle.rotation_offset.y))
		basis = basis.rotated(Vector3.FORWARD, deg_to_rad(particle.rotation_offset.z))
	else:
		# Apply rotations in local space order
		basis = basis.rotated(Vector3.FORWARD, deg_to_rad(particle.rotation_offset.z))
		basis = basis.rotated(Vector3.UP, deg_to_rad(particle.rotation_offset.y))
		basis = basis.rotated(Vector3.RIGHT, deg_to_rad(particle.rotation_offset.x))

	gizmo_transform.basis = basis

	# Draw the appropriate shape
	match particle.shape_type:
		UniParticles3D.EmissionShape.CONE:
			_draw_gizmo_cone(gizmo, particle, gizmo_transform)
		UniParticles3D.EmissionShape.SPHERE:
			_draw_gizmo_sphere(gizmo, particle, gizmo_transform)
		UniParticles3D.EmissionShape.BOX:
			_draw_gizmo_box(gizmo, particle, gizmo_transform)
		UniParticles3D.EmissionShape.CIRCLE:
			_draw_gizmo_circle(gizmo, particle, gizmo_transform)
		UniParticles3D.EmissionShape.EDGE:
			_draw_gizmo_edge(gizmo, particle, gizmo_transform)
		UniParticles3D.EmissionShape.HEMISPHERE:
			_draw_gizmo_hemisphere(gizmo, particle, gizmo_transform)

# Helper function to transform points based on gizmo transform and space settings
func _transform_point(point: Vector3, transform: Transform3D, particle: UniParticles3D) -> Vector3:
	# First apply the shape transform
	var result = transform * point

	if particle.direction_in_world_space:
		# For world space, we need to remove the node's transform since gizmo is already in local space
		result = particle.transform.basis.inverse() * result
	return result

func _draw_gizmo_cone(gizmo, particle: UniParticles3D, transform: Transform3D):
	var lines := PackedVector3Array()
	var height := particle.shape_length
	var radius := particle.radius
	var angle := deg_to_rad(clamp(particle.angle, 0.0, 89.99))
	var arc_degrees := particle.arc_degrees

	# Calculate inner radius based on radius_thickness
	var inner_radius :float = radius * (1.0 - particle.radius_thickness)
	# Inner top radius should converge to center when thickness is 1
	var inner_top_radius :float = (inner_radius + (height * tan(angle)))

	inner_top_radius = lerp(inner_top_radius,  inner_top_radius * (1.0 - particle.radius_thickness), 1.0 - inverse_lerp(0.0,90.0,angle))

	inner_top_radius = max(inner_top_radius,inner_radius)

	# Draw both outer and inner cones
	for cone_radius in [radius, inner_radius]:
		var is_inner :bool= cone_radius == inner_radius
		var top_radius :float = radius + (height * tan(angle)) if not is_inner else inner_top_radius

		# Draw base circle and top circle with arc consideration
		var step := 1  # Degrees per segment
		for i in range(0, arc_degrees + 1, step):
			var radius_a = deg_to_rad(i)
			var radius_b = deg_to_rad(min(i + 1, arc_degrees))
			var point_a = Vector2(cos(radius_a), sin(radius_a)) * cone_radius
			var point_b = Vector2(cos(radius_b), sin(radius_b)) * cone_radius

			var base_a = _transform_point(Vector3(point_a.x, 0, point_a.y), transform, particle)
			var base_b = _transform_point(Vector3(point_b.x, 0, point_b.y), transform, particle)
			lines.push_back(base_a)
			lines.push_back(base_b)

			# Draw top circle
			var top_point_a = Vector2(cos(radius_a), sin(radius_a)) * top_radius
			var top_point_b = Vector2(cos(radius_b), sin(radius_b)) * top_radius

			var top_a = _transform_point(Vector3(top_point_a.x, height, top_point_a.y), transform, particle)
			var top_b = _transform_point(Vector3(top_point_b.x, height, top_point_b.y), transform, particle)
			lines.push_back(top_a)
			lines.push_back(top_b)

			# Draw vertical lines at intervals
			if i % 45 == 0 and i <= arc_degrees:
				lines.push_back(base_a)
				lines.push_back(top_a)

	# If not a full circle, draw lines to close both inner and outer cones
	if arc_degrees < 360:
		for cone_radius in [radius, inner_radius]:
			var top_radius :float = cone_radius + (height * tan(angle))

			# Draw lines at start angle (0 degrees)
			var start_base = _transform_point(Vector3(cone_radius, 0, 0), transform, particle)
			var start_top = _transform_point(Vector3(top_radius, height, 0), transform, particle)
			lines.push_back(start_base)
			lines.push_back(start_top)

			# Draw lines at end angle
			var end_angle = deg_to_rad(arc_degrees)
			var end_base = _transform_point(Vector3(cos(end_angle) * cone_radius, 0, sin(end_angle) * cone_radius), transform, particle)
			var end_top = _transform_point(Vector3(cos(end_angle) * top_radius, height, sin(end_angle) * top_radius), transform, particle)
			lines.push_back(end_base)
			lines.push_back(end_top)

	gizmo.add_lines(lines, get_material("main", gizmo), false)

func _draw_gizmo_sphere(gizmo, particle: UniParticles3D, transform: Transform3D):
	var lines := PackedVector3Array()
	var outer_radius := particle.radius
	var inner_radius := particle.radius * (1.0 - particle.radius_thickness)
	var arc_degrees := particle.arc_degrees

	# Draw both outer and inner spheres
	for radius in [outer_radius, inner_radius]:
		for plane in range(3):
			for i in range(0, arc_degrees + 1):
				var angle_a = deg_to_rad(i)
				var angle_b = deg_to_rad(min(i + 1, arc_degrees))
				var point_a: Vector3
				var point_b: Vector3

				match plane:
					0: # XY plane
						point_a = Vector3(radius * cos(angle_a), radius * sin(angle_a), 0)
						point_b = Vector3(radius * cos(angle_b), radius * sin(angle_b), 0)
					1: # XZ plane
						point_a = Vector3(radius * cos(angle_a), 0, radius * sin(angle_a))
						point_b = Vector3(radius * cos(angle_b), 0, radius * sin(angle_b))
					2: # YZ plane
						point_a = Vector3(0, radius * cos(angle_a), radius * sin(angle_a))
						point_b = Vector3(0, radius * cos(angle_b), radius * sin(angle_b))

				lines.push_back(_transform_point(point_a, transform, particle))
				lines.push_back(_transform_point(point_b, transform, particle))

	# Add connecting lines between inner and outer spheres
	for i in range(0, arc_degrees + 1, 45):
		var angle = deg_to_rad(min(i, arc_degrees))
		# XY plane connections
		lines.push_back(_transform_point(Vector3(outer_radius * cos(angle), outer_radius * sin(angle), 0), transform, particle))
		lines.push_back(_transform_point(Vector3(inner_radius * cos(angle), inner_radius * sin(angle), 0), transform, particle))
		# XZ plane connections
		lines.push_back(_transform_point(Vector3(outer_radius * cos(angle), 0, outer_radius * sin(angle)), transform, particle))
		lines.push_back(_transform_point(Vector3(inner_radius * cos(angle), 0, inner_radius * sin(angle)), transform, particle))
		# YZ plane connections
		lines.push_back(_transform_point(Vector3(0, outer_radius * cos(angle), outer_radius * sin(angle)), transform, particle))
		lines.push_back(_transform_point(Vector3(0, inner_radius * cos(angle), inner_radius * sin(angle)), transform, particle))

	# If not a full circle, draw lines to close the arcs
	if arc_degrees < 360:
		for radius in [outer_radius, inner_radius]:
			# Draw closing lines for each plane
			var start_angle = 0
			var end_angle = deg_to_rad(arc_degrees)

			# XY plane
			lines.push_back(_transform_point(Vector3(radius * cos(start_angle), radius * sin(start_angle), 0), transform, particle))
			lines.push_back(_transform_point(Vector3(0, 0, 0), transform, particle))
			lines.push_back(_transform_point(Vector3(radius * cos(end_angle), radius * sin(end_angle), 0), transform, particle))
			lines.push_back(_transform_point(Vector3(0, 0, 0), transform, particle))

			# XZ plane
			lines.push_back(_transform_point(Vector3(radius * cos(start_angle), 0, radius * sin(start_angle)), transform, particle))
			lines.push_back(_transform_point(Vector3(0, 0, 0), transform, particle))
			lines.push_back(_transform_point(Vector3(radius * cos(end_angle), 0, radius * sin(end_angle)), transform, particle))
			lines.push_back(_transform_point(Vector3(0, 0, 0), transform, particle))

			# YZ plane
			lines.push_back(_transform_point(Vector3(0, radius * cos(start_angle), radius * sin(start_angle)), transform, particle))
			lines.push_back(_transform_point(Vector3(0, 0, 0), transform, particle))
			lines.push_back(_transform_point(Vector3(0, radius * cos(end_angle), radius * sin(end_angle)), transform, particle))
			lines.push_back(_transform_point(Vector3(0, 0, 0), transform, particle))

	gizmo.add_lines(lines, get_material("main", gizmo), false)

func _draw_gizmo_box(gizmo, particle: UniParticles3D, transform: Transform3D):
	var lines := PackedVector3Array()
	var extents:Vector3 = particle.box_extents

	# Bottom face
	lines.append_array([
		_transform_point(Vector3(-extents.x, -extents.y, -extents.z), transform, particle),
		_transform_point(Vector3(extents.x, -extents.y, -extents.z), transform, particle),
		_transform_point(Vector3(extents.x, -extents.y, -extents.z), transform, particle),
		_transform_point(Vector3(extents.x, -extents.y, extents.z), transform, particle),
		_transform_point(Vector3(extents.x, -extents.y, extents.z), transform, particle),
		_transform_point(Vector3(-extents.x, -extents.y, extents.z), transform, particle),
		_transform_point(Vector3(-extents.x, -extents.y, extents.z), transform, particle),
		_transform_point(Vector3(-extents.x, -extents.y, -extents.z), transform, particle)
	])

	# Top face
	lines.append_array([
		_transform_point(Vector3(-extents.x, extents.y, -extents.z), transform, particle),
		_transform_point(Vector3(extents.x, extents.y, -extents.z), transform, particle),
		_transform_point(Vector3(extents.x, extents.y, -extents.z), transform, particle),
		_transform_point(Vector3(extents.x, extents.y, extents.z), transform, particle),
		_transform_point(Vector3(extents.x, extents.y, extents.z), transform, particle),
		_transform_point(Vector3(-extents.x, extents.y, extents.z), transform, particle),
		_transform_point(Vector3(-extents.x, extents.y, extents.z), transform, particle),
		_transform_point(Vector3(-extents.x, extents.y, -extents.z), transform, particle)
	])

	# Vertical edges
	lines.append_array([
		_transform_point(Vector3(-extents.x, -extents.y, -extents.z), transform, particle),
		_transform_point(Vector3(-extents.x, extents.y, -extents.z), transform, particle),
		_transform_point(Vector3(extents.x, -extents.y, -extents.z), transform, particle),
		_transform_point(Vector3(extents.x, extents.y, -extents.z), transform, particle),
		_transform_point(Vector3(extents.x, -extents.y, extents.z), transform, particle),
		_transform_point(Vector3(extents.x, extents.y, extents.z), transform, particle),
		_transform_point(Vector3(-extents.x, -extents.y, extents.z), transform, particle),
		_transform_point(Vector3(-extents.x, extents.y, extents.z), transform, particle)
	])

	gizmo.add_lines(lines, get_material("main", gizmo), false)

func _draw_gizmo_circle(gizmo, particle: UniParticles3D, transform: Transform3D):
	var lines := PackedVector3Array()
	var outer_radius := particle.radius
	var inner_radius := particle.radius * (1.0 - particle.radius_thickness)
	var arc_degrees := particle.arc_degrees

	# Draw outer and inner arcs
	for i in range(0, arc_degrees + 1):
		var angle_a = deg_to_rad(i)
		var angle_b = deg_to_rad(min(i + 1, arc_degrees))

		# Draw outer arc
		lines.push_back(_transform_point(Vector3(outer_radius * cos(angle_a), 0, outer_radius * sin(angle_a)), transform, particle))
		lines.push_back(_transform_point(Vector3(outer_radius * cos(angle_b), 0, outer_radius * sin(angle_b)), transform, particle))

		# Draw inner arc
		lines.push_back(_transform_point(Vector3(inner_radius * cos(angle_a), 0, inner_radius * sin(angle_a)), transform, particle))
		lines.push_back(_transform_point(Vector3(inner_radius * cos(angle_b), 0, inner_radius * sin(angle_b)), transform, particle))

	# Draw connecting lines at intervals
	for i in range(0, arc_degrees + 1, 45):
		var angle = deg_to_rad(min(i, arc_degrees))
		lines.push_back(_transform_point(Vector3(inner_radius * cos(angle), 0, inner_radius * sin(angle)), transform, particle))
		lines.push_back(_transform_point(Vector3(outer_radius * cos(angle), 0, outer_radius * sin(angle)), transform, particle))

	# If not a full circle, draw lines to center
	if arc_degrees < 360:
		# Draw lines from center to start and end of both inner and outer arcs
		var start_angle = 0
		var end_angle = deg_to_rad(arc_degrees)

		for r in [inner_radius, outer_radius]:
			lines.push_back(_transform_point(Vector3(0, 0, 0), transform, particle))
			lines.push_back(_transform_point(Vector3(r * cos(start_angle), 0, r * sin(start_angle)), transform, particle))
			lines.push_back(_transform_point(Vector3(0, 0, 0), transform, particle))
			lines.push_back(_transform_point(Vector3(r * cos(end_angle), 0, r * sin(end_angle)), transform, particle))

	gizmo.add_lines(lines, get_material("main", gizmo), false)

func _draw_gizmo_edge(gizmo, particle: UniParticles3D, transform: Transform3D):
	var lines := PackedVector3Array()
	var length := particle.radius

	# Draw main line
	lines.push_back(_transform_point(Vector3(0, -length, 0), transform, particle))
	lines.push_back(_transform_point(Vector3(0, length, 0), transform, particle))

	# Draw small cross lines at ends and middle
	var cross_size := length * 0.1
	lines.append_array([
		_transform_point(Vector3(-cross_size, -length, 0), transform, particle),
		_transform_point(Vector3(cross_size, -length, 0), transform, particle),
		_transform_point(Vector3(0, -length, -cross_size), transform, particle),
		_transform_point(Vector3(0, -length, cross_size), transform, particle),
		_transform_point(Vector3(-cross_size, length, 0), transform, particle),
		_transform_point(Vector3(cross_size, length, 0), transform, particle),
		_transform_point(Vector3(0, length, -cross_size), transform, particle),
		_transform_point(Vector3(0, length, cross_size), transform, particle),
		_transform_point(Vector3(-cross_size, 0, 0), transform, particle),
		_transform_point(Vector3(cross_size, 0, 0), transform, particle),
		_transform_point(Vector3(0, 0, -cross_size), transform, particle),
		_transform_point(Vector3(0, 0, cross_size), transform, particle)
	])

	gizmo.add_lines(lines, get_material("main", gizmo), false)

func _draw_gizmo_hemisphere(gizmo, particle: UniParticles3D, transform: Transform3D):
	var lines := PackedVector3Array()
	var outer_radius := particle.radius
	var inner_radius := particle.radius * (1.0 - particle.radius_thickness)
	var arc_degrees := particle.arc_degrees

	# Draw both outer and inner hemispheres
	for radius in [outer_radius, inner_radius]:
		# Draw horizontal arcs at different heights
		for height_step in range(0, 91, 15):  # Draw arcs every 15 degrees
			var height_angle = deg_to_rad(height_step)
			var circle_radius = radius * sin(height_angle)
			var y = radius * cos(height_angle)

			for i in range(0, arc_degrees + 1):
				var angle_a = deg_to_rad(i)
				var angle_b = deg_to_rad(min(i + 1, arc_degrees))

				var point_a = Vector3(circle_radius * cos(angle_a), y, circle_radius * sin(angle_a))
				var point_b = Vector3(circle_radius * cos(angle_b), y, circle_radius * sin(angle_b))

				lines.push_back(_transform_point(point_a, transform, particle))
				lines.push_back(_transform_point(point_b, transform, particle))

		# Draw vertical arcs
		for i in range(0, arc_degrees + 1, 45):
			var angle = deg_to_rad(min(i, arc_degrees))
			var steps = 16
			for step in range(steps):
				var t1 = float(step) / steps
				var t2 = float(step + 1) / steps
				var height_angle1 = t1 * PI/2  # Only go up to PI/2 for hemisphere
				var height_angle2 = t2 * PI/2

				var point_a = Vector3(
					radius * sin(height_angle1) * cos(angle),
					radius * cos(height_angle1),
					radius * sin(height_angle1) * sin(angle)
				)
				var point_b = Vector3(
					radius * sin(height_angle2) * cos(angle),
					radius * cos(height_angle2),
					radius * sin(height_angle2) * sin(angle)
				)

				lines.push_back(_transform_point(point_a, transform, particle))
				lines.push_back(_transform_point(point_b, transform, particle))

	# Draw base circle for both radii
	for radius in [outer_radius, inner_radius]:
		for i in range(0, arc_degrees + 1):
			var angle_a = deg_to_rad(i)
			var angle_b = deg_to_rad(min(i + 1, arc_degrees))

			var point_a = Vector3(radius * cos(angle_a), 0, radius * sin(angle_a))
			var point_b = Vector3(radius * cos(angle_b), 0, radius * sin(angle_b))

			lines.push_back(_transform_point(point_a, transform, particle))
			lines.push_back(_transform_point(point_b, transform, particle))

	# If not a full circle, draw lines to center and top
	if arc_degrees < 360:
		for radius in [outer_radius, inner_radius]:
			var start_angle = 0
			var end_angle = deg_to_rad(arc_degrees)

			# Lines to center at base
			lines.push_back(_transform_point(Vector3(0, 0, 0), transform, particle))
			lines.push_back(_transform_point(Vector3(radius * cos(start_angle), 0, radius * sin(start_angle)), transform, particle))
			lines.push_back(_transform_point(Vector3(0, 0, 0), transform, particle))
			lines.push_back(_transform_point(Vector3(radius * cos(end_angle), 0, radius * sin(end_angle)), transform, particle))

			# Lines to top
			lines.push_back(_transform_point(Vector3(0, radius, 0), transform, particle))
			lines.push_back(_transform_point(Vector3(radius * cos(start_angle), 0, radius * sin(start_angle)), transform, particle))
			lines.push_back(_transform_point(Vector3(0, radius, 0), transform, particle))
			lines.push_back(_transform_point(Vector3(radius * cos(end_angle), 0, radius * sin(end_angle)), transform, particle))

	gizmo.add_lines(lines, get_material("main", gizmo), false)

func _get_gizmo_name():
	return "UniParticles3DGizmo"

func _get_handle_name(gizmo, handle_id, secondary):
	return "UniParticles3DGizmo"
