# to musi byc potem przepisane zeby uzywalo object pool
#	inaczej bedzie lagowac pewnie
# aby dzialalo to z edge detection shaderem ustawilem render priority label3d na 127 i 126
extends Node3D

@onready var label = %Label
@onready var animation_player = %AnimationPlayer


func set_and_play(value: int) -> void:
	label.text = str(value)
	animation_player.play("PointsPopupAnimation")


func total_points(value: int) -> void:
	label.text = str(value)
	animation_player.play("TotalPointsAnimation")


func remove() -> void:
	queue_free()
