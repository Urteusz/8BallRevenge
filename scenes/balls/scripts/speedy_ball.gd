extends BallParent
class_name SpeedyBall

# Konfiguracja supermocy
@export var speed_multiplier: float = 5 
@export var self_boost: float = 0.5   
@export var boost_cooldown: float = 0.5 
@export var min_speed_for_boost: float = 2.0 

# Efekty wizualne
@export var trail_effect: GPUParticles3D
@export var impact_effect: GPUParticles3D

var can_boost: bool = true

func _ready():
	super._ready()

	mass = 0.17
	linear_damp = 0.05
	
	if !physics_material_override:
		physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.8
	physics_material_override.friction = 0.3
	
	if trail_effect:
		trail_effect.emitting = false
	if impact_effect:
		impact_effect.emitting = false

func _process(_delta):
	if trail_effect:
		trail_effect.emitting = linear_velocity.length() > 2.0

func on_hit():
	super.on_hit()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if !can_boost:
		return
		
	if state.linear_velocity.length() < min_speed_for_boost:
		return

	for i in range(state.get_contact_count()):
		var contact_normal = state.get_contact_local_normal(i)
		
		# Ignorujemy podłogę (pionowa normalna). Interesują nas ściany/bandy (pozioma normalna).
		if abs(contact_normal.y) < 0.6:
			var collider = state.get_contact_collider_object(i)
			
			if collider.is_in_group("table") or collider.is_in_group("walls") or collider is RigidBody3D:
				var bounce_direction = state.linear_velocity.normalized()
				bounce_direction.y = 0.0
				bounce_direction = bounce_direction.normalized()
				
				apply_central_impulse(bounce_direction * self_boost)
				
				_start_cooldown()
				break

func _on_body_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if body == self:
		return

	if body is RigidBody3D:
		on_hit()
		$AudioStreamPlayer3D.play()

		if impact_effect:
			impact_effect.global_position = global_position
			impact_effect.restart()
			impact_effect.emitting = true

func _start_cooldown():
	can_boost = false
	await get_tree().create_timer(boost_cooldown).timeout
	can_boost = true
