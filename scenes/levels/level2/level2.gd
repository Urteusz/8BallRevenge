extends Node

@onready var game_manager = $SubViewportContainer/SubViewport/GameManager
@onready var sandstorm_node = $SubViewportContainer/SubViewport/Sandstorm
@onready var sand_particles = $SubViewportContainer/SubViewport/Sandstorm/SandParticles
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var wind_audio: AudioStreamPlayer3D = $SubViewportContainer/SubViewport/AudioStreamPlayer3D

const SANDSTORM_START_MOVE: int = 6
const SANDSTORM_END_MOVE: int = 3
const WIND_DIRECTION = Vector3(1, 0, 0)

const WIND_FORCE: float = 0.2
const WIND_FORCE_MILD: float = 0.05  # Lekki podmuch przed/po burzy

# Fog: progresywna widoczność
const FOG_DENSITY_OFF: float = 0.0
const FOG_DENSITY_MAX: float = 0.06

var sandstorm_active: bool = false
var sandstorm_full: bool = false
var initial_moves: int = 0
var sandstorm_intensity: float = 0.0
var current_fog: float = 0.0
var target_fog: float = 0.0
const FOG_LERP_SPEED: float = 0.4

# Audio wiatru
const WIND_VOLUME_MIN_DB: float = -40.0
const WIND_VOLUME_MAX_DB: float = -10.0
const WIND_AUDIO_LERP_SPEED: float = 0.5
var current_wind_volume_db: float = -80.0
var target_wind_volume_db: float = -80.0

func _ready() -> void:
	if game_manager:
		initial_moves = game_manager.default_level_move_count
		game_manager.moves_changed.connect(_on_moves_changed)

	if sand_particles:
		sand_particles.emitting = false

	_set_fog_density(FOG_DENSITY_OFF)
	_setup_wind_audio()

func _on_moves_changed(moves_left: int) -> void:
	_update_sandstorm(moves_left)
	_update_fog(moves_left)

func _update_sandstorm(moves_left: int) -> void:
	# Pełna burza w zakresie 6-3, lekki podmuch 1 ruch przed i po (7 i 2)
	var should_be_active = moves_left <= SANDSTORM_START_MOVE and moves_left >= SANDSTORM_END_MOVE
	var is_mild = not should_be_active and (
		moves_left == SANDSTORM_START_MOVE + 1 or moves_left == SANDSTORM_END_MOVE - 1
	)

	sandstorm_full = should_be_active
	var any_wind = should_be_active or is_mild
	if any_wind != sandstorm_active:
		sandstorm_active = any_wind
		if sand_particles:
			sand_particles.emitting = sandstorm_active

func _update_fog(moves_left: int) -> void:
	if initial_moves == 0:
		return

	# Środek burzy = najgęstsza mgła
	var storm_center = float(SANDSTORM_START_MOVE + SANDSTORM_END_MOVE) / 2.0
	# Mgła narasta od początku gry do środka burzy, potem opada do końca
	var distance_from_peak = absf(float(moves_left) - storm_center)
	var max_distance = float(initial_moves) - storm_center
	var fog_ratio = 1.0 - clampf(distance_from_peak / max_distance, 0.0, 1.0)

	target_fog = lerp(FOG_DENSITY_OFF, FOG_DENSITY_MAX, fog_ratio)

	# Głośność wiatru podąża za tą samą krzywą co fog
	if fog_ratio > 0.01:
		target_wind_volume_db = lerp(WIND_VOLUME_MIN_DB, WIND_VOLUME_MAX_DB, fog_ratio)
	else:
		target_wind_volume_db = -80.0

func _setup_wind_audio() -> void:
	if not wind_audio:
		return
	wind_audio.volume_db = -80.0
	wind_audio.play()

func _set_fog_density(density: float) -> void:
	if world_env and world_env.environment:
		world_env.environment.fog_density = density

func _process(delta: float) -> void:
	# Płynne przejście mgły
	if absf(current_fog - target_fog) > 0.0001:
		current_fog = lerp(current_fog, target_fog, FOG_LERP_SPEED * delta)
		_set_fog_density(current_fog)

	# Płynne przejście głośności wiatru
	if wind_audio and absf(current_wind_volume_db - target_wind_volume_db) > 0.1:
		current_wind_volume_db = lerp(current_wind_volume_db, target_wind_volume_db, WIND_AUDIO_LERP_SPEED * delta)
		wind_audio.volume_db = current_wind_volume_db

func _physics_process(delta: float) -> void:
	if not sandstorm_active or not game_manager:
		return

	var strength = WIND_FORCE if sandstorm_full else WIND_FORCE_MILD
	var wind_force = WIND_DIRECTION.normalized() * strength

	var all_balls = get_tree().get_nodes_in_group("balls")

	for ball in all_balls:
		if ball is RigidBody3D:
			ball.sleeping = false
			ball.apply_central_force(wind_force)
