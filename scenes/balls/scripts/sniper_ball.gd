extends BallParent
class_name SniperBall

## Prędkość z jaką kula leci w stronę celu po zderzeniu z graczem
@export var sniper_speed: float = 25.0 # Zwiększyłem, bo 10.0 to często wolno w skali Godot

@onready var sniper_hit_sound: AudioStreamPlayer3D = $SniperHitSound

var _pending_snipe: bool = false
var _snipe_velocity: Vector3 = Vector3.ZERO

func _ready():
	super._ready()
	base_value = 400

func _on_body_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if body == self or body.is_in_group("table") or body.is_in_group("walls"):
		return
	
	# Jeśli uderzył inną kulę (nie gracza), odtwarzamy tylko dźwięk i zaliczamy hit
	if body.name != "PlayerBall":
		$AudioStreamPlayer3D.play()
		on_hit()
		return

	# --- Logika trafienia przez gracza ---
	on_hit()
	
	# 1. Obliczamy wektor uderzenia na podstawie POZYCJI, a nie prędkości.
	# To daje nam wektor "od gracza do snajpera".
	var impact_vector = (global_position - body.global_position).normalized()
	
	var target = _find_nearest_ball_in_direction(impact_vector)
	
	if target:
		sniper_hit_sound.play()
		
		# Obliczamy kierunek do celu
		var dir_to_target = (target.global_position - global_position).normalized()
		
		# 2. Snajper zawsze przyspiesza (ignorujemy obecną prędkość, narzucamy sniper_speed)
		# Możesz tu użyć max(), jeśli chcesz zachować pęd przy bardzo silnych uderzeniach.
		_snipe_velocity = dir_to_target * sniper_speed
		_pending_snipe = true
	else:
		# Brak celu w zasięgu wzroku - zwykłe uderzenie
		$AudioStreamPlayer3D.play()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_snipe:
		state.linear_velocity = _snipe_velocity
		# Opcjonalnie: Zerujemy prędkość kątową, żeby kula nie "kręciła się" dziwnie przy wystrzale
		state.angular_velocity = Vector3.ZERO 
		_pending_snipe = false

func _find_nearest_ball_in_direction(hit_dir: Vector3) -> Node:
	var best: Node = null
	var best_dist: float = INF
	# Kąt stożka widzenia (np. 0.5 to 60 stopni w każdą stronę, 0.0 to 90 stopni - cała półsfera)
	# Ustawienie 0.2 sprawia, że szuka bardziej "przed sobą" a nie idealnie na boki.
	var vision_dot_threshold = 0.2 

	for ball in get_tree().get_nodes_in_group("balls"):
		# Standardowe pominięcia
		if ball == self or ball.name == "PlayerBall":
			continue
		
		# 3. Rozszerzone sprawdzanie "martwych" kul
		if not is_instance_valid(ball) or ball.is_queued_for_deletion():
			continue
		# Jeśli masz flagę w kulach, np. 'is_falling', dodaj ją tutaj:
		# if "is_falling" in ball and ball.is_falling: continue
		
		var to_ball_vec = ball.global_position - global_position
		var dist = to_ball_vec.length()
		var to_ball_dir = to_ball_vec / dist # normalized
		
		# Sprawdzamy czy cel jest "z przodu" zgodnie z kierunkiem uderzenia
		if to_ball_dir.dot(hit_dir) < vision_dot_threshold:
			continue
			
		# 4. (Opcjonalnie) Raycast - sprawdzenie czy nie ma ściany po drodze.
		# W bilardzie rzadko potrzebne, chyba że stół ma dziwny kształt.
		
		if dist < best_dist:
			best_dist = dist
			best = ball

	return best
