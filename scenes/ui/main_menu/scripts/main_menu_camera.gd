extends Camera3D

@export var pivot_point = Vector3(0.0, 0.483, -2.365)
@export var rotation_speed: float = 0.2
@export var radius: float = 2.1
@export var height: float = 5.0

var current_angle: float = 0.0


# kamera zaczyna z losowym katem
func _ready() -> void:
	current_angle = TAU


func _process(delta: float) -> void:
	var offset_x = radius * cos(current_angle)
	var offset_z = radius * sin(current_angle)
	var final_height = (sin(current_angle * 0.5) * 0.5 + 1.0) * height

	global_position = Vector3(
		pivot_point.x + offset_x,
		pivot_point.y + final_height,
		pivot_point.z + offset_z,
	)

	look_at(pivot_point)
