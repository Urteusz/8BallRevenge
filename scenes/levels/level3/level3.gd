extends Node

@onready var game_manager = $SubViewportContainer/SubViewport/GameManager
@onready var rain_node = $SubViewportContainer/SubViewport/RainParticle
@onready var base_rain = $SubViewportContainer/SubViewport/RainParticle/GPUParticles3D

var initial_moves: int = 0
var extra_rain_layers: Array[GPUParticles3D] = []
const RAIN_LAYERS_COUNT: int = 5
const MIN_GRAVITY: float = -8.0
const MAX_GRAVITY: float = -20.0

func _ready() -> void:
	if game_manager:
		initial_moves = game_manager.default_level_move_count
		game_manager.moves_changed.connect(_on_moves_changed)

	_create_rain_layers()
	_update_rain_intensity(initial_moves)

func _create_rain_layers() -> void:
	if not base_rain or not rain_node:
		return

	# Move rain further from camera (increase Z offset)
	rain_node.position.z -= 3.0

	for i in range(RAIN_LAYERS_COUNT):
		var new_rain = base_rain.duplicate() as GPUParticles3D
		rain_node.add_child(new_rain)
		new_rain.emitting = false

		# Duplicate process material
		new_rain.process_material = new_rain.process_material.duplicate()

		# Adjust emission box to avoid particles near camera
		var mat = new_rain.process_material as ParticleProcessMaterial
		if mat:
			# Keep particles away from camera front
			mat.emission_box_extents = Vector3(10, 1, 12)

		extra_rain_layers.append(new_rain)

func _on_moves_changed(moves_left: int) -> void:
	_update_rain_intensity(moves_left)

func _update_rain_intensity(moves_left: int) -> void:
	if initial_moves == 0 or not base_rain:
		return

	# Calculate intensity: 0.0 (full moves) to 1.0 (no moves)
	var intensity = 1.0 - (float(moves_left) / float(initial_moves))

	# Update gravity - rain falls faster as moves decrease
	var current_gravity = lerp(MIN_GRAVITY, MAX_GRAVITY, intensity)
	var base_material = base_rain.process_material as ParticleProcessMaterial
	if base_material:
		base_material.gravity = Vector3(0, current_gravity, 0)

	# Update color - more intense red as moves decrease
	var color_intensity = lerp(0.5, 1.0, intensity)
	var alpha = lerp(0.3, 0.7, intensity)
	var draw_pass = base_rain.draw_pass_1 as QuadMesh
	if draw_pass and draw_pass.material:
		var mat = draw_pass.material as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(color_intensity, 0, 0, alpha)

	# Base rain is always on
	base_rain.emitting = true

	# Enable extra layers based on intensity
	var layers_to_enable = int(intensity * RAIN_LAYERS_COUNT)

	for i in range(extra_rain_layers.size()):
		var should_emit = i < layers_to_enable
		if extra_rain_layers[i].emitting != should_emit:
			extra_rain_layers[i].emitting = should_emit

		# Update gravity for extra layers too
		if should_emit:
			var layer_material = extra_rain_layers[i].process_material as ParticleProcessMaterial
			if layer_material:
				layer_material.gravity = Vector3(0, current_gravity, 0)

	print("Moves: ", moves_left, " | Layers: ", layers_to_enable + 1, "/", RAIN_LAYERS_COUNT + 1, " | Gravity: %.1f | Color: %.2f" % [current_gravity, color_intensity])
