extends Node3D

@export var card: Node3D
@export var camera: Camera3D
@export var second_camera: Camera3D
@export var ball: Node3D
@export var target: Node3D
@export var card_rotation_sensitivity: float = 0.2
@export var lerp_speed: float = 10.0

var ball_previous_position: Vector3

func _ready() -> void:
	ball_previous_position = ball.position

func _process(delta: float) -> void:
	var destination = second_camera.project_position(Vector2.ZERO, 1.0) + Vector3(0.5, -0.5, 0.0)
	var look_target = destination + (destination - target.global_position)
	
	var target_transform = Transform3D(Basis(), destination)
	target_transform = target_transform.looking_at(look_target, Vector3.UP)
	target_transform.basis = target_transform.basis.scaled(Vector3.ONE * 0.3)
	
	card.global_transform = card.global_transform.interpolate_with(target_transform, delta * lerp_speed)
