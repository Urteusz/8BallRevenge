extends BallParent

# Progi prędkości dla możliwości strzelania
const SHOOTABLE_VELOCITY_THRESHOLD: float = 3.0
const SHOOTABLE_ANGULAR_THRESHOLD: float = 2.0

# Minimalna prędkość po której uznajemy, że kula CAŁKOWICIE stoi
const FULL_STOP_THRESHOLD: float = 0.1
const FULL_STOP_ANGULAR_THRESHOLD: float = 0.15

# Stałe uderzenia
const MIN_IMPULSE: float = 0.2

# Power bar & crosshair scenes
const POWER_BAR_OFFSET_RIGHT: float = 1.0
const POWER_BAR_CYCLE_SPEED: float = 1.4
var PowerBarScene: PackedScene = preload("res://scenes/player_ball/power_bar.tscn")
var CrosshairScene: PackedScene = preload("res://scenes/player_ball/spin_crosshair.tscn")

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
@onready var meshBlack = $MeshInstance3D
@onready var meshGold = $MeshInstance3DGold

var camera: Camera3D = null

# Power bar
var power_bar_root: Node3D = null
var current_power_ratio: float = 0.0
var charging: bool = false
var charge_timer: float = 0.0
var hit_position: Vector3
var aimed_at_ball: BallParent = null

# Celownik
var crosshair: MeshInstance3D = null
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
signal shoot_requested(ball)

var owner_id: int = 1

func _ready() -> void:
	if PlayerData.get_total_stars() == 21:
		print_debug("Dupa")
		meshGold.visible = true
		meshBlack.visible = false
	camera = get_viewport().get_camera_3d()
	ball_radius = get_ball_radius()

	if not camera:
		push_error("Error: No camera found.")
		set_process(false)
		return

	# Instantiate power bar and crosshair scenes
	power_bar_root = PowerBarScene.instantiate()
	add_child(power_bar_root)
	crosshair = CrosshairScene.instantiate()
	add_child(crosshair)
	create_aim_line_mesh()
	sleeping = true

func _process(delta: float) -> void:
	# On multiplayer client, UI still updates locally
	if charging and camera and power_bar_root:
		_animate_power_bar(delta)
		_animate_crosshair()
	
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
		
	if NetworkManager.is_multiplayer_active() and owner_id != NetworkManager.peer_id:
		return

	if charging:
		if event.is_action_pressed("cancel_charging"):
			if power_bar_root:
				power_bar_root.visible = false
			if crosshair:
				crosshair.visible = false
			charging = false
			charge_timer = 0.0
			current_power_ratio = 0.0
			emit_signal("charging_cancelled")

	if event.is_action_pressed("push_ball") and can_shoot():
		start_charging()
	elif event.is_action_released("push_ball"):
		if charging:
			emit_signal("shoot_requested", self)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if sleeping:
		return
	# On multiplayer client, player ball is frozen — no local physics
	if NetworkManager.is_multiplayer_active() and not NetworkManager.is_host:
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

	var my_turn := true
	if NetworkManager.is_multiplayer_active():
		var gm := _get_game_manager()
		if gm:
			my_turn = gm.is_my_turn() and (owner_id == NetworkManager.peer_id or owner_id == 0)

	return (
		can_shoot_flag
		and is_shootable_speed()
		and is_grounded
		and camera.current_target_index == 0
		and !charging
		and my_turn
	)

func _get_game_manager() -> Node:
	var parent := get_parent()
	while parent:
		if parent.has_method("is_my_turn"):
			return parent
		for child in parent.get_children():
			if child.has_method("is_my_turn"):
				return child
		parent = parent.get_parent()
	return null

func release_push() -> void:
	if !charging:
		return

	charging = false
	if power_bar_root:
		power_bar_root.visible = false
	if crosshair:
		crosshair.visible = false
	var impulse_power: float = clamp(current_power_ratio, MIN_IMPULSE, 1.0) * max_impulse_strength
	current_power_ratio = 0.0

	emit_signal("turn_started")
	push_ball(impulse_power)

func execute_shot() -> void:
	release_push()

func execute_shot_from_network(power_ratio: float, direction: Vector3, spin: float, v_spin: float) -> void:
	# Called by host's game_manager when receiving an RPC shot (or host's own shot)
	charging = false
	if power_bar_root:
		power_bar_root.visible = false
	if crosshair:
		crosshair.visible = false

	hit_position = direction
	current_power_ratio = power_ratio

	# Set spin values on camera temporarily so push_ball picks them up
	if camera:
		if "spin_offset" in camera:
			camera.spin_offset = spin
		if "vertical_spin_offset" in camera:
			camera.vertical_spin_offset = v_spin

	var impulse_power: float = clamp(power_ratio, MIN_IMPULSE, 1.0) * max_impulse_strength
	current_power_ratio = 0.0
	emit_signal("turn_started")
	push_ball(impulse_power)

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



func _animate_power_bar(delta: float) -> void:
	hit_position = camera.cursor_position

	# Position bar to the right of the ball (relative to camera)
	var cam_right := camera.global_transform.basis.x.normalized()
	var bar_pos := global_position + cam_right * POWER_BAR_OFFSET_RIGHT
	bar_pos.y = global_position.y
	power_bar_root.global_position = bar_pos

	# Face the bar towards camera
	var look_target := power_bar_root.global_position + camera.global_transform.basis.z
	power_bar_root.look_at(look_target, Vector3.UP)

	# Oscillating power — triangle wave (ping-pong)
	charge_timer += delta
	var t := fmod(charge_timer, POWER_BAR_CYCLE_SPEED) / POWER_BAR_CYCLE_SPEED
	current_power_ratio = 1.0 - abs(2.0 * t - 1.0)

	# Marker position on bar
	var bar_h: float = power_bar_root.POWER_BAR_HEIGHT
	var marker_y := -bar_h / 2.0 + current_power_ratio * bar_h
	power_bar_root.marker.position.y = marker_y

	# Marker color — matches gradient position
	if power_bar_root.marker_material:
		var col := get_charge_color(current_power_ratio)
		col.a = 0.95
		power_bar_root.marker_material.set_shader_parameter("color", col)

func start_charging() -> void:
	camera.cursor_phi = camera.phi
	charging = true
	charge_timer = 0.0
	current_power_ratio = 0.0
	if power_bar_root:
		power_bar_root.visible = true
	if crosshair:
		crosshair.visible = true



func _animate_crosshair() -> void:
	if not crosshair or not camera:
		return

	# Kierunek od bili do kursora (kierunek uderzenia)
	var dir_to_cursor: Vector3 = (camera.cursor_position - global_position).normalized()

	# Prawo/góra relative to that direction
	var right: Vector3 = dir_to_cursor.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var up: Vector3 = Vector3.UP

	# Pobierz spin offset z kamery
	var h_spin := 0.0
	var v_spin := 0.0
	if "spin_offset" in camera:
		h_spin = camera.spin_offset
	if "vertical_spin_offset" in camera:
		v_spin = camera.vertical_spin_offset

	# Pozycja na powierzchni bili
	var offset_dir: Vector3 = (dir_to_cursor + right * h_spin * 0.5 + up * v_spin * 0.5).normalized()
	var ch_pos: Vector3 = global_position + offset_dir * (ball_radius + 0.001)

	crosshair.global_position = ch_pos
	# Ring przylegający do powierzchni bili
	crosshair.look_at(ch_pos + offset_dir, Vector3.UP)
	crosshair.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))

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
