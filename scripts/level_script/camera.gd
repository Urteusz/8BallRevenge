extends Camera3D

const BALLS_GROUP = "balls"
const DEFAULT_CURSOR_PHI: float = 1.45
const DEFAULT_PHI: float = 1.0

var points_popup = preload(ScenePaths.POINTS_POPUP_PATH)

@export var player_ball: Node3D
@export var mouse_sensitivity: float = 0.003
@export var joystick_sensitivity: float = 2.0
@export var table_camera_radius: float = 13.0 # dystans kamery od celu gdy patrzy sie na srodek
@export var ball_camera_radius: float = 5.0 #		i gdy patrzy sie na kule
@export var camera_lerp_speed: float = 10.0

@export var cursor_lock_offset: float = 0.0
@export var min_phi: float = 0.4 # max wysokosc kamery
@export var max_phi: float = 1.45 #		min wysokosc, albo na odwrot nie pamietam
@export var min_cursor_phi: float = 0.08 # min/max wysokosc 'celownika'
@export var max_cursor_phi: float = 1.8

var target: Node3D = null
# do obliczania pozycji kamery/celownika
var theta = PI / 2
var phi = DEFAULT_PHI
var cursor_phi = phi
# kamera patrzy sie w tym sammy kierunku po powrocie do bili, co przed przelaczeniem kamery na srodek
var previous_theta = theta

var ball_list
var camera_current_radius: float = 0.0
var camera_target_radius: float = 0.0
var current_target_index: int = 0 # Biala bila
var offset := Vector3(0.0, 0.0, 0.0) # Przesuniecie kamery od celu
var pivot := Vector3.ZERO # Punkt wokol ktorego kamera sie obraca
var animating: bool = false # czy jest w trakcie lerp
var cursor_position := Vector3.ZERO
var cursor_offset := Vector3.ZERO


signal targetting_center
signal game_won

var spin_offset: float = 0.0
const MAX_SPIN_OFFSET: float = 0.95
const SPIN_ADJUST_SPEED: float = 2.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	self.position = Vector3.ZERO
	ball_list = get_tree().get_nodes_in_group(BALLS_GROUP)
	target = player_ball

	camera_current_radius = ball_camera_radius
	camera_target_radius = camera_current_radius


# do podzielenia na mniejsze funkcje
func _process(delta: float) -> void:
	_handle_joystick_input(delta)
	
	var spin_input = 0.0
	if Input.is_physical_key_pressed(KEY_E):
		spin_input += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		spin_input -= 1.0
		
	spin_offset += spin_input * SPIN_ADJUST_SPEED * delta
	spin_offset = clamp(spin_offset, -MAX_SPIN_OFFSET, MAX_SPIN_OFFSET)

	# Reset spin when moving camera
	if abs(spin_input) > 0.001:
		pass # Keep spin
	
	camera_current_radius = lerp(camera_current_radius, camera_target_radius, camera_lerp_speed * delta)
	cursor_phi = clamp(cursor_phi, min_cursor_phi, max_cursor_phi)

	#print_debug("Cursor PHI: {}", cursor_phi)
	#print_debug("PHI: {}", phi)
	var x: float = camera_current_radius * sin(cursor_phi) * cos(theta)
	var y: float = 0.0
	if cursor_phi > DEFAULT_CURSOR_PHI:
		y = camera_current_radius * cos(cursor_phi)
	else:
		y = camera_current_radius * cos(DEFAULT_CURSOR_PHI)
	var z: float = camera_current_radius * sin(cursor_phi) * sin(theta)
	
	if current_target_index == 0:
		cursor_offset = Vector3(x, y, z)
	phi = clamp(cursor_phi, min_phi, max_phi)

	x = camera_current_radius * sin(phi) * cos(theta)
	y = camera_current_radius * cos(phi)
	z = camera_current_radius * sin(phi) * sin(theta)
	offset = Vector3(x, y, z)
	
	# jesli kamera jest wyzej niz domyslna pozycja to ciagnie za soba kursor
	# cursor_lock_offset zmienia jak szybko kursor zaczyna podazac za kamera kiedy ta podniesie sie
	#	powyżej domyślnej pozycji
	if current_target_index == 0 and cursor_phi < DEFAULT_PHI - cursor_lock_offset:
		var cursor_y = camera_current_radius * cos(phi + (DEFAULT_CURSOR_PHI - DEFAULT_PHI) + cursor_lock_offset)
		cursor_offset = Vector3(x, cursor_y, z)

	var target_center := Vector3.ZERO
	if target:
		target_center = target.global_position

	if animating:
		pivot = lerp(pivot, target_center, camera_lerp_speed * delta)
		if pivot.distance_to(target_center) < 0.01:
			animating = false
			pivot = target_center
	else:
		pivot = target_center

	if current_target_index == 0:
		cursor_position = pivot + cursor_offset
	global_position = pivot + offset
	look_at(pivot)


func _input(event) -> void:
	if event is InputEventMouseMotion:
		if SettingsManager.get_setting("controls", "inverted_mouse"):
			cursor_phi -= event.relative.y * mouse_sensitivity
		else:
			cursor_phi += event.relative.y * mouse_sensitivity
		theta += event.relative.x * mouse_sensitivity

	# Na szybko to zmienilem zeby dzialalo
	# DO PRZEPISANIA TAK SAMO JAK udpate_camera_target()
	if event.is_action_pressed("next_camera_target") || event.is_action_pressed("previous_camera_target"):
		if target == null:
			theta = previous_theta
			current_target_index = 0
		else:
			previous_theta = theta
			current_target_index = 1
		update_camera_target()

	if event.is_action_pressed("toggle_mouse_capture"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("reload_scene"):
		_reload_current_scene()


# do przepisania, nie powinno uzywac ball_list array w taki sposob
#	chyba ze chcemy wykorzystac mozliwosc patrzenia na inne bile (niz biala)
func update_camera_target() -> void:
	var total_targets: int = ball_list.size() + 1
	current_target_index = wrapi(current_target_index, 0, total_targets)

	if target != null:
		camera_target_radius = table_camera_radius
		emit_signal("targetting_center")
		target = null
	else:
		camera_target_radius = ball_camera_radius
		target = player_ball

	animating = true


func is_looking_at_player() -> bool:
	return current_target_index == 0


func is_looking_at_center() -> bool:
	if ball_list:
		return current_target_index == ball_list.size() + 1
	else:
		push_error("Error: camera.ball_list is null")
		return false

func _handle_joystick_input(delta: float) -> void:
	var input_direction = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	
	if input_direction.length() > 0:
		theta += input_direction.x * joystick_sensitivity * delta
		
		if SettingsManager.get_setting("controls", "inverted_mouse"):
			cursor_phi -= input_direction.y * joystick_sensitivity * delta
		else:
			cursor_phi += input_direction.y * joystick_sensitivity * delta

func _reload_current_scene() -> void:
	var error_code = get_tree().reload_current_scene()
	if error_code != OK:
		print("Error reloading scene: ", error_code)
