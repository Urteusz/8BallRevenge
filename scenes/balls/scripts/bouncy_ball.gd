extends BallParent
class_name BouncyBall

# Konfiguracja
@export var wall_bounce_multiplier: float = 1.3
@export var ball_impact_dampening: float = 0.6
@export var cooldown_time: float = 0.1
@export var start_delay: float = 2.0 

var can_apply_modifier: bool = true
var abilities_enabled: bool = false

func _ready():
	super._ready()
	contact_monitor = true
	max_contacts_reported = 4
	
	abilities_enabled = true
	
	# Ensure correct physics layers are set immediately (Standard Ball Layers)
	collision_mask = 5 # Table (1) + Balls (4/Layer 3)
	collision_layer = 4 # Balls layer (Layer 3)

func on_hit():
	super.on_hit()

func _on_body_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	# Standard Ball Behavior (Sound + Scoring)
	$AudioStreamPlayer3D.play()
	
	if body.is_in_group("table"):
		return
		
	# Call scoring logic for any valid hit (walls, balls, etc.)
	on_hit()

	if body == self or not can_apply_modifier:
		return

	# --- 1. ODBICIE OD ŚCIANY ---
	# Pamiętaj o ustawieniu grupy "walls" dla band w edytorze!
	if body.is_in_group("walls"):
		if abilities_enabled:
			# Sprawdzenie prędkości, żeby nie przyspieszała przy toczeniu
			if linear_velocity.length() > 1.0:
				linear_velocity = linear_velocity * wall_bounce_multiplier
				print("Boost od ściany!")
				_start_cooldown()
		return

	# --- 2. KOLIZJA Z INNYMI OBIEKTAMI ---
	if body is RigidBody3D:
		if body.name == "PlayerBall":
			print("Kontakt z białą")
		else:
			if abilities_enabled:
				linear_velocity = linear_velocity * ball_impact_dampening
				print("Hamowanie na innej bili")
				_start_cooldown()

func _start_cooldown():
	can_apply_modifier = false
	await get_tree().create_timer(cooldown_time).timeout
	can_apply_modifier = true
