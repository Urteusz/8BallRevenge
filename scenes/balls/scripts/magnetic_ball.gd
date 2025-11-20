extends BallParent
class_name MagneticBall

@export var magnet_range: float = 5.0
@export var magnet_force: float = 10.0
@export var magnet_time: float = 2.0
@export var magnet_min_dist: float = 2.0

var magnet_timer: float = 0.0
var magnet_active: bool = false
var magnet_used_this_round: bool = false

const MOVEMENT_THRESHOLD: float = 0.1

func _physics_process(delta: float) -> void:
	# Reset blokady magnesu gdy kula stoi
	if linear_velocity.length() < MOVEMENT_THRESHOLD and !magnet_active:
		magnet_used_this_round = false

	# Odpalenie magnesu JEDEN RAZ po ruszeniu w rundzie
	if not magnet_active and not magnet_used_this_round:
		if linear_velocity.length() > MOVEMENT_THRESHOLD:
			magnet_timer = magnet_time
			magnet_active = true
			magnet_used_this_round = true
		return

	# Magnes aktywny
	if magnet_active:
		magnet_timer -= delta
		if magnet_timer <= 0.0:
			magnet_active = false
			# Mozna tu dodać np. dźwięk, efekt, ale nie zatrzymujemy ręcznie!
			return

		for ball in get_tree().get_nodes_in_group("balls"):
			if ball == self:
				continue
			if ball.name == "PlayerBall":
				continue
			var dist = global_position.distance_to(ball.global_position)
			if dist <= magnet_range and dist > magnet_min_dist:
				var direction = (global_position - ball.global_position).normalized()
				ball.linear_velocity += direction * magnet_force * delta
