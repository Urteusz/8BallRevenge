extends Node3D

@onready var game_manager = $SubViewportContainer/SubViewport/GameManager
@onready var lights_node = $SubViewportContainer/SubViewport/TableCircle2/Lights
@onready var pockets_node = $SubViewportContainer/SubViewport/TableCircle2/Pockets
@onready var center_light: SpotLight3D = $SubViewportContainer/SubViewport/TableCircle2/Lights/SpotLightCenter

const TOTAL_POCKET_LIGHTS: int = 8
const LIGHT_FADE_DURATION: float = 0.5
const CENTER_LIGHT_FADE_DURATION: float = 0.3
const FLICKER_DURATION: float = 2.5
const FLICKER_DIM_RATIO: float = 0.15
const BASE_LIGHT_ENERGY: float = 20.0
const BASE_CENTER_ENERGY: float = 15.0

var pocket_to_light: Dictionary = {}
var lights_on: Dictionary = {}
var lights_on_count: int = TOTAL_POCKET_LIGHTS
var initial_ball_count: int = 0
var light_tweens: Dictionary = {}

func _ready() -> void:
	# Buduj mapowanie pocket -> spotlight po indeksie 0-7
	for i in range(TOTAL_POCKET_LIGHTS):
		var pocket_name = "Pocket%d" % i
		var light_name = "SpotLight3D%d" % i
		var pocket = pockets_node.get_node_or_null(pocket_name)
		var light = lights_node.get_node_or_null(light_name)
		if pocket and light:
			pocket_to_light[pocket] = light
			lights_on[light] = true
			pocket.body_entered.connect(_on_pocket_body_entered.bind(pocket))

	if game_manager:
		game_manager.moves_changed.connect(_on_moves_changed)
		game_manager.ball_pocketed.connect(_on_ball_pocketed_signal)
		await get_tree().process_frame
		initial_ball_count = game_manager.ball_list.size()

func _on_pocket_body_entered(body: Node3D, pocket: Area3D) -> void:
	# Reaguj tylko na kule które nie są gracza
	if not body is RigidBody3D:
		return
	if body.is_in_group("playerBall"):
		return

	var light = pocket_to_light.get(pocket)
	if light and lights_on.get(light, false):
		var particle_node = null
		for child in pocket.get_children():
			if child is UniParticles3D:
				particle_node = child
				break
		if particle_node:
			particle_node.emitting = false
		_fade_out_light(light)

func _fade_out_light(light: SpotLight3D) -> void:
	lights_on[light] = false
	lights_on_count -= 1

	# Zabij istniejący tween (np. flicker) żeby nie przywrócił energii
	if light_tweens.has(light) and light_tweens[light] != null and light_tweens[light].is_valid():
		light_tweens[light].kill()

	# Gaś światło nad pocketem
	var tween = create_tween()
	tween.tween_property(light, "light_energy", 0.0, LIGHT_FADE_DURATION).set_ease(Tween.EASE_IN)
	light_tweens[light] = tween

	_update_center_light()

func _update_center_light() -> void:
	if not center_light or not game_manager:
		return
	# Bierzemy pod uwagę oba czynniki: zgaszone światła i pozostałe kule
	var lights_ratio = float(lights_on_count) / float(TOTAL_POCKET_LIGHTS)
	var balls_remaining = game_manager.ball_list.size()
	var balls_ratio = float(balls_remaining) / float(initial_ball_count) if initial_ball_count > 0 else 1.0

	var ratio = minf(lights_ratio, balls_ratio)
	var target_energy = BASE_CENTER_ENERGY * ratio
	var tween = create_tween()
	tween.tween_property(center_light, "light_energy", target_energy, CENTER_LIGHT_FADE_DURATION)

func _on_ball_pocketed_signal(_ball_id: int) -> void:
	# Kula usunięta z ball_list — aktualizuj centralne światło
	_update_center_light()

func _on_moves_changed(_moves_left: int) -> void:
	_flicker_random_lights()

func _flicker_random_lights() -> void:
	# Zbierz światła które jeszcze świecą
	var active_lights: Array[SpotLight3D] = []
	for light in lights_on:
		if lights_on[light]:
			active_lights.append(light)

	if active_lights.is_empty():
		return

	# Losowo 1-2 światła migają
	active_lights.shuffle()
	var flicker_count = mini(randi_range(1, 2), active_lights.size())

	for i in range(flicker_count):
		var light: SpotLight3D = active_lights[i]
		# Zabij poprzedni flicker tween jeśli jeszcze trwa
		if light_tweens.has(light) and light_tweens[light] != null and light_tweens[light].is_valid():
			light_tweens[light].kill()
			light.light_energy = BASE_LIGHT_ENERGY
		var original_energy = light.light_energy
		var dim_energy = original_energy * FLICKER_DIM_RATIO
		var tween = create_tween()
		tween.tween_property(light, "light_energy", dim_energy, FLICKER_DURATION)
		tween.tween_property(light, "light_energy", original_energy, FLICKER_DURATION)
		light_tweens[light] = tween
