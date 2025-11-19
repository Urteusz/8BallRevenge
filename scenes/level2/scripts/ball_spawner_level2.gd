extends Marker3D

@export var game_manager: Node3D

@export var ball_scene: PackedScene
@export var player_ball: RigidBody3D

# --- New variable to control the triangle size ---
@export var num_rows: int = 3 # Defines the number of rows (e.g., 3 rows = 1+2+3=6 balls total)

@export var spread: float = 1.0 # Horizontal distance between balls in a row
@export var depth: float = 1.0  # Vertical (z-axis) distance between rows
@export var height: float = 1.0 # Base height offset from the Marker3D

@export var ball_radius: float = 0.05

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
	# Loop through each row (r = 0 is the front ball)
	for r in range(num_rows):
		# Calculate the Z offset (depth) for the current row
		var z_offset = -(back_vector * depth * float(r))
		
		# Each row 'r' has 'r + 1' balls (row 0 has 1, row 1 has 2, etc.)
		var num_balls_in_row = r + 1
		
		# Calculate the starting X offset to keep the row centered
		# For r=0 (1 ball), start_x_scalar = 0
		# For r=1 (2 balls), start_x_scalar = -0.5
		# For r=2 (3 balls), start_x_scalar = -1.0
		var start_x_scalar: float = -(float(r) / 2.0) * spread
		
		# Loop through each ball 'c' in the current row 'r'
		for c in range(num_balls_in_row):
			# Calculate the X offset for this specific ball
			# (start_x_scalar + c * spread) gives the centered position for this ball
			var x_offset = (start_x_scalar + (float(c) * spread)) * right_vector
			
			# Combine all offsets to get the final position
			var ball_position = base_position + z_offset + x_offset + y_offset_for_balls
			positions.append(ball_position)
	# --- End of Automatic Calculation ---

	var i: int = 0
	for ball_position in positions:
		if i >= PlayerData.current_deck.size():
			return
		
		var ball_data: BallData = PlayerData.current_deck[i]
		if !ball_data or !ball_data.scene:
			i += 1
			continue	
		
		var new_instance = ball_data.scene.instantiate()
		add_child(new_instance)
		game_manager.ball_list.append(new_instance)
		new_instance.base_value = ball_data.base_value
		new_instance.global_position = ball_position
		
		if ball_data.texture:
			apply_texture_to_ball(new_instance, ball_data.texture)
		
		if new_instance.has_method("_on_round_ended"):
			player_ball.round_ended.connect(new_instance._on_round_ended)
		else:
			push_warning("Warning: Ball instance does not have 'on_round_ended'")
		
		i += 1


func apply_texture_to_ball(ball_instance: Node3D, texture: Texture2D) -> void:
	var mesh_instance = find_mesh_instance(ball_instance)

	if mesh_instance and mesh_instance.mesh:
		var material = mesh_instance.get_active_material(0)
		
		if material:
			# *** KLUCZOWA ZMIANA: Tworzenie unikalnej kopii materiału ***
			var unique_material = material.duplicate()
			mesh_instance.set_surface_override_material(0, unique_material) # Ustaw unikalny materiał na powierzchni 0

			print("Znaleziono materiał: ", unique_material.get_class(), " dla kuli ", ball_instance.name)
			if unique_material is StandardMaterial3D:
				(unique_material as StandardMaterial3D).albedo_texture = texture
				print("Zastosowano teksturę StandardMaterial3D: ", texture.resource_path, " dla kuli ", ball_instance.name)
			elif unique_material is ORMMaterial3D:
				(unique_material as ORMMaterial3D).albedo_texture = texture
				print("Zastosowano teksturę ORMMaterial3D: ", texture.resource_path, " dla kuli ", ball_instance.name)
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
