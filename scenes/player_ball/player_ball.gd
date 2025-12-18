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

# Ustawienia podkręcenia (uderzenie w prawo/lewo na bili)
@export var max_spin_offset: float = 0.7 
@export var spin_change_speed: float = 1.8 
@export var spin_indicator_max_offset_visual: float = 0.5 # Zwiększono zakres ruchu wskaźnika
@export var side_spin_curve_strength: float = 20000 

# Kolory pierścienia ładowania strzału (słaby -> średni -> mocny)
@export var weak_charge_color := Color(0.0, 1.0, 0.0, 1.0)
@export var medium_charge_color := Color(1.0, 1.0, 0.0, 1.0)
@export var strong_charge_color := Color(1.0, 0.0, 0.0, 1.0)

@export var aim_line_ray_range: float = 20.0

# Ścieżki
@onready var collision_shape := $CollisionShape3D
@onready var charge_ring: MeshInstance3D = $ChargeRing
#@onready var animation_player := $AnimationPlayer
# Bezpieczne pobranie control_gameplay (może nie istnieć)
@onready var control_gameplay = get_node_or_null("/root/Node3D/GameplayUI/ControlGameplay")

@onready var ball_radius: float = get_ball_radius()
@onready var aim_line: MeshInstance3D = null
# @onready var spin_indicator: MeshInstance3D = null # Removed in favor of charge_ring

var ring_material: StandardMaterial3D = null
# var spin_indicator_material: StandardMaterial3D = null
var hit_position: Vector3 # Pozycja kursora/kamery w momencie rozpoczęcia ładowania strzału
var charging: bool = false
var charge_timer: float = 0.0
var aimed_at_ball: BallParent = null
var camera: Camera3D = null
var current_phase: Phase = Phase.AIMING
var stop_timer: float = 0.0 # patrzy STOP_DELAY wyżej
var is_grounded: bool = false  # Czy piłka dotyka podłoża

var spin_factor: float = 0.0 # -1.0 (left) to 1.0 (right) stored from camera at shot time
var spin_active: bool = false

# Stałe fizyki podkręcania
const SPIN_CURVE_FORCE: float = 6.0 # Siła "skręcania" (Drastycznie zmniejszono)
const SPIN_DECAY: float = 0.5 # Jak szybko wygasa podkręcenie
const SPIN_TORQUE_MULT: float = 0.02 # Przelicznik offsetu na rotację piłki (Zmniejszono z 0.15)

signal ball_pushed(impulse_power: float)
signal round_ended
signal charging_cancelled


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
			
	# Spin decay
	if spin_active:
		spin_factor = move_toward(spin_factor, 0.0, SPIN_DECAY * delta)
		if is_equal_approx(spin_factor, 0.0):
			spin_active = false


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if spin_active and !sleeping:
		var lv = state.linear_velocity
		var speed = lv.length()
		if speed > 0.5:

			var curve_dir = lv.cross(Vector3.UP).normalized()
			var force = -curve_dir * spin_factor * SPIN_CURVE_FORCE
			
			state.apply_central_force(force)


func _input(event) -> void:
	if !is_inside_tree():
		return
		
	if charging:
		if event.is_action_pressed("cancel_charging"):
			charge_ring.visible = false
			charging = false
			charge_timer = 0.0
			emit_signal("charging_cancelled")

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



# ... (rest of file until _animate_charge_ring)

func _animate_charge_ring(delta: float) -> void:
	hit_position = camera.cursor_position
	var direction_to_camera: Vector3 = (camera.cursor_position - global_position).normalized()

	# Kierunek prawej/lewej względem kierunku strzału (po płaszczyźnie stołu)
	var forward_visual: Vector3 = direction_to_camera
	var right_visual: Vector3 = Vector3.UP.cross(forward_visual).normalized()
	if right_visual.length_squared() == 0.0:
		right_visual = Vector3.RIGHT
		
	# Get spin offset from camera (keeping our input logic)
	var current_spin_offset: float = 0.0
	if "spin_offset" in camera:
		current_spin_offset = camera.spin_offset

	# Orbital movement: Rotate the forward vector around UP axis
	# Max angle: spin_indicator_max_offset_visual (interpreted as radians or scale factor)
	# Increased to 1.2 (~70 degrees) for better visibility as requested ("weak").
	
	# We want: Hit Right (spin_offset > 0) -> Indicator moves Right.
	# direction_to_camera is roughly Back.
	# Rotating around UP: Positive angle is CCW.
	# If we look FROM camera at ball: Right is ...
	# Let's try positive offset for positive spin.
	var angle_offset = current_spin_offset * spin_indicator_max_offset_visual
	
	var orbital_direction = forward_visual.rotated(Vector3.UP, angle_offset)
	
	# Floating billboard style, but orbiting position
	charge_ring.global_position = global_position + orbital_direction * 1.0 # Radius 1.0
	
	# User request: "Look at the ball"
	charge_ring.look_at(global_position, Vector3.UP)
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
	
	# Logic for spin
	if camera and "spin_offset" in camera:
		spin_factor = camera.spin_offset
		spin_active = abs(spin_factor) > 0.05
		# Reset camera spin after shooting
		camera.spin_offset = 0.0
	else:
		spin_factor = 0.0
		spin_active = false
		
	if spin_active:
		# Apply explicit torque impulse for stronger effect if needed
		# spin_factor > 0 (Right hit) -> Torque +Y
		apply_torque_impulse(Vector3.UP * spin_factor * max_impulse_strength * SPIN_TORQUE_MULT)

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
		# Fallback just in case, or we can push_error like in snippet
		# push_error("Error: ChargeRing has no material!")
		# But for safety, let's keep basic creation if missing, but prioritized what snippet did.
		# Snippet uses get_surface_override_material.
		
		# Proba pobrania z mesha jesli override nie ma
		var mesh = charge_ring.mesh
		if mesh:
			var mat = mesh.surface_get_material(0)
			if mat:
				ring_material = mat.duplicate()
				charge_ring.set_surface_override_material(0, ring_material)
				var color = ring_material.albedo_color
				color.a = 0.0
				ring_material.albedo_color = color
				return
				
		push_error("Error: ChargeRing has no material to setup!")


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
