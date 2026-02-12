extends Area3D

@export var pocket_effect: PackedScene
@export var particle_scene: PackedScene
@export var uniParticlesYPos: float = 1.5

var soundPocket: AudioStreamPlayer3D

@export_group("Loop Particle Gradients")
@export var og_gradient_texture: GradientTexture1D
@export var ball_pocketed_gradient: GradientTexture1D
@export var player_pocketed_gradient: GradientTexture1D

@export_group("Pocket Assist")
@export var assist_radius: float = 2.5
@export var assist_strength: float = 2.5
@export var assist_max_speed: float = 1.0

var uniParticles: Node3D
var color_reset_timer: SceneTreeTimer
var pocketed_balls: Array = []  # Lista piłek już pocketowanych

var snd_pocket = preload("res://sounds/Pocketed.wav")
var snd_player = preload("res://sounds/Pocketed_player.wav")

func _ready() -> void:
	if not particle_scene:
		particle_scene = preload("res://scenes/particles/particlePocketLoop1.tscn")
	soundPocket = AudioStreamPlayer3D.new()
	add_child(soundPocket)

	body_entered.connect(_on_pocket_body_entered)

	uniParticles = particle_scene.instantiate()
	add_child(uniParticles)
	uniParticles.position = Vector3(0, uniParticlesYPos, 0)

	if og_gradient_texture:
		uniParticles.color_over_lifetime = og_gradient_texture

	print("Pocket ready, effect assigned: ", pocket_effect != null)

func _physics_process(_delta: float) -> void:
	if !uniParticles:
		return

	var target = uniParticles.global_position
	for ball in get_tree().get_nodes_in_group("balls"):
		if !is_instance_valid(ball) or !(ball is RigidBody3D):
			continue

		var distance = ball.global_position.distance_to(target)
		if distance > assist_radius or distance < 0.01:
			continue

		if ball.linear_velocity.length() > assist_max_speed:
			continue

		var factor = 1.0 - (distance / assist_radius)
		var direction = (target - ball.global_position).normalized()
		ball.apply_central_force(direction * assist_strength * factor)

func _on_pocket_body_entered(body: Node3D) -> void:
	print("Body entered pocket: ", body.name, self.name)

	if body is BallParent:
		# Sprawdź czy piłka już została pocketowana (zabezpieczenie przed wielokrotnym wywołaniem)
		# UWAGA: Player ball NIE jest dodawany do listy, bo może wpadać wielokrotnie
		var is_player = body.is_in_group("playerBall")
		if not is_player:
			if body in pocketed_balls:
				return
			pocketed_balls.append(body)

		_show_pocket_effect(self.global_position)
		if uniParticles:
			if not is_player:
				change_and_play_sound(snd_pocket)
				if ball_pocketed_gradient:
					_set_particle_gradient(uniParticles, ball_pocketed_gradient)
			else:
				change_and_play_sound(snd_player)
				if player_pocketed_gradient:
					_set_particle_gradient(uniParticles, player_pocketed_gradient)
			_reset_particle_color_after_delay()

		if body.has_method("pocketed"):
			body.pocketed()
		else:
			push_warning("BallParent doesn't have pocketed() method")

func _reset_particle_color_after_delay():
	color_reset_timer = get_tree().create_timer(5.0)
	await color_reset_timer.timeout
	color_reset_timer = null
	if uniParticles and og_gradient_texture:
		uniParticles.color_over_lifetime = og_gradient_texture

func _show_pocket_effect(pocket_position: Vector3) -> void:
	if !pocket_effect:
		return
	
	var effect_instance = pocket_effect.instantiate()
	get_parent().add_child(effect_instance)
	effect_instance.global_position = pocket_position
	
	print("Effect spawned at: ", pocket_position)
	
	effect_instance.emitting = true

func _set_particle_gradient(particles: Node3D, gradient_tex: GradientTexture1D) -> void:
	particles.enable_color_over_lifetime = Vector2i(1, 0)
	particles.color_over_lifetime = gradient_tex

func change_and_play_sound(sound: AudioStream):
	soundPocket.stream = sound
	soundPocket.play()
