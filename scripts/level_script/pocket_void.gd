extends Area3D

var soundPocket: AudioStreamPlayer3D
var pocketed_balls: Array = []  # Lista piłek już pocketowanych

# Preload dźwięków
var snd_pocket = preload("res://sounds/Pocketed.wav")
var snd_player = preload("res://sounds/Pocketed_player.wav")

func _ready() -> void:
	# Tworzymy audio player
	soundPocket = AudioStreamPlayer3D.new()
	add_child(soundPocket)

	# Podłączamy sygnał wejścia
	body_entered.connect(_on_pocket_body_entered)

func _on_pocket_body_entered(body: Node3D) -> void:
	# Sprawdzamy czy to piłka (zakładam, że piłki dziedziczą po RigidBody3D lub mają klasę BallParent)
	if body is RigidBody3D or body.has_method("pocketed_void"):
		# Sprawdź czy piłka już została pocketowana (zabezpieczenie przed wielokrotnym wywołaniem)
		# UWAGA: Player ball NIE jest dodawany do listy, bo może wpadać wielokrotnie
		var is_player = body.is_in_group("playerBall")
		if not is_player:
			if body in pocketed_balls:
				return
			pocketed_balls.append(body)

		print("Wpadło do fałszywej łuzy (void pocket): ", body.name)

		# 1. Odtwórz Dźwięk
		if is_player:
			change_and_play_sound(snd_player)
		else:
			change_and_play_sound(snd_pocket)

		# 2. Logika wypadnięcia BEZ PUNKTÓW
		if body.has_method("pocketed_void"):
			print("Wywołuję pocketed_void() dla: ", body.name)
			body.pocketed_void()  # Wywołaj pocketowanie bez punktów
		elif body.has_method("pocketed"):
			print("Brak pocketed_void(), używam pocketed() dla: ", body.name)
			body.pocketed()  # Fallback na normalną metodę
		else:
			# Fallback - po prostu usuń piłkę
			print("Brak metod pocketowania, usuwam: ", body.name)
			body.queue_free()

func change_and_play_sound(sound: AudioStream):
	if soundPocket.playing:
		soundPocket.stop()
	soundPocket.stream = sound
	soundPocket.play()
