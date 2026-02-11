extends AnimatableBody3D

# Możesz dostosować w inspektorze
@export var swing_speed: float = 1.0  # Prędkość wahadła (mniejsza = wolniejsze)
@export var max_angle: float = 45.0  # Maksymalny kąt wychylenia (stopnie)
@export var swing_axis: Vector3 = Vector3(1, 0, 0)  # Oś wahadła (x, y, z)

var time: float = 0.0

func _physics_process(delta):
	time += delta
	
	# Oblicz aktualny kąt wahadła
	var current_angle = sin(time * swing_speed) * deg_to_rad(max_angle)
	
	# Bezpośrednio ustaw rotację na osi (nie dodawaj!)
	if swing_axis == Vector3(1, 0, 0):
		rotation.x = current_angle
	elif swing_axis == Vector3(0, 1, 0):
		rotation.y = current_angle
	elif swing_axis == Vector3(0, 0, 1):
		rotation.z = current_angle
