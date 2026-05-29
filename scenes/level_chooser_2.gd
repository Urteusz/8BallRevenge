extends Node3D

class SimulatedBody:
	var multimesh_instance: MultiMeshInstance3D
	var instance_id: int
	var current_position: Vector3 = Vector3.ZERO
	var current_scale: float = 1.0
	var orbit_speed: float
	var rotation_speed: float
	var distance_from_pivot: float
	var current_orbit_angle: float = 0.0
	var current_spin_angle: float = 0.0
	var inclination_basis: Basis = Basis.IDENTITY
	var parent_body: SimulatedBody = null 

class PlanetBlueprint:
	var ball_data: Resource
	var scale: float
	var distance: float
	var moons: Array[PlanetBlueprint] = [] 
	var orbit_speed: float
	var rotation_speed: float
	var inclination_basis: Basis

@export_group("Level Chooser Settings")
@export var camera_speed: float = 10.0
@export var level_spacing: float = 10.0
@export var level_path: String = "res://scenes/levels/level%d/level%d.tscn"

@export_group("Hold Settings")
@export var hold_time_required: float = 1.0
@export var hold_delay: float = 0.15 

@export_group("Background Setup")
@export var world_env: WorldEnvironment 
@export var level_colors: Array[Color]

@export_group("Controller Debounce")
@export var menu_scroll_delay: float = 0.3

@export_group("Universe General Settings")
@export var target_planet_count: int = 2000 
@export var max_draw_distance: float = 1.4 
@export var base_orbit_speed: float = 0.3
@export var base_rotation_speed: float = 0.5

@export_group("Universe Visuals")
@export var draw_planet_orbits: bool = true
@export var draw_moon_orbits: bool = true 
@export var orbit_color: Color = Color(1, 1, 1, 0.4) 
@export var min_emission_energy: float = 0.5 
@export var max_emission_energy: float = 4.0 

@export_group("Universe Starfield")
@export var star_count: int = 8000
@export var star_distance_min: float = 1.45
@export var star_distance_max: float = 1.5
@export var star_base_size: float = 0.004

@export_group("Universe Planet Spawning")
@export var min_start_distance: float = 0.02 
@export var min_gap: float = 0.002 
@export var max_gap: float = 0.008 
@export var min_scale: float = 0.002 
@export var max_scale: float = 0.01

@export_group("Universe Moon Settings")
@export_range(0.0, 1.0) var moon_chance: float = 0.5 
@export var max_moons_per_planet: int = 4 
@export var moon_min_scale_mult: float = 0.1 
@export var moon_max_scale_mult: float = 0.25
@export var moon_orbit_speed_mult: float = 2.0 

@onready var camera: Camera3D = $Camera3D
@onready var progress_quad: MeshInstance3D = $ProgressQuad

var levels: Array[Node3D] = []
var base_scales: Dictionary = {}
var current_level_index: int = 0
var target_camera_z: float = 0.0 

var is_mouse_pressed: bool = false
var current_mouse_pos: Vector2 = Vector2.ZERO
var hold_progress: float = 0.0
var held_level_index: int = -1

var bg_tween: Tween
var current_scroll_cooldown: float = 0.0

var _multimesh_map: Dictionary = {}
var _multimesh_fill_cursor: Dictionary = {}
var _simulated_bodies: Array[SimulatedBody] = []
var _starfield_node: MultiMeshInstance3D = null
var universe_root: Node3D

func _ready() -> void:
	if progress_quad:
		progress_quad.visible = false

	var i: int = 1
	while true:
		var level_node = get_node_or_null("Level" + str(i))
		if level_node:
			levels.append(level_node)
			base_scales[level_node] = level_node.scale
			level_node.position.z = -(i - 1) * level_spacing 
			i += 1
		else:
			break
			
	if camera:
		target_camera_z = camera.position.z 
		
	if world_env and not level_colors.is_empty():
		if world_env.environment and world_env.environment.sky:
			var sky_mat = world_env.environment.sky.sky_material as ShaderMaterial
			if sky_mat:
				sky_mat.set_shader_parameter("color_new", level_colors[0])
				sky_mat.set_shader_parameter("color_old", level_colors[0])
				sky_mat.set_shader_parameter("progress", 1.0)
		else:
			push_warning("WorldEnvironment has no Environment or Sky setup!")
			
	_update_level_focus()

	universe_root = Node3D.new()
	universe_root.name = "UniverseRoot"
	add_child(universe_root)
	
	_multimesh_map.clear()
	_multimesh_fill_cursor.clear()
	_simulated_bodies.clear()
	_starfield_node = null
	
	_build_starfield() 
	_build_universe()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)

	if event.is_action_pressed("ui_accept"):
		is_mouse_pressed = true
		held_level_index = current_level_index
	elif event.is_action_released("ui_accept") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_mouse_pressed = false
		
	if event is InputEventMouseMotion:
		current_mouse_pos = event.position

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			is_mouse_pressed = true
			current_mouse_pos = event.position
		else:
			is_mouse_pressed = false

func _process(delta: float) -> void:
	if not camera or levels.is_empty():
		return
		
	camera.position.z = lerp(camera.position.z, target_camera_z, camera_speed * delta) 

	var move_dir = 0
	if Input.get_action_strength("ui_right") > 0.5 or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_D):
		move_dir = 1
	elif Input.get_action_strength("ui_left") > 0.5 or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		move_dir = -1

	if current_scroll_cooldown > 0.0:
		current_scroll_cooldown -= delta
		if move_dir == 0:
			current_scroll_cooldown = 0.0
	elif move_dir != 0:
		_move_selection(move_dir)
		current_scroll_cooldown = menu_scroll_delay

	if is_mouse_pressed:
		var hovered_index = held_level_index if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else _get_hovered_level(current_mouse_pos)
		if hovered_index != -1:
			if held_level_index != hovered_index:
				_reset_hold()
				held_level_index = hovered_index

			hold_progress += delta
			
			if hold_progress > hold_delay:
				var active_hold = hold_progress - hold_delay
				var ratio = clamp(active_hold / hold_time_required, 0.0, 1.0)

				var lvl = levels[held_level_index]
				var base = base_scales.get(lvl, Vector3.ONE)
				lvl.scale = base.lerp(base + Vector3(0.2, 0.2, 0.2), ratio)

				if progress_quad:
					progress_quad.visible = true
					progress_quad.global_position = lvl.global_position
					var mat = progress_quad.get_active_material(0)
					if mat is ShaderMaterial:
						mat.set_shader_parameter("progress", ratio)
						
						if held_level_index < level_colors.size():
							var base_color = level_colors[held_level_index]
							var quad_color = Color(base_color.r * 2.4, base_color.g * 2.4, base_color.b * 2.4, 0.2)
							mat.set_shader_parameter("color", quad_color)

				if active_hold >= hold_time_required:
					is_mouse_pressed = false
					_enter_level(held_level_index + 1)
		else:
			_reset_hold()
	else:
		_reset_hold()

	_process_universe(delta)

func _process_universe(delta: float) -> void:
	var is_universe_visible = false
	if current_level_index < levels.size():
		var parsed_lvl = levels[current_level_index].name.trim_prefix("Level").to_int()
		if parsed_lvl >= 5:
			is_universe_visible = true

	if universe_root:
		universe_root.visible = is_universe_visible

	if not is_universe_visible:
		return

	if _starfield_node and camera:
		_starfield_node.global_position = camera.global_position

	for body in _simulated_bodies:
		body.current_orbit_angle += body.orbit_speed * delta
		body.current_spin_angle += body.rotation_speed * delta
		
		var flat_pos = Vector3(cos(body.current_orbit_angle), 0, sin(body.current_orbit_angle)) * body.distance_from_pivot
		var tilted_pos = body.inclination_basis * flat_pos
		
		if body.parent_body == null:
			body.current_position = tilted_pos
		else:
			body.current_position = body.parent_body.current_position + tilted_pos
		
		var spin_basis = Basis(Vector3.UP, body.current_spin_angle)
		var scaled_spin = spin_basis.scaled(Vector3.ONE * body.current_scale)
		var final_basis = body.inclination_basis * scaled_spin
		
		var final_transform = Transform3D(final_basis, body.current_position)
		
		var offset_transform = final_transform
		offset_transform.origin += camera.global_position
		body.multimesh_instance.multimesh.set_instance_transform(body.instance_id, offset_transform)
		
	if draw_moon_orbits:
		_update_moon_orbit_positions()

func _reset_hold() -> void:
	if held_level_index != -1:
		var lvl = levels[held_level_index]
		var base = base_scales.get(lvl, Vector3.ONE)
		
		var tween = create_tween()
		tween.tween_property(lvl, "scale", base, 0.2)
		
		held_level_index = -1

	hold_progress = 0.0
	if progress_quad:
		progress_quad.visible = false
		var mat = progress_quad.get_active_material(0)
		if mat is ShaderMaterial:
			mat.set_shader_parameter("progress", 0.0)

func _move_selection(direction: int) -> void:
	if levels.is_empty(): 
		return
	
	var new_index = clamp(current_level_index + direction, 0, levels.size() - 1)
	if new_index == current_level_index:
		return 
		
	current_level_index = new_index
	
	if camera:
		target_camera_z = levels[current_level_index].position.z 
		
	_transition_background(current_level_index)
	_update_level_focus()

func _update_level_focus() -> void:
	for i in range(levels.size()):
		if levels[i].has_method("set"):
			levels[i].is_currently_focused = (i == current_level_index)

func _transition_background(to_index: int) -> void:
	if not world_env or level_colors.is_empty(): 
		return
		
	var sky_mat = world_env.environment.sky.sky_material as ShaderMaterial
	if not sky_mat:
		return
		
	var current_color = sky_mat.get_shader_parameter("color_new")
	sky_mat.set_shader_parameter("color_old", current_color)
	
	var target_color = level_colors[min(to_index, level_colors.size() - 1)]
	sky_mat.set_shader_parameter("color_new", target_color)
	
	sky_mat.set_shader_parameter("progress", 0.0)
	
	if bg_tween:
		bg_tween.kill()
		
	bg_tween = create_tween()
	bg_tween.tween_method(func(v): sky_mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.6)

func _get_hovered_level(mouse_pos: Vector2) -> int:
	if levels.is_empty() or not camera: 
		return -1
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	for i in range(levels.size()):
		var lvl = levels[i]
		var center = lvl.global_position
		var radius = 1.0
		
		if lvl is MeshInstance3D and lvl.mesh:
			radius = lvl.mesh.get_aabb().size.length() * 0.5 * base_scales.get(lvl, Vector3.ONE).x
			
		var l = center - ray_origin
		var tca = l.dot(ray_dir)
		if tca < 0.0:
			continue
			
		var d2 = l.dot(l) - tca * tca
		if d2 <= radius * radius:
			return i
			
	return -1

func _enter_level(level_number: int) -> void:
	var path = level_path % [level_number, level_number]
	if ResourceLoader.exists(path):
		LoadManager.load_scene(path)

func _build_starfield() -> void:
	var mat = StandardMaterial3D.new()
	mat.render_priority = 1
	mat.no_depth_test = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(star_base_size, star_base_size)
	
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true 
	mm.mesh = mesh
	mm.instance_count = star_count
	
	for i in range(star_count):
		var theta = randf() * TAU
		var phi = acos(2.0 * randf() - 1.0)
		var dist = randf_range(star_distance_min, star_distance_max)
		
		var pos = Vector3(
			sin(phi) * cos(theta),
			sin(phi) * sin(theta),
			cos(phi)
		) * dist
		
		var t = Transform3D(Basis.IDENTITY, pos)
		mm.set_instance_transform(i, t)
		
		var brightness = randf_range(0.3, 1.0)
		var col = Color(brightness, brightness, brightness, 1.0)
		if randf() > 0.8:
			col = col.lerp(Color(0.6, 0.8, 1.0), 0.5)
			
		mm.set_instance_color(i, col)
		
	_starfield_node = MultiMeshInstance3D.new()
	_starfield_node.multimesh = mm
	_starfield_node.material_override = mat
	_starfield_node.name = "StarField"
	_starfield_node.custom_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	
	universe_root.add_child(_starfield_node)

func _build_universe() -> void:
	var valid_deck = _scan_deck_for_valid_balls(PlayerData.current_deck)
	if valid_deck.is_empty(): return
	
	var blueprints: Array[PlanetBlueprint] = []
	var resource_counts: Dictionary = {} 
	
	var current_boundary = min_start_distance
	
	for i in range(target_planet_count):
		var ball_data = valid_deck.pick_random()
		var random_scale = randf_range(min_scale, max_scale)
		
		var p_bp = PlanetBlueprint.new()
		p_bp.ball_data = ball_data
		p_bp.scale = random_scale
		
		if randf() < moon_chance:
			for m in range(randi_range(1, 2)): 
				_add_moon_to_blueprint(p_bp, valid_deck, resource_counts)
		
		var system_radius = p_bp.scale * 0.5 
		for moon in p_bp.moons:
			var moon_extent = moon.distance + (moon.scale * 0.5) 
			if moon_extent > system_radius:
				system_radius = moon_extent
		
		var proposed_center_dist = current_boundary + system_radius
		
		if (proposed_center_dist + system_radius) > max_draw_distance:
			break 
			
		p_bp.distance = proposed_center_dist
		current_boundary = proposed_center_dist + system_radius + randf_range(min_gap, max_gap)
		
		p_bp.orbit_speed = (base_orbit_speed * randf_range(0.8, 1.2) * (1 if i % 2 == 0 else -1)) / (1.0 + (i * 0.05))
		p_bp.rotation_speed = base_rotation_speed * randf_range(0.8, 1.2)
		
		var tilt_axis = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		p_bp.inclination_basis = Basis(tilt_axis, randf_range(-0.4, 0.4))
		
		if not resource_counts.has(ball_data): resource_counts[ball_data] = 0
		resource_counts[ball_data] += 1
		
		blueprints.append(p_bp)
	
	_allocate_multimeshes(resource_counts)
	if draw_planet_orbits: _generate_static_planet_orbits(blueprints)
		
	for bp in blueprints:
		var p_body = _create_simulated_body(bp)
		if draw_moon_orbits and not bp.moons.is_empty():
			var helper = Node3D.new()
			universe_root.add_child(helper)
			helper.name = "MoonOrbitHolder"
			helper.set_meta("linked_body", p_body)
			for moon_bp in bp.moons:
				_create_simulated_body(moon_bp).parent_body = p_body
				
				var fade = clamp(1.0 - (bp.distance / max_draw_distance), 0.0, 1.0)
				var moon_orbit_col = orbit_color * fade
				helper.add_child(_create_torus_ring(moon_bp.distance, moon_orbit_col, moon_bp.inclination_basis))

func _update_moon_orbit_positions() -> void:
	for child in universe_root.get_children():
		if child.has_meta("linked_body"):
			child.position = child.get_meta("linked_body").current_position
			if camera:
				child.position += camera.global_position

func _add_moon_to_blueprint(parent_bp: PlanetBlueprint, deck: Array, counts: Dictionary) -> void:
	if parent_bp.moons.size() >= max_moons_per_planet: return
	var moon_data = deck.pick_random()
	var m_bp = PlanetBlueprint.new()
	m_bp.ball_data = moon_data
	var p_rad = parent_bp.scale * 0.5
	m_bp.scale = parent_bp.scale * randf_range(moon_min_scale_mult, moon_max_scale_mult)
	
	var base_dist = p_rad * 1.6
	if not parent_bp.moons.is_empty():
		var last = parent_bp.moons.back()
		base_dist = last.distance + (last.scale * 0.6) + (m_bp.scale * 0.6)
		
	m_bp.distance = base_dist
	m_bp.orbit_speed = base_orbit_speed * moon_orbit_speed_mult * randf_range(0.9, 1.1)
	m_bp.rotation_speed = base_rotation_speed * randf_range(1.0, 3.0)
	m_bp.inclination_basis = Basis(Vector3(randf(), 0, randf()).normalized(), randf_range(-0.6, 0.6))
	
	if not counts.has(moon_data): counts[moon_data] = 0
	counts[moon_data] += 1
	parent_bp.moons.append(m_bp)

func _generate_static_planet_orbits(blueprints: Array) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var mat = StandardMaterial3D.new()
	mat.render_priority = 1
	mat.no_depth_test = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	
	for bp in blueprints:
		var fade = clamp(1.0 - (bp.distance / max_draw_distance), 0.0, 1.0)
		var final_ring_color = orbit_color * fade
		st.set_color(final_ring_color)
		
		var segments = clampi(int(bp.distance * 300.0), 64, 256)
		for i in range(segments):
			var t1 = (float(i) / segments) * TAU
			var t2 = (float(i + 1) / segments) * TAU
			st.add_vertex(bp.inclination_basis * (Vector3(cos(t1), 0, sin(t1)) * bp.distance))
			st.add_vertex(bp.inclination_basis * (Vector3(cos(t2), 0, sin(t2)) * bp.distance))

	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	
	var holder = Node3D.new()
	holder.name = "PlanetOrbitHolder"
	holder.add_child(mi)
	universe_root.add_child(holder)

func _create_torus_ring(radius: float, color: Color, tilt: Basis) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var mesh = TorusMesh.new()
	var thickness = clamp(radius * 0.02, 0.0005, 0.005)
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius
	mesh.ring_segments = 4
	mesh.rings = 32
	
	var mat = StandardMaterial3D.new()
	mat.render_priority = 1
	mat.no_depth_test = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform.basis = tilt
	return mi

func _scan_deck_for_valid_balls(raw_deck: Array) -> Array:
	var valid = []
	for ball_data in raw_deck:
		if not ball_data or not ball_data.get("scene"): continue
		if "bomb" in ball_data.resource_path.to_lower(): continue
		var temp = ball_data.scene.instantiate()
		if _find_first_mesh(temp): valid.append(ball_data)
		temp.free()
	return valid

func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var res = _find_first_mesh(child)
		if res: return res
	return null

func _allocate_multimeshes(counts: Dictionary) -> void:
	for ball_data in counts:
		var temp = ball_data.scene.instantiate()
		var mesh_res = _find_first_mesh(temp).mesh
		var mat = null
		if ball_data.get("texture"):
			mat = StandardMaterial3D.new()
			mat.render_priority = 1
			mat.no_depth_test = true
			mat.albedo_texture = ball_data.texture
			mat.emission_enabled = true
			mat.emission_texture = ball_data.texture
			mat.emission_energy_multiplier = randf_range(min_emission_energy, max_emission_energy)
		else:
			var orig_mat = _find_first_mesh(temp).get_active_material(0)
			if orig_mat:
				mat = orig_mat.duplicate()
				mat.render_priority = 1
				mat.no_depth_test = true
		
		temp.free()
		var mm_inst = MultiMeshInstance3D.new()
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh_res
		mm.instance_count = counts[ball_data]
		mm_inst.multimesh = mm
		mm_inst.material_override = mat
		universe_root.add_child(mm_inst)
		_multimesh_map[ball_data] = mm_inst
		_multimesh_fill_cursor[ball_data] = 0

func _create_simulated_body(bp: PlanetBlueprint) -> SimulatedBody:
	var body = SimulatedBody.new()
	body.multimesh_instance = _multimesh_map[bp.ball_data]
	body.instance_id = _multimesh_fill_cursor[bp.ball_data]
	_multimesh_fill_cursor[bp.ball_data] += 1
	
	body.current_scale = bp.scale
	body.distance_from_pivot = bp.distance
	body.orbit_speed = bp.orbit_speed
	body.rotation_speed = bp.rotation_speed
	body.inclination_basis = bp.inclination_basis
	body.current_orbit_angle = randf() * TAU
	
	_simulated_bodies.append(body)
	return body
