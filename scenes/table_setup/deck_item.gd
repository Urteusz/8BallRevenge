extends Control

@export var camera: Camera3D
@onready var original_position = position

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var ball_scene: PackedScene

func _ready() -> void:
	ball_scene = PlayerData.current_deck[1].scene

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				move_to_front()
				drag_offset = get_global_mouse_position() - global_position
			else:
				dragging = false
				fire_raycast_at_mouse()
				position = original_position

	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset

func fire_raycast_at_mouse():
	var mouse_pos = get_viewport().get_mouse_position()

	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	var ray_length = 1000.0
	var ray_end = ray_origin + (ray_normal * ray_length)

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	# query.collision_mask = 1 

	var result = space_state.intersect_ray(query)

	if result:
		var collider = result["collider"]
		if collider.has_method("receive_ui_drop"):
			collider.receive_ui_drop(ball_scene)
