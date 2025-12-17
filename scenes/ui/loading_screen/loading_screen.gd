extends CanvasLayer

signal loading_screen_has_full_coverage

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var progress_bar: ProgressBar = $Panel/ProgressBar


func _update_progress_bar(new_value: float) -> void:
	progress_bar.set_value_no_signal(new_value * 100)


func _start_outro_animation() -> void:
	if animation_player.is_playing():
		animation_player.stop()
	
	animation_player.play("loading_end")
	
	if animation_player.has_animation("loading_end"):
		await animation_player.animation_finished
	else:
		push_warning("Animation 'loading_end' not found!")
	
	self.queue_free()
