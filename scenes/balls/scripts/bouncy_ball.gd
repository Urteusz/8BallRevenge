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
	base_value = 400
	contact_monitor = true
	max_contacts_reported = 4
	
	# --- FIX RESPAWNU: TRYB DUCHA ---
	# Wyłączamy kolizję z innymi bilami na starcie, żeby nie wybuchały.
	
	# 1. Ustawiamy Maskę na 1 (widzimy tylko Stół/Layer 1). 
	# Ignorujemy Layer 2 (inne bile).
	collision_mask = 1 
	
	# 2. Ustawiamy naszą Warstwę na 0 (lub inną pustą), 
	# żeby inne bile nas "nie widziały" i nie odpychały się od nas.
	# (Zakładając, że normalnie bile są na Layer 2)
	collision_layer = 0 
	
	print("Bila w trybie ducha (przenika inne bile)...")

	# Czekamy na koniec respa
	await get_tree().create_timer(start_delay).timeout
	
	# --- KONIEC FAZY DUCHA ---
	abilities_enabled = true
	
	# Przywracamy normalną fizykę
	# Teraz widzimy stół (1) i bile (2) -> Wartość binarna 1+2 = 3
	collision_mask = 3 
	
	# My też wracamy na warstwę 2, żeby inne bile nas widziały
	collision_layer = 2 
	
	print("BouncyBall: Fizyka i umiejętności włączone!")

func on_hit():
	super.on_hit()

func _on_body_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if body == self or not can_apply_modifier:
		return

	# --- 1. ODBICIE OD ŚCIANY ---
	# Pamiętaj o ustawieniu grupy "walls" dla band w edytorze!
	if body.is_in_group("walls"):
		$AudioStreamPlayer3D.play()
		
		if abilities_enabled:
			# Sprawdzenie prędkości, żeby nie przyspieszała przy toczeniu
			if linear_velocity.length() > 1.0:
				linear_velocity = linear_velocity * wall_bounce_multiplier
				print("Boost od ściany!")
				_start_cooldown()
		return

	# --- 2. KOLIZJA Z INNYMI OBIEKTAMI ---
	if body is RigidBody3D:
		on_hit()
		$AudioStreamPlayer3D.play()
		
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
