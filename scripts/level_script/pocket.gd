extends Area3D

@export var pocket_effect: PackedScene
@export var uniParticles: UniParticles3D
@export var start_color_entered: Color = Color.DARK_GREEN
@export var end_color_entered: Color = Color.GREEN
var og_gradient_texture
var color_changed = false

func _ready() -> void:
	body_entered.connect(_on_pocket_body_entered)
	og_gradient_texture = GradientTexture1D.new()
	print("Pocket ready, effect assigned: ", pocket_effect != null)

func _on_pocket_body_entered(body: Node3D) -> void:
	print("Body entered pocket: ", body.name, self.name)
	
	if body is BallParent:
		print("Body is BallParent!")
		_show_pocket_effect(body.global_position)
		
		if uniParticles:
			og_gradient_texture = uniParticles.color_over_lifetime
			_set_particle_gradient_transition(uniParticles, start_color_entered, end_color_entered)
		
		
		if body.has_method("pocketed"):
			body.pocketed()
		else:
			push_warning("BallParent doesn't have pocketed() method")
	else:
		print("Body is NOT BallParent, it's: ", body.get_class())

func _process(delta: float) -> void:
	if color_changed && uniParticles:
		await get_tree().create_timer(5.0).timeout
		uniParticles.color_over_lifetime = og_gradient_texture

func _show_pocket_effect(pocket_position: Vector3) -> void:
	if !pocket_effect:
		push_warning("Pocket effect scene missing")
		return
	
	var effect_instance = pocket_effect.instantiate()
	get_tree().root.add_child(effect_instance)
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
	color_changed = true
