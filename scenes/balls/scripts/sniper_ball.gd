extends BallParent
class_name SniperBall

## Prędkość z jaką kula leci w stronę celu po zderzeniu z graczem
@export var sniper_speed: float = 10.0

@onready var sniper_hit_sound: AudioStreamPlayer3D = $SniperHitSound

var _pending_snipe: bool = false
var _snipe_direction: Vector3 = Vector3.ZERO
var _snipe_speed: float = 0.0

func _ready():
	super._ready()
	base_value = 400

func _on_body_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if body == self:
		return

	if body.is_in_group("table") or body.is_in_group("walls"):
		return

	on_hit()

	# Po zderzeniu z kulą gracza — aimbot + dźwięk snajpera tylko gdy znajdzie cel
	if body.name == "PlayerBall":
		var hit_direction = linear_velocity.normalized()
		var target = _find_nearest_ball_in_direction(hit_direction)
		if target:
			sniper_hit_sound.play()
			_snipe_direction = (target.global_position - global_position).normalized()
			_snipe_speed = max(linear_velocity.length(), sniper_speed)
			_pending_snipe = true
		else:
			$AudioStreamPlayer3D.play()
	else:
		$AudioStreamPlayer3D.play()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_snipe:
		state.linear_velocity = _snipe_direction * _snipe_speed
		_pending_snipe = false

func _find_nearest_ball_in_direction(hit_dir: Vector3) -> Node:
	var best: Node = null
	var best_dist: float = INF

	for ball in get_tree().get_nodes_in_group("balls"):
		if ball == self:
			continue
		if ball.name == "PlayerBall":
			continue
		if not is_instance_valid(ball) or ball.is_queued_for_deletion():
			continue
		var to_ball = (ball.global_position - global_position).normalized()
		# Tylko kule w półsferze w kierunku uderzenia (dot > 0)
		if to_ball.dot(hit_dir) <= 0:
			continue
		var dist = global_position.distance_to(ball.global_position)
		if dist < best_dist:
			best_dist = dist
			best = ball

	return best
