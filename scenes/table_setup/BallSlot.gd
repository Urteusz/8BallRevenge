extends CharacterBody3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@export var camera: Camera3D

var hovering: bool = false
var is_dragging: bool = false

var original_material: StandardMaterial3D
var highlight_material: StandardMaterial3D

func _ready() -> void:
	original_material = mesh_instance.get_active_material(0).duplicate()
	mesh_instance.material_override = original_material
	
	highlight_material = original_material.duplicate()
	highlight_material.albedo_color = Color.RED

func _physics_process(_delta: float) -> void:
	if is_dragging:
		var mouse_position = get_viewport().get_mouse_position()
		
		var drop_plane = Plane(Vector3.UP, global_position.y)
		
		var ray_origin = camera.project_ray_origin(mouse_position)
		var ray_normal = camera.project_ray_normal(mouse_position)
		
		var intersection_point = drop_plane.intersects_ray(ray_origin, ray_normal)
		
		# Jak nie chcesz snap to grid to wywal snapped
		var grid_size = 1.0
		if intersection_point:
			global_position = Vector3(snapped(intersection_point.x, grid_size), intersection_point.y, snapped(intersection_point.z, grid_size))

func _input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_dragging = !is_dragging

func _on_mouse_entered():
	hovering = true
	mesh_instance.material_override = highlight_material
	
func _on_mouse_exited():
	hovering = false
	mesh_instance.material_override = original_material

func receive_ui_drop(ball_scene: PackedScene) -> void:
	remove_child(mesh_instance) # mesh_instance jest null po tym
	#i nie wiem czy to nie sprawia problemów
	var ball: RigidBody3D = ball_scene.instantiate()
	ball.freeze = true
	add_child(ball)
