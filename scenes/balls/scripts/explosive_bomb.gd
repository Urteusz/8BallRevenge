extends BallParent
class_name ExplosiveBomb

@export var extra_speed: float = 10.0
@export var explosion_radius: float = 5.0
@export var explosion_force: float = 20.0
@export var explosion_cooldown: float = 0.4 
@export var smoke_effect: GPUParticles3D
@export var shockwave_effect: GPUParticles3D
@export var fuze_effect: GPUParticles3D

var can_explode: bool = true 

func _ready():
	super._ready()
	base_value = 500
	
	if smoke_effect:
		smoke_effect.emitting = false
	if shockwave_effect:
		shockwave_effect.emitting = false
	if fuze_effect:
		fuze_effect.emitting = true


func on_hit():
	print("points")
	super.on_hit()


func _on_body_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if !can_explode or body.is_in_group("table"):
		return
	
	$AudioStreamPlayer3D.play()
	var collision_position = global_position
	on_hit()
	
	if body.name != "PlayerBall":
		if smoke_effect:
			smoke_effect.global_position = collision_position
			smoke_effect.restart()
			smoke_effect.emitting = true
			
		if shockwave_effect:
			shockwave_effect.global_position = collision_position
			shockwave_effect.restart()
			shockwave_effect.emitting = true
	
	can_explode = false
	
	explode()
	
	await get_tree().create_timer(explosion_cooldown).timeout
	can_explode = true


func explode():
	print("BOOM! Eksplozja w pozycji: ", global_position)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = global_transform
	query.exclude = [self]
	
	var results = space_state.intersect_shape(query, 32)
	
	for result in results:
		var body = result["collider"]
		if body is RigidBody3D and body != self:
			var direction = (body.global_position - global_position).normalized()
			var distance = global_position.distance_to(body.global_position)
			var force_multiplier = 1.0 - (distance / explosion_radius)
			force_multiplier = clamp(force_multiplier, 0.0, 1.0)
			var force = direction * explosion_force * force_multiplier
			body.apply_central_impulse(force)
