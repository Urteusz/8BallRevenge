extends Control

@onready var original_position = position

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				move_to_front()
				drag_offset = get_global_mouse_position() - global_position
			else:
				dragging = false
				position = original_position

	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset
