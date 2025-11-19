extends Marker3D

@export var ball_scene: PackedScene
@export var player_ball: RigidBody3D

@export var spread: float = 1.0
@export var depth: float = 1.0
@export var height: float = 1.0

@export var ball_textures: Array[Texture2D] 
@export var ball_radius: float = 0.05 

@export var default_ball_texture: Texture2D 

func _ready() -> void:
	if !ball_scene:
		push_error("Error: 'Object Scene' or 'Spawn Point' not set.")
		return

	if !player_ball:
		push_error("Error: 'Player Ball' not set in Ball Spawner")
		return
	
	load_textures_from_folder("res://textures/balls")
		
	if ball_textures.is_empty() and !default_ball_texture:
		push_warning("Warning: 'Ball Textures' array is empty and 'Default Ball Texture' is not set. Balls will not have any texture unless set in their scene directly.")
	elif ball_textures.is_empty() and default_ball_texture:
		push_warning("Warning: 'Ball Textures' array is empty. All balls will use the 'Default Ball Texture'.")


	var base_transform := global_transform
	var base_position := base_transform.origin
	var right_vector := base_transform.basis.x
	var back_vector := base_transform.basis.z
	var up_vector := base_transform.basis.y

	var y_offset_for_balls := up_vector * (height + ball_radius)
	
	var positions: Array[Vector3] = []
	var current_texture_index = 0

	# Rząd 1: 1 kula
	positions.append(base_position + y_offset_for_balls)
	
	# Rząd 2: 2 kule
	positions.append(base_position - (back_vector * depth) - (right_vector * spread * 0.5) + y_offset_for_balls)
	positions.append(base_position - (back_vector * depth) + (right_vector * spread * 0.5) + y_offset_for_balls)

	# Rząd 3: 3 kule
	positions.append(base_position - (back_vector * depth * 2.0) - (right_vector * spread * 1.0) + y_offset_for_balls)
	positions.append(base_position - (back_vector * depth * 2.0) + y_offset_for_balls)
	positions.append(base_position - (back_vector * depth * 2.0) + (right_vector * spread * 1.0) + y_offset_for_balls)

	for position in positions:
		var new_instance = ball_scene.instantiate()
		add_child(new_instance)
		new_instance.global_position = position
		
		# ---- Zmieniona logika przypisywania tekstur ----
		var texture_to_apply: Texture2D = null

		# Najpierw spróbuj wziąć unikalną teksturę z tablicy
		if not ball_textures.is_empty() and current_texture_index < ball_textures.size():
			texture_to_apply = ball_textures[current_texture_index]
			print("Kula ", current_texture_index, ": Używam tekstury z ball_textures: ", texture_to_apply.resource_path if texture_to_apply else "Brak")
			current_texture_index += 1
		# Jeśli nie ma więcej unikalnych tekstur, użyj domyślnej
		elif default_ball_texture:
			texture_to_apply = default_ball_texture
			print("Kula ", current_texture_index, ": Używam domyślnej tekstury: ", texture_to_apply.resource_path if texture_to_apply else "Brak")
			current_texture_index += 1;
		else:
			print("Kula ", current_texture_index, ": Brak tekstury do zastosowania.")
		
		# Jeśli znaleziono teksturę (czy to unikalną, czy domyślną), zastosuj ją
		if texture_to_apply:
			apply_texture_to_ball(new_instance, texture_to_apply)
		else:
			push_warning("Warning: No texture assigned to a ball instance. 'Ball Textures' array exhausted and 'Default Ball Texture' not set.")


		if new_instance.has_method("_on_round_ended"):
			player_ball.round_ended.connect(new_instance._on_round_ended)
		else:
			push_warning("Warning: Ball instance does not have '_on_round_ended' method.")

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
	
func load_textures_from_folder(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if !dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".jpg")):
				var full_path = path + "/" + file_name
				var texture = load(full_path)
				if texture is Texture2D:
					ball_textures.append(texture)
					print("Załadowano teksturę z kodu: ", file_name)
			
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("Nie znaleziono folderu: " + path)
