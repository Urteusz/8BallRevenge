extends Area3D

var soundPocket: AudioStreamPlayer3D

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
	if body is RigidBody3D or body.has_method("pocketed"):
		print("Wpadło do fałszywej łuzy: ", body.name)
		
		# 1. Odtwórz Dźwięk
		if body.is_in_group("playerBall"):
			change_and_play_sound(snd_player)
		else:
			change_and_play_sound(snd_pocket)
			
		# 2. Logika wypadnięcia
		if body.has_method("pocketed"):
			body.pocketed() 
		else:
			# Fallback - po prostu usuń piłkę
			body.queue_free()

func change_and_play_sound(sound: AudioStream):
	if soundPocket.playing:
		soundPocket.stop()
	soundPocket.stream = sound
	soundPocket.play()
