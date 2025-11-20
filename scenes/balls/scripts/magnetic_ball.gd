extends BallParent
class_name MagneticBall

@export var magnet_range: float = 5.0     # Promień przyciągania
@export var magnet_force: float = 10.0    # Siła magnetyzmu

func _physics_process(delta: float) -> void:
	for ball in get_tree().get_nodes_in_group("balls"):
		if ball == self:
			continue
		var dist = global_position.distance_to(ball.global_position)
		if dist <= magnet_range:
			var direction = (global_position - ball.global_position).normalized()
			ball.linear_velocity += direction * magnet_force * delta
