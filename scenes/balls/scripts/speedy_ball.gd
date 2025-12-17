extends BallParent
class_name SpeedyBall

# Konfiguracja supermocy
@export var speed_multiplier: float = 5  # Mnożnik siły przekazywanej innej bili
@export var self_boost: float = 1.2        # Ile prędkości zachowuje/zyskuje po odbiciu od bandy
@export var boost_cooldown: float = 0.2    # Żeby nie "zwariowała" przy ciągłym styku

# Efekty wizualne
@export var trail_effect: GPUParticles3D   # Np. smuga ognia/światła za bilą
@export var impact_effect: GPUParticles3D  # Iskry przy uderzeniu

var can_boost: bool = true

func _ready():
	super._ready()
	base_value = 300 # Szybka bila może być warta mniej/więcej punktów
	
	
	if trail_effect:
		trail_effect.emitting = false
	if impact_effect:
		impact_effect.emitting = false

func _process(_delta):
	# Opcjonalnie: Włączaj smugę tylko gdy bila szybko się porusza
	if trail_effect:
		trail_effect.emitting = linear_velocity.length() > 1.0

func on_hit():
	super.on_hit()

# Główna logika kolizji
func _on_body_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	# 1. Zabezpieczenia i cooldown (tutaj też poprawiłem logikę punktów z poprzedniej rozmowy)
	if body == self:
		return

	# 2. Sprawdzamy czy to banda
	if body.is_in_group("table"):
		if can_boost:
			apply_central_impulse(linear_velocity.normalized() * self_boost)
			_start_cooldown()
		return 

	# 3. Kolizja z inną bilą / graczem
	if body is RigidBody3D:
		
		# --- PUNKTY I EFEKTY (zawsze) ---
		on_hit() 
		$AudioStreamPlayer3D.play()
		
		if impact_effect:
			impact_effect.global_position = global_position
			impact_effect.restart()
			impact_effect.emitting = true
		

			_start_cooldown()

func _start_cooldown():
	can_boost = false
	await get_tree().create_timer(boost_cooldown).timeout
	can_boost = true
