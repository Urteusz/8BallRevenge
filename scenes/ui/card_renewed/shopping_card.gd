extends SubViewportContainer

# pewnie zamiast uzywac export, powinien dostawac kule z listy kul
@export var card: Node3D
@export var camera: Camera3D
@export var ball: Node3D
# Zmienia jak daleko/blisko jest Z pozycja kursora,
#	< 1.0 -> karta bardziej sie obraca
#	> 1.0 -> karta obraca sie mniej
@export var card_rotation_sensitivity: float = 1.0

var ball_previous_position: Vector3

func _ready() -> void:
	ball_previous_position = ball.position


func _process(delta: float) -> void:
	var mouse_position: Vector2 = get_global_mouse_position()
	var window_size = DisplayServer.window_get_size()
	var mouse_position_x: float = remap(mouse_position.x, 0, window_size.x, 1.0, -1.0);
	var mouse_position_y: float = remap(mouse_position.y, 0, window_size.y, -1.0, 1.0);
	var target = Vector3(mouse_position_x, mouse_position_y, -camera.position.z * card_rotation_sensitivity)
	card.look_at(target, Vector3.UP, false)
