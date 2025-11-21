extends Area3D

class_name Portal

@export var destination_portal: Area3D 

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	if body is RigidBody3D and destination_portal:
		teleport_object(body)

func teleport_object(body: RigidBody3D):
	var exit_point = destination_portal.get_node("ExitPoint")
	
	body.global_position = exit_point.global_position
	var local_velocity = global_transform.basis.inverse() * body.linear_velocity
	local_velocity.z = -local_velocity.z
	var final_velocity = destination_portal.global_transform.basis * local_velocity
	
	body.linear_velocity = final_velocity
