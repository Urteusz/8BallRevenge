extends Camera3D

@export var mouse_sensitivity: float = 0.003 # CZYTAJ Z USTAWIEN
@export var table_camera_radius: float = 13.0 # dystans kamery od celu gdy patrzy sie na srodek

@export var min_phi: float = 0.4 # max wysokosc kamery
@export var max_phi: float = 1.45 #		min wysokosc, albo na odwrot nie pamietam

var theta = PI / 2
var phi = 1.0

var camera_current_radius: float = 0.0
var offset := Vector3(0.0, 0.0, 0.0) # Przesuniecie kamery od celu
var pivot := Vector3.ZERO # Punkt wokol ktorego kamera sie obraca

func _ready() -> void:
	camera_current_radius = table_camera_radius
	_update_position()
	look_at(pivot)


func _process(delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_update_position()
		look_at(pivot)

func _update_position() -> void:
	phi = clamp(phi, min_phi, max_phi)

	var x = camera_current_radius * sin(phi) * cos(theta)
	var y = camera_current_radius * cos(phi)
	var z = camera_current_radius * sin(phi) * sin(theta)
	offset = Vector3(x, y, z)

	global_position = pivot + offset

func _input(event) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if SettingsManager.get_setting("controls", "inverted_mouse"):
				phi -= event.relative.y * mouse_sensitivity
			else:
				phi += event.relative.y * mouse_sensitivity
			theta += event.relative.x * mouse_sensitivity
	# Mozna by tu dodac poruszanie sie kamera wsadem moze

	if event.is_action_pressed("toggle_mouse_capture"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
