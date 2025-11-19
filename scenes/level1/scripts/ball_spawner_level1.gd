extends Marker3D

@export var game_manager: Node3D
@export var ball_scene: PackedScene
@export var player_ball: RigidBody3D

# Ustawienia trójkąta
@export var num_rows: int = 3 
@export var spread: float = 1.0
@export var depth: float = 1.0 
@export var height: float = 1.0 
@export var ball_radius: float = 0.05

func _ready() -> void:
	if !game_manager: # Ważne sprawdzenie
		push_error("Game Manager not set!")
		return
		
	# ... (Twoje obliczanie pozycji positions - zostaje bez zmian) ...
	var base_transform := global_transform
	var base_position := base_transform.origin
	var right_vector := base_transform.basis.x
	var back_vector := base_transform.basis.z
	var up_vector := base_transform.basis.y
	var y_offset_for_balls := up_vector * (height + ball_radius)
	var positions: Array[Vector3] = []

	for r in range(num_rows):
		var z_offset = -(back_vector * depth * float(r))
		var num_balls_in_row = r + 1
		var start_x_scalar: float = -(float(r) / 2.0) * spread
		for c in range(num_balls_in_row):
			var x_offset = (start_x_scalar + (float(c) * spread)) * right_vector
			var ball_position = base_position + z_offset + x_offset + y_offset_for_balls
			positions.append(ball_position)
	# ... (Koniec obliczeń) ...

	# --- ZMIENIONA CZĘŚĆ SPAWNOWANIA ---
	var i: int = 0
	for ball_position in positions:
		# Sprawdzamy czy mamy wystarczająco kul w talii gracza
		if i >= PlayerData.current_deck.size():
			return
		
		# Pobieramy dane (zakładając, że BallData ma class_name BallData)
		var ball_data = PlayerData.current_deck[i] as BallData
		
		# Jeśli dane są uszkodzone, pomijamy tę pozycję i idziemy do następnej kuli w talii?
		# Czy może pomijamy kulę w talii i próbujemy wstawić następną w to miejsce?
		# Tutaj zakładam: Pozycja zostaje pusta, idziemy do nast. pozycji.
		if !ball_data or !ball_data.scene:
			push_warning("Błąd danych kuli przy indeksie: " + str(i))
			i += 1
			continue	
		
		var new_instance = ball_data.scene.instantiate()
		add_child(new_instance)
		
		# Dodawanie do listy w managerze
		if game_manager.get("ball_list") != null:
			game_manager.ball_list.append(new_instance)
			
		new_instance.base_value = ball_data.base_value
		new_instance.global_position = ball_position
		
		# Tuitaj dzieje się magia z teksturami załadowanymi w PlayerData
		if ball_data.texture:
			apply_texture_to_ball(new_instance, ball_data.texture)
		
		if new_instance.has_method("_on_round_ended") and player_ball:
			player_ball.round_ended.connect(new_instance._on_round_ended)
		
		i += 1

# --- ZOPTORMALIZOWANA FUNKCJA APLIKOWANIA TEKSTURY ---
func apply_texture_to_ball(ball_instance: Node3D, texture: Texture2D) -> void:
	var mesh_instance = find_mesh_instance(ball_instance)

	if mesh_instance and mesh_instance.mesh:
		var material = mesh_instance.get_active_material(0)
		
		if material:
			# Duplikujemy materiał, aby zmiana dotyczyła tylko tej jednej kuli
			var unique_material = material.duplicate()
			mesh_instance.set_surface_override_material(0, unique_material)

			# BaseMaterial3D to wspólna klasa dla StandardMaterial3D i ORMMaterial3D
			# Dzięki temu jeden if obsługuje oba przypadki!
			if unique_material is BaseMaterial3D:
				unique_material.albedo_texture = texture
				# print("Zastosowano teksturę: ", texture.resource_path)
			else:
				push_warning("Materiał kuli nie dziedziczy po BaseMaterial3D. Kula: " + ball_instance.name)
		else:
			push_warning("MeshInstance3D nie ma przypisanego materiału. Kula: " + ball_instance.name)

func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var mesh_instance = find_mesh_instance(child)
		if mesh_instance:
			return mesh_instance
	return null
