extends BallParent

enum Phase { AIMING, MOVING }

# Progi prędkości dla możliwości strzelania (bardziej liberalne niż pełne zatrzymanie)
const SHOOTABLE_VELOCITY_THRESHOLD: float = 3 
const SHOOTABLE_ANGULAR_THRESHOLD: float = 2

# Minimalna prędkość po której uznajemy, że kula CAŁKOWICIE stoi (dla round_ended)
const FULL_STOP_THRESHOLD: float = 0.1
const FULL_STOP_ANGULAR_THRESHOLD: float = 0.15

# Ile czasu program czeka aby uznać, że kula na pewno się zatrzymała
const STOP_DELAY: float = 0.4
const RING_ALPHA: float = 0.7
const MIN_IMPULSE: float = 0.2

# Ustawienia uderzenia
@export var max_charge_duration: float = 1.0
@export var max_impulse_strength: float = 30.0

# Kolory pierścienia ładowania strzału (słaby -> średni -> mocny)
@export var weak_charge_color := Color(0.0, 1.0, 0.0, 1.0)
@export var medium_charge_color := Color(1.0, 1.0, 0.0, 1.0)
@export var strong_charge_color := Color(1.0, 0.0, 0.0, 1.0)

@export var aim_line_ray_range: float = 20.0

# Ścieżki
@onready var collision_shape := $CollisionShape3D
@onready var charge_ring: MeshInstance3D = $ChargeRing
@onready var animation_player := $AnimationPlayer
# Bezpieczne pobranie control_gameplay (może nie istnieć)
@onready var control_gameplay = get_node_or_null("/root/Node3D/GameplayUI/ControlGameplay")

@onready var ball_radius: float = get_ball_radius()
@onready var aim_line: MeshInstance3D = null

var ring_material: StandardMaterial3D = null
var hit_position: Vector3 # Pozycja kursora/kamery w momencie rozpoczęcia ładowania strzału
var charging: bool = false
var charge_timer: float = 0.0
var aimed_at_ball: BallParent = null
var camera: Camera3D = null
var current_phase: Phase = Phase.AIMING
var stop_timer: float = 0.0 # patrzy STOP_DELAY wyżej
var is_grounded: bool = false  # Czy piłka dotyka podłoża

signal ball_pushed(impulse_power: float)
signal round_ended


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	ball_radius = get_ball_radius()

	if not camera:
		push_error("Error: No camera found.")
		set_process(false)
		return

	setup_charge_ring()
	create_aim_line_mesh()
	# Wejście w stan AIMING na starcie
	_enter_aiming_state()


func _process(delta: float) -> void:
	if charging and camera and charge_ring:
		_animate_charge_ring(delta)

	_check_ground_contact()

	if !is_fully_stopped():
		if current_phase == Phase.AIMING:
			_enter_moving_state()
		stop_timer = 0.0
		if can_shoot() and camera.is_looking_at_player():
			_setup_aim_line()
		else:
			_clear_aim_line()
	else:
		if current_phase == Phase.MOVING:
			stop_timer += delta
			if stop_timer >= STOP_DELAY:
				_enter_aiming_state()
		if camera.is_looking_at_player():
			_setup_aim_line()


func _input(event) -> void:
	if !is_inside_tree():
		return
		
	if charging:
		if event.is_action_pressed("cancel_charging"):
			charge_ring.visible = false
			charging = false

	# Można strzelać gdy piłka jest wystarczająco wolna, dotyka podłoża i kamera patrzy na gracza
	if event.is_action_pressed("push_ball") and can_shoot() and !charging:
		start_charging()
	elif event.is_action_released("push_ball"):
		release_push()


func can_shoot() -> bool:
	if !camera:
		return false
	
	return is_shootable_speed() and is_grounded and camera.current_target_index == 0


func is_shootable_speed() -> bool:
	# Sprawdza czy piłka jest wystarczająco wolna aby można było strzelać
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


func _enter_aiming_state() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true
	current_phase = Phase.AIMING
	stop_timer = 0.0


func _enter_moving_state() -> void:
	sleeping = false
	current_phase = Phase.MOVING


func _animate_charge_ring(delta: float) -> void:
	hit_position = camera.cursor_position
	var direction_to_camera: Vector3 = (camera.cursor_position - global_position).normalized()
	charge_ring.global_position = global_position + direction_to_camera * 1.0
	charge_ring.look_at(camera.cursor_position, Vector3.UP)
	charge_ring.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	charge_timer += delta
	var ratio: float = clamp(charge_timer / max_charge_duration, 0.0, 1.0)
	if ring_material:
		var current_color := get_charge_color(ratio)
		current_color.a = RING_ALPHA
		ring_material.albedo_color = current_color


func get_charge_color(ratio: float) -> Color:
	# Gradient: zielony -> żółty -> czerwony
	if ratio < 0.5:
		var local_ratio = ratio * 2.0
		return weak_charge_color.lerp(medium_charge_color, local_ratio)
	else:
		var local_ratio = (ratio - 0.5) * 2.0
		return medium_charge_color.lerp(strong_charge_color, local_ratio)


func start_charging() -> void:
	camera.cursor_phi = camera.phi
	charging = true
	charge_timer = 0.0
	charge_ring.visible = true


func release_push() -> void:
	if !charging:
		return

	charging = false
	charge_ring.visible = false

	charge_timer = clamp(charge_timer, 0.0, max_charge_duration)
	var impulse_power: float = clamp(charge_timer / max_charge_duration, MIN_IMPULSE, 1.0) * max_impulse_strength

	if current_phase == Phase.MOVING or stop_timer >= STOP_DELAY:
		emit_signal("round_ended")
		print("Zakończono rundę (nowym uderzeniem)")

	push_ball(impulse_power)
	_enter_moving_state()


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
	apply_impulse(-impulse_vector, impulse_position)
	emit_signal("ball_pushed", impulse_power)


func setup_charge_ring() -> void:
	if charge_ring.get_surface_override_material(0):
		ring_material = charge_ring.get_surface_override_material(0).duplicate()
		charge_ring.set_surface_override_material(0, ring_material)
		var color = ring_material.albedo_color
		color.a = 0.0
		ring_material.albedo_color = color
	else:
		push_error("Error: ChargeRing has no material!")
		return


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
