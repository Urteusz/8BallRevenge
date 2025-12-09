extends BallParent
class_name BouncyBall

# Konfiguracja
@export var wall_bounce_multiplier: float = 5  # 2x szybciej po odbiciu od ściany
@export var ball_impact_dampening: float = 1.0   # 0.5x prędkości po uderzeniu w inną bilę (znaczne zwolnienie)
@export var cooldown_time: float = 0.1           # Krótki czas, żeby nie naliczać kolizji wielokrotnie

var can_apply_modifier: bool = true

func _ready():
	super._ready()
	base_value = 400 # Wartość punktowa
	
	# Upewnij się, że bila ma włączony Contact Monitor w kodzie lub inspektorze
	contact_monitor = true
	max_contacts_reported = 4

func on_hit():
	super.on_hit()

func _on_body_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if body == self or not can_apply_modifier:
		return

	# --- 1. ODBICIE OD ŚCIANY (MOCNIEJ) ---
	if body.is_in_group("walls"):
		$AudioStreamPlayer3D.play()
		
		# Dajemy "kopa" w aktualnym kierunku ruchu (odbicie już nastąpiło fizycznie)
		# Mnożymy wektor prędkości, żeby przyspieszyła
		linear_velocity = linear_velocity * wall_bounce_multiplier
		
		print("WallHunter: Boost od ściany!")
		_start_cooldown()
		return

	# --- 2. ODBICIE OD CZEGOŚ INNEGO ---
	if body is RigidBody3D:
		# Zawsze naliczamy punkty i gramy dźwięk
		on_hit()
		$AudioStreamPlayer3D.play()
		
		# Sprawdzamy, czy to biała bila
		if body.name == "PlayerBall":
			# BIAŁA BILA: Ignorujemy modyfikatory. 
			# Fizyka zadziała standardowo (odbiją się jak zwykłe kule).
			print("WallHunter: Kontakt z białą - standardowa fizyka")
		
		else:
			# INNA BILA: "Przyklejamy się" / Tracimy energię
			# Zmniejszamy drastycznie prędkość naszej bili
			linear_velocity = linear_velocity * ball_impact_dampening
			
			print("WallHunter: Zderzenie z inną bilą - hamowanie")
		
		_start_cooldown()

func _start_cooldown():
	can_apply_modifier = false
	await get_tree().create_timer(cooldown_time).timeout
	can_apply_modifier = true
