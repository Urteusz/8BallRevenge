class_name IceCube
extends Area3D

@export var break_delay: float = 0.5
var is_breaking = false

func _ready():
	monitoring = true
	monitorable = true

func _physics_process(delta):
	global_rotation = Vector3.ZERO

func _on_body_entered(body: Node3D) -> void:
	if is_breaking: return

	if body.name == "PlayerBall":
		start_break_sequence()

func start_break_sequence():
	is_breaking = true
	if break_delay > 0:
		await get_tree().create_timer(break_delay).timeout
	break_ice()

func break_ice() -> void:
	var parent_ball = get_parent()
	
	if parent_ball is BallParent:
		parent_ball.set_deferred("lock_rotation", false)
		parent_ball.sleeping = false 
	
	queue_free()
