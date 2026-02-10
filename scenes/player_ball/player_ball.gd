extends BallParent

# Progi prędkości dla możliwości strzelania
const SHOOTABLE_VELOCITY_THRESHOLD: float = 3.0
const SHOOTABLE_ANGULAR_THRESHOLD: float = 2.0

# Minimalna prędkość po której uznajemy, że kula CAŁKOWICIE stoi
const FULL_STOP_THRESHOLD: float = 0.1
const FULL_STOP_ANGULAR_THRESHOLD: float = 0.15

# Stałe uderzenia
const MIN_IMPULSE: float = 0.2

# Stałe paska mocy
const POWER_BAR_HEIGHT: float = 1.5
const POWER_BAR_WIDTH: float = 0.18
const POWER_BAR_DEPTH: float = 0.02
const MARKER_WIDTH: float = 0.28
const MARKER_HEIGHT: float = 0.045
const POWER_BAR_OFFSET_RIGHT: float = 1.0
const POWER_BAR_CYCLE_SPEED: float = 1.4  # sekundy na pełny cykl 0→1→0
const FRAME_THICKNESS: float = 0.035
const TICK_COUNT: int = 4  # kreski podziałki (20%, 40%, 60%, 80%)
const TICK_HEIGHT: float = 0.012
const TICK_OUTLINE: float = 0.006

# Stałe fizyki podkręcania
const SPIN_CURVE_FORCE: float = 4.5
const SPIN_DECAY: float = 0.4
const SPIN_TORQUE_MULT: float = 0.015
const VERTICAL_SPIN_FORCE: float = 3.0
const ROLLING_RESISTANCE_FACTOR: float = 0.15

# Ustawienia uderzenia
@export var max_charge_duration: float = 1.5
@export var max_impulse_strength: float = 4.0

# Ustawienia podkręcenia
@export var max_spin_offset: float = 0.7 
@export var spin_change_speed: float = 1.8 
@export var spin_indicator_max_offset_visual: float = 0.5

# Kolory paska mocy
@export var weak_charge_color := Color(0.1, 1.0, 0.2, 0.95)
@export var medium_charge_color := Color(1.0, 1.0, 0.0, 0.95)
@export var strong_charge_color := Color(1.0, 0.1, 0.0, 0.95)

# Długość lini pomocniczej
@export var aim_line_ray_range: float = 20.0

# Ścieżki
@onready var collision_shape := $CollisionShape3D
@onready var ball_radius: float = get_ball_radius()
@onready var aim_line: MeshInstance3D = null
@onready var audioStream = $AudioStreamPlayer3D

var camera: Camera3D = null

# Pasek mocy
var power_bar_root: Node3D = null
var power_bar_bg: MeshInstance3D = null
var power_bar_marker: MeshInstance3D = null
var marker_material: ShaderMaterial = null
var current_power_ratio: float = 0.0
var charging: bool = false
var charge_timer: float = 0.0
var hit_position: Vector3
var aimed_at_ball: BallParent = null
var is_grounded: bool = false
var can_shoot_flag: bool = true

# Zmienne podkręcenia
var spin_factor: float = 0.0
var vertical_spin_factor: float = 0.0
var spin_active: bool = false

# Sygnały
signal ball_pushed(impulse_power: float)
signal charging_cancelled
signal turn_started
signal shoot_requested

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	ball_radius = get_ball_radius()

	if not camera:
		push_error("Error: No camera found.")
		set_process(false)
		return

	_create_power_bar()
	create_aim_line_mesh()
	sleeping = true

func _process(delta: float) -> void:
	if charging and camera and power_bar_root:
		_animate_power_bar(delta)
	
	_check_ground_contact()
	
	if camera.is_looking_at_player() and (can_shoot() or charging):
		_setup_aim_line()
	else:
		_clear_aim_line()
	
	if spin_active:
		spin_factor = move_toward(spin_factor, 0.0, SPIN_DECAY * delta)
		vertical_spin_factor = move_toward(vertical_spin_factor, 0.0, SPIN_DECAY * delta)
		if is_equal_approx(spin_factor, 0.0) and is_equal_approx(vertical_spin_factor, 0.0):
			spin_active = false

func _input(event) -> void:
	if !is_inside_tree():
		return
		
	if charging:
		if event.is_action_pressed("cancel_charging"):
			if power_bar_root:
				power_bar_root.visible = false
			charging = false
			charge_timer = 0.0
			current_power_ratio = 0.0
			emit_signal("charging_cancelled")

	if event.is_action_pressed("push_ball") and can_shoot():
		start_charging()
	elif event.is_action_released("push_ball"):
		if charging:
			emit_signal("shoot_requested")

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if sleeping:
		return

	var lv = state.linear_velocity
	var speed = lv.length()
	var angular_speed = angular_velocity.length()

	# Automatyczne zatrzymanie przy bardzo niskich prędkościach
	if speed < FULL_STOP_THRESHOLD and angular_speed < FULL_STOP_ANGULAR_THRESHOLD:
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		return

	# Spin effects
	if spin_active and speed > 0.5:
		var forward_dir = lv.normalized()
		var curve_dir = lv.cross(Vector3.UP).normalized()
		state.apply_central_force(-curve_dir * spin_factor * SPIN_CURVE_FORCE)

		if abs(vertical_spin_factor) > 0.05:
			state.apply_central_force(forward_dir * vertical_spin_factor * VERTICAL_SPIN_FORCE)

	# Rolling resistance
	if speed > 0.5 and is_grounded:
		var forward_dir = lv.normalized()
		var rotation_axis = forward_dir.cross(Vector3.UP).normalized()
		var target_angular = speed / ball_radius
		var current_angular = angular_velocity.dot(rotation_axis)
		var angular_diff = target_angular - current_angular
		if abs(angular_diff) > 0.2:
			state.apply_torque(rotation_axis * angular_diff * ROLLING_RESISTANCE_FACTOR)

func can_shoot() -> bool:
	if !camera:
		return false
	
	return (
		can_shoot_flag
		and is_shootable_speed() 
		and is_grounded 
		and camera.current_target_index == 0
		and !charging
	)

func release_push() -> void:
	if !charging:
		return

	charging = false
	if power_bar_root:
		power_bar_root.visible = false
	var impulse_power: float = clamp(current_power_ratio, MIN_IMPULSE, 1.0) * max_impulse_strength
	current_power_ratio = 0.0

	emit_signal("turn_started")
	push_ball(impulse_power)

func execute_shot() -> void:
	release_push()

func allow_shooting(allowed: bool) -> void:
	can_shoot_flag = allowed

func push_ball(impulse_power: float) -> void:
	if !camera:
		push_error("Error: No active Camera3D found.")
		return

	var camera_position = hit_position
	var ball_position = global_position
	var direction_to_camera = (camera_position - ball_position).normalized()

	print_debug("Impulse power: ", impulse_power)
	var impulse_position = -direction_to_camera * ball_radius
	var impulse_vector = direction_to_camera * impulse_power

	print_debug("Impulse_vector: ", impulse_vector)
	
	if audioStream:
		var power_ratio = impulse_power / max_impulse_strength
		
		var min_volume_db = -20.0  # Ciche uderzenie
		var max_volume_db = 2.0    # Głośne uderzenie
		
		audioStream.volume_db = lerp(min_volume_db, max_volume_db, power_ratio)
		print("Volume:", audioStream.volume_db)
		audioStream.play()
	
	# Logic for spin
	if camera and "spin_offset" in camera:
		spin_factor = camera.spin_offset
		if "vertical_spin_offset" in camera:
			vertical_spin_factor = camera.vertical_spin_offset
			camera.vertical_spin_offset = 0.0
		else:
			vertical_spin_factor = 0.0
		spin_active = abs(spin_factor) > 0.05 or abs(vertical_spin_factor) > 0.05
		camera.spin_offset = 0.0
	else:
		spin_factor = 0.0
		vertical_spin_factor = 0.0
		spin_active = false

	if spin_active:
		if abs(spin_factor) > 0.05:
			apply_torque_impulse(Vector3.UP * spin_factor * max_impulse_strength * SPIN_TORQUE_MULT)
		if abs(vertical_spin_factor) > 0.05:
			var shot_dir = (camera.cursor_position - global_position).normalized()
			shot_dir.y = 0
			shot_dir = shot_dir.normalized()
			var rotation_axis = shot_dir.cross(Vector3.UP).normalized()
			apply_torque_impulse(rotation_axis * vertical_spin_factor * max_impulse_strength * SPIN_TORQUE_MULT)

	apply_impulse(-impulse_vector, impulse_position)
	emit_signal("ball_pushed", impulse_power)

func get_charge_color(ratio: float) -> Color:
	# Gradient: zielony -> żółty -> czerwony
	if ratio < 0.5:
		var local_ratio = ratio * 2.0
		return weak_charge_color.lerp(medium_charge_color, local_ratio)
	else:
		var local_ratio = (ratio - 0.5) * 2.0
		return medium_charge_color.lerp(strong_charge_color, local_ratio)

# Helper: shader overlay (depth_test_disabled = zawsze na wierzchu)
func _make_overlay_shader(color: Color, priority: int) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
		shader_type spatial;
		render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled;
		uniform vec4 color : source_color;
		void fragment() {
			ALBEDO = color.rgb;
			ALPHA = color.a;
		}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("color", color)
	mat.render_priority = priority
	return mat

func _create_power_bar() -> void:
	# Root node
	power_bar_root = Node3D.new()
	power_bar_root.name = "PowerBarRoot"
	add_child(power_bar_root)
	power_bar_root.visible = false

	var half_w := POWER_BAR_WIDTH / 2.0
	var half_h := POWER_BAR_HEIGHT / 2.0
	var frame_col := Color(0.05, 0.05, 0.08, 0.96)

	# --- Ramka (4 boki) ---
	# Lewa
	var lm := BoxMesh.new()
	lm.size = Vector3(FRAME_THICKNESS, POWER_BAR_HEIGHT + FRAME_THICKNESS * 2.0, POWER_BAR_DEPTH)
	var li := MeshInstance3D.new()
	li.mesh = lm
	li.material_override = _make_overlay_shader(frame_col, 10)
	li.position = Vector3(-(half_w + FRAME_THICKNESS / 2.0), 0.0, 0.0)
	power_bar_root.add_child(li)

	# Prawa
	var rm := BoxMesh.new()
	rm.size = Vector3(FRAME_THICKNESS, POWER_BAR_HEIGHT + FRAME_THICKNESS * 2.0, POWER_BAR_DEPTH)
	var ri := MeshInstance3D.new()
	ri.mesh = rm
	ri.material_override = _make_overlay_shader(frame_col, 10)
	ri.position = Vector3(half_w + FRAME_THICKNESS / 2.0, 0.0, 0.0)
	power_bar_root.add_child(ri)

	# Góra
	var tm := BoxMesh.new()
	tm.size = Vector3(POWER_BAR_WIDTH, FRAME_THICKNESS, POWER_BAR_DEPTH)
	var ti := MeshInstance3D.new()
	ti.mesh = tm
	ti.material_override = _make_overlay_shader(frame_col, 10)
	ti.position = Vector3(0.0, half_h + FRAME_THICKNESS / 2.0, 0.0)
	power_bar_root.add_child(ti)

	# Dół
	var bm := BoxMesh.new()
	bm.size = Vector3(POWER_BAR_WIDTH, FRAME_THICKNESS, POWER_BAR_DEPTH)
	var bi := MeshInstance3D.new()
	bi.mesh = bm
	bi.material_override = _make_overlay_shader(frame_col, 10)
	bi.position = Vector3(0.0, -(half_h + FRAME_THICKNESS / 2.0), 0.0)
	power_bar_root.add_child(bi)

	# --- Gradient bar (green → yellow → red) ---
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(POWER_BAR_WIDTH, POWER_BAR_HEIGHT, POWER_BAR_DEPTH)

	var bar_shader := ShaderMaterial.new()
	var shader_code := Shader.new()
	shader_code.code = """
		shader_type spatial;
		render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled;
		void fragment() {
			vec3 n = normalize(NORMAL);
			if (abs(n.z) < 0.5) { discard; }
			float ratio = 1.0 - UV.y;
			vec3 green  = vec3(0.1, 1.0, 0.2);
			vec3 yellow = vec3(1.0, 1.0, 0.0);
			vec3 red    = vec3(1.0, 0.1, 0.0);
			vec3 col = (ratio < 0.5)
				? mix(green, yellow, ratio * 2.0)
				: mix(yellow, red, (ratio - 0.5) * 2.0);
			ALBEDO = col;
			ALPHA = 0.92;
		}
	"""
	bar_shader.shader = shader_code
	bar_shader.render_priority = 11

	power_bar_bg = MeshInstance3D.new()
	power_bar_bg.name = "PowerBarBG"
	power_bar_bg.mesh = bar_mesh
	power_bar_bg.material_override = bar_shader
	power_bar_bg.position = Vector3.ZERO
	power_bar_root.add_child(power_bar_bg)

	# --- Kreski podziałki (4 równo rozłożone) ---
	for i in range(TICK_COUNT):
		var frac := float(i + 1) / float(TICK_COUNT + 1)  # 0.2, 0.4, 0.6, 0.8
		var tick_y := -half_h + frac * POWER_BAR_HEIGHT

		# Czarna ramka za kreską
		var outline_mesh := BoxMesh.new()
		outline_mesh.size = Vector3(POWER_BAR_WIDTH + 0.01, TICK_HEIGHT + TICK_OUTLINE * 2.0, POWER_BAR_DEPTH)
		var outline_inst := MeshInstance3D.new()
		outline_inst.mesh = outline_mesh
		outline_inst.material_override = _make_overlay_shader(Color(0.0, 0.0, 0.0, 0.85), 12)
		outline_inst.position = Vector3(0.0, tick_y, 0.0)
		power_bar_root.add_child(outline_inst)

		# Biała kreska
		var tick_mesh := BoxMesh.new()
		tick_mesh.size = Vector3(POWER_BAR_WIDTH, TICK_HEIGHT, POWER_BAR_DEPTH)
		var tick_inst := MeshInstance3D.new()
		tick_inst.mesh = tick_mesh
		tick_inst.material_override = _make_overlay_shader(Color(0.0, 0.0, 0.0, 0.9), 12)
		tick_inst.position = Vector3(0.0, tick_y, 0.0)
		power_bar_root.add_child(tick_inst)

	# --- Marker ---
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(MARKER_WIDTH, MARKER_HEIGHT, POWER_BAR_DEPTH)

	var marker_sh := Shader.new()
	marker_sh.code = """
		shader_type spatial;
		render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled;
		uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
		void fragment() {
			ALBEDO = color.rgb;
			ALPHA = color.a;
		}
	"""
	marker_material = ShaderMaterial.new()
	marker_material.shader = marker_sh
	marker_material.set_shader_parameter("color", Color(1.0, 1.0, 1.0, 0.95))
	marker_material.render_priority = 13

	power_bar_marker = MeshInstance3D.new()
	power_bar_marker.name = "PowerBarMarker"
	power_bar_marker.mesh = marker_mesh
	power_bar_marker.material_override = marker_material
	power_bar_marker.position = Vector3(0.0, -POWER_BAR_HEIGHT / 2.0, 0.0)
	power_bar_root.add_child(power_bar_marker)

func _animate_power_bar(delta: float) -> void:
	hit_position = camera.cursor_position

	# Pozycjonowanie paska po prawej stronie bili (względem kamery)
	var cam_right := camera.global_transform.basis.x.normalized()
	var bar_pos := global_position + cam_right * POWER_BAR_OFFSET_RIGHT
	bar_pos.y = global_position.y  # Środek paska na środku bili
	power_bar_root.global_position = bar_pos

	# Pasek zawsze twarzą do kamery
	var look_target := power_bar_root.global_position + camera.global_transform.basis.z
	power_bar_root.look_at(look_target, Vector3.UP)

	# Oscylacja mocy — fala trójkątna (ping-pong)
	charge_timer += delta
	var t := fmod(charge_timer, POWER_BAR_CYCLE_SPEED) / POWER_BAR_CYCLE_SPEED
	current_power_ratio = 1.0 - abs(2.0 * t - 1.0)  # 0→1→0→1...

	# Pozycja markera na pasku (od -H/2 do +H/2)
	var marker_y := -POWER_BAR_HEIGHT / 2.0 + current_power_ratio * POWER_BAR_HEIGHT
	power_bar_marker.position.y = marker_y

	# Kolor markera — dopasowany do pozycji na gradiencie
	if marker_material:
		var col := get_charge_color(current_power_ratio)
		col.a = 0.95
		marker_material.set_shader_parameter("color", col)

func start_charging() -> void:
	camera.cursor_phi = camera.phi
	charging = true
	charge_timer = 0.0
	current_power_ratio = 0.0
	if power_bar_root:
		power_bar_root.visible = true

func create_aim_line_mesh() -> void:
	var mesh := ImmediateMesh.new()

	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = Color(1.0, 1.0, 1.0, 0.7)
	line_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED

	aim_line = MeshInstance3D.new()
	aim_line.mesh = mesh
	aim_line.material_override = line_material
	add_child(aim_line)

func _clear_aim_line() -> void:
	if aimed_at_ball != null:
		aimed_at_ball.stop_being_aimed_at()
		aimed_at_ball = null
	if aim_line:
		(aim_line.mesh as ImmediateMesh).clear_surfaces()

func _setup_aim_line() -> void:
	var draw = func _draw_aim_line(to: Vector3):
		if !aim_line or !aim_line.mesh:
			return
		var mesh := aim_line.mesh as ImmediateMesh
		mesh.clear_surfaces()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(aim_line.to_local(to))
		mesh.surface_end()

	var direction_to_camera := (camera.global_position - global_position)
	direction_to_camera.y = 0.0
	direction_to_camera = direction_to_camera.normalized()
	var ray_origin := global_position
	var ray_target := ray_origin - direction_to_camera * aim_line_ray_range
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	var new_aimed_at_ball: BallParent = null

	if result:
		draw.call(result.position)
		var collider = result.collider
		if collider is BallParent:
			new_aimed_at_ball = collider
	else:
		draw.call(ray_target)

	if aimed_at_ball != new_aimed_at_ball:
		if aimed_at_ball:
			aimed_at_ball.stop_being_aimed_at()
		if new_aimed_at_ball:
			new_aimed_at_ball.start_being_aimed_at()
		aimed_at_ball = new_aimed_at_ball

# --- LOGIKA STANU FIZYKI ---

func is_fully_stopped() -> bool:
	return sleeping or (
		linear_velocity.length_squared() < FULL_STOP_THRESHOLD * FULL_STOP_THRESHOLD
		and angular_velocity.length_squared() < FULL_STOP_ANGULAR_THRESHOLD * FULL_STOP_ANGULAR_THRESHOLD
	)

func is_shootable_speed() -> bool:
	return (
		linear_velocity.length() < SHOOTABLE_VELOCITY_THRESHOLD
		and angular_velocity.length() < SHOOTABLE_ANGULAR_THRESHOLD
	)

func _check_ground_contact() -> void:
	var space_state := get_world_3d().direct_space_state
	var ray_origin := global_position
	var ray_target := ray_origin + Vector3.DOWN * (ball_radius + 0.1)
	
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	query.exclude = [self]
	
	var result := space_state.intersect_ray(query)
	is_grounded = result.size() > 0

func get_ball_radius() -> float:
	if !collision_shape:
		push_error("Error: CollisionShape3D of PlayerBall is null")
		return 0.0
	var shape_resource = collision_shape.shape
	if not shape_resource:
		push_error("Error: CollisionShape3D node has no shape resource assigned.")
		return 0.0
	if shape_resource is SphereShape3D:
		var sphere_shape := shape_resource as SphereShape3D
		return sphere_shape.radius
	else:
		push_error("Error: The shape is not a SphereShape3D. Cannot retrieve radius.")
		return 0.0
