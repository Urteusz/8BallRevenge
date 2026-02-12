extends Node2D

@export var start_node: LevelNode
@export var player_cursor: Sprite2D
@export var move_duration: float = 0.3
@export var line_drawer: Line2D
@export var max_stars_per_level: int = 3

@onready var total_stars_label: Label = %StarsLabel

var current_node: LevelNode
var is_moving: bool = false
var last_clicked_node: LevelNode = null
var last_click_time: float = 0.0
var double_click_threshold: float = 0.3

func _ready() -> void:
	# Ukryj mapę do zakończenia przejścia
	modulate.a = 0.0

	current_node = start_node
	player_cursor.global_position = current_node.global_position

	if current_node:
		current_node.set_selected(true)

	_draw_connections()

	# Odświeżamy gwiazdki na wszystkich węzłach
	for node in get_tree().get_nodes_in_group("level_nodes"):
		if node is LevelNode:
			node.refresh_stars()
			if not node.clicked.is_connected(_on_level_node_clicked):
				node.clicked.connect(_on_level_node_clicked)

	# Aktualizuj label z całkowitą liczbą gwiazdek
	_update_total_stars_label()

	# Animacja pulsowania kursora
	_start_cursor_pulse()

	# Fade-in po krótkim opóźnieniu
	await get_tree().create_timer(0.8).timeout
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _process(delta: float) -> void:
	if is_moving:
		return

	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right"): input_dir.x += 1
	if Input.is_action_pressed("ui_left"): input_dir.x -= 1
	if Input.is_action_pressed("ui_down"): input_dir.y += 1
	if Input.is_action_pressed("ui_up"): input_dir.y -= 1
	
	if input_dir != Vector2.ZERO:
		_try_move(input_dir)
		
	# Wybór poziomu (Enter / Spacja)
	if Input.is_action_just_pressed("ui_accept"):
		_select_level()

	# Powrót do menu głównego (ESC)
	if Input.is_action_just_pressed("ui_cancel"):
		LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)

func _try_move(direction: Vector2) -> void:
	var best_neighbor: LevelNode = null
	var best_angle: float = 999.0 
	
	# Normalizujemy wektor wejściowy, żeby (1,1) nie mieszało w obliczeniach
	direction = direction.normalized()
	
	for neighbor in current_node.neighbors:
		var direction_to_neighbor = (neighbor.global_position - current_node.global_position).normalized()
		var angle_diff = direction.angle_to(direction_to_neighbor)
		
		if abs(angle_diff) < 1.35: 
			if abs(angle_diff) < best_angle:
				best_angle = abs(angle_diff)
				best_neighbor = neighbor
	
	if best_neighbor:
		_move_to_node(best_neighbor)

func _move_to_node(target_node: LevelNode) -> void:
	is_moving = true

	# Odznacz poprzedni węzeł
	if current_node:
		current_node.set_selected(false)

	current_node = target_node

	# Zaznacz nowy węzeł
	current_node.set_selected(true)

	# Animacja ruchu (Tween)
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(player_cursor, "global_position", target_node.global_position, move_duration)

	var original_scale = player_cursor.scale
	tween.parallel().tween_property(player_cursor, "scale", original_scale * 1.2, move_duration / 2)
	tween.parallel().tween_property(player_cursor, "scale", original_scale, move_duration / 2).set_delay(move_duration / 2)

	await tween.finished
	is_moving = false

func _select_level() -> void:
	if current_node.level_scene_path != "":
		print("Ładowanie poziomu: ", current_node.level_scene_path)
		PlayerData.set_level(current_node.level_number)
		LoadManager.load_scene(ScenePaths.DECK_CHOOSE)
	else:
		print("Ten węzeł nie ma przypisanego poziomu.")

func _draw_connections() -> void:
	for child in get_children():
		if child is Line2D and child != line_drawer:
			child.queue_free()

	var processed_connections = []
	var connections_count = 0

	for node in get_tree().get_nodes_in_group("level_nodes"):
		if not is_instance_valid(node):
			continue

		for neighbor in node.neighbors:
			if not is_instance_valid(neighbor):
				continue

			var connection_id = [node, neighbor]
			connection_id.sort_custom(func(a, b): return a.name < b.name)

			if not connection_id in processed_connections:
				# Konwertuj global position do lokalnego względem LevelSelectMap
				var local_pos_a = to_local(node.global_position)
				var local_pos_b = to_local(neighbor.global_position)
				_create_visual_line(local_pos_a, local_pos_b)
				processed_connections.append(connection_id)
				connections_count += 1

	print("Narysowano ", connections_count, " połączeń między węzłami")

func _create_visual_line(pos_a: Vector2, pos_b: Vector2) -> void:
	var new_line = Line2D.new()

	# Jasnoniebieski kolor
	new_line.default_color = Color(0.5, 0.8, 1.0, 0.9)
	new_line.width = 6.0
	new_line.add_point(pos_a)
	new_line.add_point(pos_b)
	new_line.z_index = 0  # Pod węzłami poziomów (które też mają z_index=0, ale są dodane później)
	new_line.antialiased = true

	# Dodaj skrypt do animacji (gradient będzie dodany w skrypcie)
	new_line.set_script(load("res://scenes/ui/level_picker/animated_line.gd"))

	add_child(new_line)

func _find_path(from: LevelNode, to: LevelNode) -> Array[LevelNode]:
	if from == to:
		return [from]

	var queue: Array = [[from]]  # Kolejka ścieżek
	var visited: Array[LevelNode] = [from]

	while queue.size() > 0:
		var path: Array = queue.pop_front()
		var node: LevelNode = path[-1]

		for neighbor in node.neighbors:
			if neighbor == to:
				# Znaleziono cel!
				var final_path: Array[LevelNode] = []
				final_path.append_array(path)
				final_path.append(to)
				return final_path

			if neighbor not in visited:
				visited.append(neighbor)
				var new_path: Array = path.duplicate()
				new_path.append(neighbor)
				queue.append(new_path)

	# Nie znaleziono ścieżki
	return []

# Animuj ruch po ścieżce węzeł po węźle
func _move_along_path(path: Array[LevelNode]) -> void:
	is_moving = true

	for i in range(path.size()):
		var target_node = path[i]

		# Odznacz poprzedni węzeł
		if current_node:
			current_node.set_selected(false)

		current_node = target_node
		current_node.set_selected(true)

		# Animacja ruchu
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(player_cursor, "global_position", target_node.global_position, move_duration)

		# Efekt scale
		var original_scale = player_cursor.scale
		tween.parallel().tween_property(player_cursor, "scale", original_scale * 1.2, move_duration / 2)
		tween.parallel().tween_property(player_cursor, "scale", original_scale, move_duration / 2).set_delay(move_duration / 2)

		await tween.finished

		# Krótka pauza między skokami (tylko jeśli nie jest to ostatni węzeł)
		if i < path.size() - 1:
			await get_tree().create_timer(0.1).timeout
	is_moving = false

func _start_cursor_pulse() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(player_cursor, "scale", Vector2(1.1, 1.1), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player_cursor, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_total_stars_label() -> void:
	if not total_stars_label:
		return

	var total_stars = PlayerData.get_total_stars()
	var level_count = get_tree().get_nodes_in_group("level_nodes").size()
	var max_possible_stars = level_count * max_stars_per_level

	total_stars_label.text = str(total_stars) + " / " + str(max_possible_stars)

func _on_level_node_clicked(node: LevelNode) -> void:
	if is_moving:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	var is_double_click = (node == last_clicked_node and
						   current_time - last_click_time < double_click_threshold)

	last_clicked_node = node
	last_click_time = current_time

	# Podwójne kliknięcie - natychmiast załaduj poziom
	if is_double_click:
		if node == current_node:
			_select_level()
		else:
			# Znajdź ścieżkę i przejdź, potem załaduj
			var path = _find_path(current_node, node)
			if path.size() > 0:
				# Usuń pierwszy węzeł (aktualny) z ścieżki
				path.remove_at(0)
				if path.size() > 0:
					await _move_along_path(path)
				_select_level()
		return

	if node == current_node:
		return

	var path = _find_path(current_node, node)

	if path.size() > 1:
		path.remove_at(0)

		if path.size() == 1:
			_move_to_node(path[0])
		else:
			_move_along_path(path)
