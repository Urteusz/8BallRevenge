extends Marker3D

@export var game_manager: Node3D

@export var ball_scene: PackedScene
@export var player_ball: RigidBody3D

@export var num_rows: int = 2 # Default to 2 rows (3 balls) to match "triangle from last 3 balls"

@export var spread: float = 1.0
@export var depth: float = 1.0
@export var height: float = 1.0

@export var ball_radius: float = 0.5

func _ready() -> void:
	if !ball_scene:
		push_error("Error: 'Object Scene' or 'Spawn Point' not set.")
		return

	if !player_ball:
		push_error("Error: 'Player Ball' not set in Ball Spawner")
		return
		
	var base_transform := global_transform
	var base_position := base_transform.origin
	var right_vector := base_transform.basis.x
	var back_vector := base_transform.basis.z
	var up_vector := base_transform.basis.y

	var y_offset_for_balls := up_vector * (height + ball_radius)
	
	var positions: Array[Vector3] = []

	# --- Automatic Position Calculation ---
	for r in range(num_rows):
		var z_offset = -(back_vector * depth * float(r))
		var num_balls_in_row = r + 1
		var start_x_scalar: float = -(float(r) / 2.0) * spread
		
		for c in range(num_balls_in_row):
			var x_offset = (start_x_scalar + (float(c) * spread)) * right_vector
			var ball_position = base_position + z_offset + x_offset + y_offset_for_balls
			positions.append(ball_position)
	# --- End of Automatic Calculation ---

	var current_deck_size = PlayerData.current_deck.size()
	var total_positions = positions.size()
	
	# Calculate start index to take the LAST 'total_positions' balls
	var deck_idx = current_deck_size - total_positions
	if deck_idx < 0: 
		deck_idx = 0 # Fallback if deck is too small

	for ball_position in positions:
		if deck_idx >= current_deck_size:
			return
		
		var ball_data: BallData = PlayerData.current_deck[deck_idx]
		if !ball_data or !ball_data.scene:
			deck_idx += 1
			continue
		
		var new_instance = ball_data.scene.instantiate()
		add_child(new_instance)
		game_manager.ball_list.append(new_instance)
		new_instance.base_value = ball_data.base_value
		new_instance.global_position = ball_position

		# Connect signals
		if new_instance.has_signal("ball_pocketed"):
			new_instance.ball_pocketed.connect(game_manager._on_ball_pocketed)
		if new_instance.has_signal("ball_pocketed_void"):
			new_instance.ball_pocketed_void.connect(game_manager._on_ball_pocketed_void)
		if new_instance.has_signal("points_scored"):
			new_instance.points_scored.connect(game_manager._on_points_scored)
		if new_instance.has_signal("score_updated"):
			var gameplay_ui = game_manager.gameplay_ui
			if gameplay_ui:
				new_instance.score_updated.connect(gameplay_ui._on_ball_score_updated.bind(new_instance.get_instance_id()))

		if ball_data.texture:
			apply_texture_to_ball(new_instance, ball_data.texture)
		
		deck_idx += 1
	await get_tree().create_timer(0.3).timeout
	_enable_scoring_for_all_balls()


func _enable_scoring_for_all_balls() -> void:
	for ball in game_manager.ball_list:
		if ball.has_method("enable_scoring"):
			ball.enable_scoring()

func apply_texture_to_ball(ball_instance: Node3D, texture: Texture2D) -> void:
	var mesh_instance = find_mesh_instance(ball_instance)

	if mesh_instance and mesh_instance.mesh:
		var material = mesh_instance.get_active_material(0)
		
		if material:
			var unique_material = material.duplicate()
			mesh_instance.set_surface_override_material(0, unique_material)

			if unique_material is StandardMaterial3D:
				(unique_material as StandardMaterial3D).albedo_texture = texture
			elif unique_material is ORMMaterial3D:
				(unique_material as ORMMaterial3D).albedo_texture = texture
			else:
				push_warning("Warning: Material on ball mesh is not a StandardMaterial3D or ORMMaterial3D. Cannot apply texture easily. Kula: " + ball_instance.name)
		else:
			push_warning("Warning: MeshInstance3D has no material. Kula: " + ball_instance.name)
	else:
		push_warning("Warning: Could not find MeshInstance3D or mesh in ball instance to apply texture. Kula: " + ball_instance.name)


func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var mesh_instance = find_mesh_instance(child)
		if mesh_instance:
			return mesh_instance
	return null
