class_name IceBall
extends BallParent

@onready var ice_cube_scene: PackedScene = load(ScenePaths.ICE_CUBE_PATH)

var can_apply_modifier = true
@export var freeze_delay: float = 0.5 

func _ready():
	super._ready()
	contact_monitor = true
	max_contacts_reported = 11

func _on_body_entered(idk, body: Node, idk2, idk3) -> void:
	if body == self or not can_apply_modifier:
		return
	
	if body is RigidBody3D:
		if body.name == "PlayerBall":
			pass 
		elif body is BallParent:
			apply_freeze_sequence(body)

func apply_freeze_sequence(target: RigidBody3D):
	if freeze_delay > 0:
		await get_tree().create_timer(freeze_delay).timeout
	
	if not is_instance_valid(target):
		return

	target.lock_rotation = true
	
	# target.linear_damp = 1.0 
	
	var ice_cube_instance = ice_cube_scene.instantiate()
	var ice_cube := ice_cube_instance as IceCube
	if ice_cube == null:
		ice_cube = ice_cube_instance.get_node_or_null("Area3D") as IceCube
		
	ice_cube.frozen_ball = target
	
	target.add_child(ice_cube_instance)
	
	ice_cube_instance.position = Vector3.ZERO
	ice_cube_instance.rotation = Vector3.ZERO
