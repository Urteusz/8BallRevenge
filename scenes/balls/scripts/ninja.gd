extends BallParent
class_name NinjaBall

@export var hits_to_kill: int = 3

@onready var aura_mesh: MeshInstance3D = $AuraMesh

var hit_count: int = 0
var charged: bool = false

var aura_colors = [
	Color(0.5, 0.0, 0.5),# 0 hits - dark purple
	Color(1.0, 0.9, 0.2),# 1 hit: bright yellow
	Color(1.0, 0.5, 0.0),# 2 hits - orange
	Color(1.0, 0.2, 0.0)# charged - red
]

func _ready():
	super()
	if not is_in_group("balls"):
		add_to_group("balls")
	_update_aura()

func _on_body_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	$AudioStreamPlayer3D.play()

	if body.is_in_group("table"):
		return

	# If player ball, just score points without ninja mechanics (no stacks, no killing)
	if body.name == "PlayerBall":
		on_hit()  # Score points like normal ball
		return

	if not (body.is_in_group("balls") and body != self):
		return

	on_hit()

	if charged:
		# Charged - kill this ball
		charged = false
		hit_count = 0
		_update_aura()
		_kill_ball(body)
	else:
		# Charging - count hit
		hit_count += 1
		if hit_count >= hits_to_kill:
			charged = true
		_update_aura()

func _update_aura():
	if not aura_mesh:
		return
	var mat = aura_mesh.mesh.material as ShaderMaterial
	if not mat:
		return

	var intensity: float
	var color_index: int
	if charged:
		intensity = 1.0
		color_index = 3
	else:
		intensity = float(hit_count) / float(hits_to_kill)
		color_index = clampi(hit_count, 0, aura_colors.size() - 1)

	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("aura_color", aura_colors[color_index])

func _kill_ball(ball: Node) -> void:
	if not is_instance_valid(ball):
		return
	if ball.has_method("pocketed"):
		ball.pocketed()
	else:
		ball.queue_free()
