extends Area3D

@export var pocket_effect: PackedScene
@onready var uniParticles = $UniParticles3D
@onready var soundPocket = $AudioStreamPlayer3D 
@export var firstColorBall: Color = Color.DARK_GREEN
@export var lastColorBall: Color = Color.GREEN
@export var firstColorPlayerBall: Color = Color.WEB_MAROON
@export var lastColorPlayerBall: Color = Color.ORANGE_RED

@export_group("Pocket Assist")
@export var assist_radius: float = 1.5
@export var assist_strength: float = 2.0
@export var assist_max_speed: float = 1.0

var og_gradient_texture
var color_reset_timer: SceneTreeTimer

var snd_pocket = preload("res://sounds/Pocketed.wav")
var snd_player = preload("res://sounds/Pocketed_player.wav")

func _ready() -> void:
	body_entered.connect(_on_pocket_body_entered)
	og_gradient_texture = uniParticles.color_over_lifetime
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
		_show_pocket_effect(body.global_position)
		if uniParticles:
			if body not in get_tree().get_nodes_in_group("playerBall"):
				change_and_play_sound(snd_pocket)
				_set_particle_gradient_transition(uniParticles, firstColorBall, lastColorBall)
			else:
				change_and_play_sound(snd_player)
				_set_particle_gradient_transition(uniParticles, firstColorPlayerBall, lastColorPlayerBall)
			_reset_particle_color_after_delay()
			
			
		if body.has_method("pocketed"):
			body.pocketed()
		else:
			push_warning("BallParent doesn't have pocketed() method")

func _reset_particle_color_after_delay():
	color_reset_timer = get_tree().create_timer(5.0)
	await color_reset_timer.timeout
	color_reset_timer = null
	if uniParticles:
		uniParticles.color_over_lifetime = og_gradient_texture

func _show_pocket_effect(pocket_position: Vector3) -> void:
	if !pocket_effect:
		push_warning("Pocket effect scene missing")
		return
	
	var effect_instance = pocket_effect.instantiate()
	get_parent().add_child(effect_instance)
	effect_instance.global_position = pocket_position

	
	print("Effect spawned at: ", pocket_position)
	
	effect_instance.emitting = true
func _set_particle_gradient_transition(particles: UniParticles3D, start_color: Color, end_color: Color) -> void:
	particles.enable_color_over_lifetime = Vector2i(1, 0)
	
	var gradient = Gradient.new()
	gradient.set_color(0, start_color)  # Kolor początkowy
	gradient.set_color(0.5, end_color)    # Kolor końcowy
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particles.color_over_lifetime = gradient_texture

func change_and_play_sound(sound: AudioStream):
	soundPocket.stream = sound
	soundPocket.play()
