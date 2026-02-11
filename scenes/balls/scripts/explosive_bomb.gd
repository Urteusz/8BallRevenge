extends BallParent
class_name ExplosiveBomb

@export var explosion_radius: float = 5.0
@export var explosion_force: float = 2.0
@export var explosion_cooldown: float = 0.4
@export var smoke_effect: GPUParticles3D
@export var shockwave_effect: GPUParticles3D
@export var fuze_effect: GPUParticles3D

signal explosion_happened(position: Vector3, force: float)

var _is_exploding_locked: bool = false
var _base_fuze_amount: int = 0
var _bomb_mesh: MeshInstance3D


func _ready():
	super()

	if smoke_effect: smoke_effect.emitting = false
	if shockwave_effect: shockwave_effect.emitting = false
	if fuze_effect:
		fuze_effect.emitting = true
		_base_fuze_amount = fuze_effect.amount

	_bomb_mesh = _find_mesh()


func _process(_delta: float) -> void:
	if fuze_effect and fuze_effect.emitting:
		var speed: float = linear_velocity.length()
		var intensity: float = clampf(speed / 5.0, 0.3, 2.5)
		fuze_effect.amount = int(_base_fuze_amount * intensity)
		fuze_effect.speed_scale = lerpf(0.8, 2.0, clampf(speed / 5.0, 0.0, 1.0))


func _on_body_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if _is_exploding_locked:
		return
	if not body.is_in_group("balls") and body.name != "PlayerBall":
		return

	_is_exploding_locked = true

	$AudioStreamPlayer3D.play()
	on_hit()

	var collision_position = global_position
	if smoke_effect:
		smoke_effect.global_position = collision_position
		smoke_effect.restart()
		smoke_effect.emitting = true
	if shockwave_effect:
		shockwave_effect.global_position = collision_position
		shockwave_effect.restart()
		shockwave_effect.emitting = true

	_flash_bomb()
	explode()
	_camera_shake()

	await get_tree().create_timer(explosion_cooldown).timeout
	_is_exploding_locked = false


func explode():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = global_transform
	query.exclude = [self.get_rid()]
	query.collision_mask = 4

	var results = space_state.intersect_shape(query, 64)

	for result in results:
		var body = result["collider"]

		if body is RigidBody3D and body != self:
			body.sleeping = false

			var direction = (body.global_position - global_position).normalized()
			if direction == Vector3.ZERO: direction = Vector3.UP

			var distance = global_position.distance_to(body.global_position)
			var force_multiplier = 1.0 - (distance / explosion_radius)
			force_multiplier = clamp(force_multiplier, 0.0, 1.0)

			var force = direction * explosion_force * force_multiplier
			body.apply_central_impulse(force)

			_flash_hit_ball(body)

	# Odrzut bomby (reakcja Newtona)
	var random_dir := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(0.2, 0.8),
		randf_range(-1.0, 1.0)
	).normalized()
	apply_central_impulse(random_dir * explosion_force * 0.3)

	explosion_happened.emit(global_position, explosion_force)


func _flash_bomb() -> void:
	if not _bomb_mesh:
		return

	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.1)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	_bomb_mesh.material_overlay = mat

	var tween := create_tween()
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): _bomb_mesh.material_overlay = null)


func _flash_hit_ball(body: Node) -> void:
	var mesh: MeshInstance3D = _find_mesh_in(body)
	if not mesh:
		return

	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	mesh.material_overlay = mat

	var tween := body.create_tween()
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): mesh.material_overlay = null)


func _camera_shake() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var original_pos := camera.global_position
	var tween := get_tree().create_tween()
	var shake_strength := 0.15

	for i in 6:
		var offset := Vector3(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		tween.tween_property(camera, "global_position", original_pos + offset, 0.04)
		shake_strength *= 0.7

	tween.tween_property(camera, "global_position", original_pos, 0.04)


func _find_mesh() -> MeshInstance3D:
	return _find_mesh_in(self)


static func _find_mesh_in(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var found := _find_mesh_in(child)
		if found:
			return found
	return null
