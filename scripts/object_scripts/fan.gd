extends Node3D

# Możesz dostosować w inspektorze
@export var rotation_speed: float = 90.0  # Stopnie na sekundę
@export var rotation_axis: Vector3 = Vector3(0, 1, 0)  # Oś obrotu (x, y, z)

func _process(delta):
	rotate(rotation_axis.normalized(), deg_to_rad(rotation_speed) * delta)
