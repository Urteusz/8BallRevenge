extends SubViewportContainer

signal clicked(ball_data)

var my_ball_data: BallData
@onready var pivot: Node3D = $SubViewport/Pivot

func setup(ball_data: BallData) -> void:
	my_ball_data = ball_data
	
	if ball_data.scene:
		var ball_instance = ball_data.scene.instantiate()
		pivot.add_child(ball_instance)
		
		ball_instance.position = Vector3.ZERO
		
		if ball_data.texture:
			var mesh = ball_instance.get_node_or_null("MeshInstance3D")
			if mesh:
				var new_mat = StandardMaterial3D.new()
				new_mat.albedo_texture = ball_data.texture
				mesh.material_override = new_mat
		
		if ball_instance is RigidBody3D:
			ball_instance.freeze = true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(my_ball_data)
		
func _ready() -> void:
	custom_minimum_size = Vector2(100, 100) 
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
