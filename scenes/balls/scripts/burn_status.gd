class_name BurnStatus
extends Node3D

# Variables set by LavaBall
var duration: float = 3.0
var tick_interval: float = 1.0
var points_per_tick: int = 50
var vfx_scene: PackedScene = null

var target_ball: BallParent
var time_elapsed: float = 0.0
var tick_timer: float = 0.0
var visual_light: OmniLight3D
var visual_vfx: Node

func _ready() -> void:
	var parent = get_parent()
	if parent is BallParent:
		target_ball = parent
	else:
		queue_free()
		return
	
	# 1. Visual VFX (Constant effect from scene)
	if vfx_scene:
		visual_vfx = vfx_scene.instantiate()
		add_child(visual_vfx)
		
	# 2. Light (Constant glow)
	visual_light = OmniLight3D.new()
	visual_light.light_color = Color(1.0, 0.4, 0.0) # Orange/Fire color
	visual_light.light_energy = 2.0
	visual_light.omni_range = 2.0
	add_child(visual_light)

func _process(delta: float) -> void:
	# Lock rotation to stay vertical regardless of ball rotation
	global_rotation = Vector3.ZERO
	
	time_elapsed += delta
	tick_timer += delta

	# Flicker effect
	if visual_light:
		visual_light.light_energy = 2.0 + randf_range(-0.5, 0.5)

	if tick_timer >= tick_interval:
		tick_timer = 0.0
		apply_burn_points()

	if time_elapsed >= duration:
		queue_free()

func apply_burn_points() -> void:
	if is_instance_valid(target_ball):
		target_ball.total_points += points_per_tick
		
		# Emit signal if connected, to update UI
		if target_ball.has_signal("score_updated"):
			target_ball.emit_signal("score_updated", target_ball.total_points)
		
		# Show popup with points
		if target_ball.has_method("_show_popup"):
			target_ball._show_popup(target_ball.global_position + Vector3(0, 0.5, 0), points_per_tick)
			
		# Visual effect: reuse hit particles (one-shot pops)
		if target_ball.has_method("_show_particles"):
			target_ball._show_particles(target_ball.global_position)
