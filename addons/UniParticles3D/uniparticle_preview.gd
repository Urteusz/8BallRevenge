@tool
extends Control

var linked_particles: UniParticles3D

@onready var play_button: Button = %PlayButton
@onready var stop_button: Button = %StopButton
@onready var restart_button: Button = %RestartButton
@onready var time_label: Label = %TimeLabel
@onready var speed_spinbox: SpinBox = %SpeedSpinBox
@onready var actual_time_label = %ActualTimeLabel
@onready var actual_particles_label = %ActualParticlesLabel

var paused_by_view_change:bool = false
func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	speed_spinbox.value_changed.connect(_on_speed_changed)
	self_modulate.a = 0.0
	# Set initial state
	request_hide()
	_update_play_button_state()

func _process(_delta: float) -> void:
	if linked_particles:
		actual_time_label.text = "%.2f" % linked_particles.simulation_time
		actual_particles_label.text = "%d" % linked_particles._visible_count
		_update_play_button_state()

func view_changed(is_viewing:bool) -> void:
	if is_viewing:
		if (paused_by_view_change) and linked_particles != null:
			if linked_particles._playing:
				if linked_particles.paused:
					# Resume
					linked_particles.paused = false
					paused_by_view_change = false
	else:
		if (not paused_by_view_change) and linked_particles != null:
			if linked_particles._playing and not linked_particles.paused:
					# Resume
					linked_particles.paused = true
					paused_by_view_change = true

func _update_play_button_state() -> void:
	if play_button == null:
		return
	if not linked_particles:
		play_button.text = "Play"
		return

	if linked_particles._playing:
		if linked_particles.paused:
			play_button.text = "Resume"
		else:
			play_button.text = "Pause"
	else:
		play_button.text = "Play"

func link_with_particles(particles: UniParticles3D) -> void:
	linked_particles = particles
	if linked_particles:
		speed_spinbox.value = linked_particles.playback_speed
	_update_play_button_state()

func unlink_particles() -> void:
	linked_particles = null
	_update_play_button_state()

func request_show() -> void:
	visible = true
	set_process(true)

func request_hide() -> void:
	visible = false
	set_process(false)

func _on_play_pressed() -> void:
	if not linked_particles:
		return
	if linked_particles._playing:
		if linked_particles.paused:
			# Resume
			linked_particles.paused = false
		else:
			# Pause
			linked_particles.paused = true
	else:
		# Start playing
		linked_particles.play()

	_update_play_button_state()

func _on_stop_pressed() -> void:
	if linked_particles:
		linked_particles.stop(true)
		linked_particles.clear()
		linked_particles.paused = false
	_update_play_button_state()

func _on_restart_pressed() -> void:
	if linked_particles:
		linked_particles.stop(true)
		linked_particles.clear()
		linked_particles.paused = false
		linked_particles.play(true)
	_update_play_button_state()

func _on_speed_changed(value: float) -> void:
	if linked_particles:
		linked_particles.playback_speed = value
