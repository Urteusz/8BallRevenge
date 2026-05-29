extends Node3D

signal deck_selected

const POSITIONS: Array = [
	Vector3(1.147, 0.0, -2.0),
	Vector3(1.736, 0.0, -1.0),
	Vector3(0.558, 0.0, -1.0),
	Vector3(1.147, 0.0, 0.0),
	Vector3(2.265, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
]


const INVENTORY_ITEM_SCENE = preload("res://scenes/DeckChoose/InventoryBallItem.tscn")

@onready var camera: Camera3D = $SubViewportContainer/SubViewport/Camera3D
@onready var edge_shader: MeshInstance3D = $SubViewportContainer/SubViewport/Camera3D/EdgeDetectionShader

# Parametry EdgeDetectionShader dopasowane do każdego levelu
const LEVEL_SHADER_PARAMS: Dictionary = {
	1: { "tintColor": Color(0.18, 0.17, 0.72, 1), "lineShadow": 0.7, "tintStrength": 0.8 },
	2: { "tintColor": Color(1.0, 0.745, 0.239, 1.0), "lineShadow": 0.7, "tintStrength": 0.8 },
	3: { "tintColor": Color(1.0, 0.0, 0.0, 1), "lineShadow": 0.7, "tintStrength": 0.7 },
	4: { "tintColor": Color(0.54, 0.21, 0.9, 1), "lineShadow": 0.55, "tintStrength": 0.7 },
	5: { "tintColor": Color(0.28, 0.42, 1.0, 1), "lineShadow": 0.55, "tintStrength": 0.0 },
}
@onready var ui: CanvasLayer = $UI
@onready var panel_container: PanelContainer = $UI/PanelContainer
@onready var back_button: TextureButton = $UI/BackContainer/ButtonBack
@onready var play_button: TextureButton = $UI/PlayContainer/ButtonPlay
@onready var balls = %Balls
@onready var inventory_grid: Container = $UI/PanelContainer/HBoxContainer/VBoxContainer/ScrollContainer/InventoryGrid
@onready var tooltip_panel: Control = $UI/TooltipPanel
@onready var tooltip_label: Label = $UI/TooltipPanel/Label

# Drag & Drop State
var dragged_ball: Node3D = null
var is_dragging: bool = false
var is_swapping: bool = false
var drag_offset: Vector3 = Vector3.ZERO

@onready var sub_viewport_container: SubViewportContainer = $SubViewportContainer
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport

func _ready() -> void:

	_spawn_balls()
	_refresh_inventory_ui()
	_apply_level_shader()

	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	if play_button:
		play_button.pressed.connect(_on_confirm_button_pressed)

	_setup_pad_navigation()
	# zapamietaj statyczna pozycje tooltipa (z anchorow sceny) zanim cokolwiek ja ruszy
	call_deferred("_cache_tooltip_static_pos")

const ZONE_RACK: int = 0
const ZONE_INVENTORY: int = 1

var nav_zone: int = ZONE_RACK
var selected_index: int = 0      # kursor po stojaku
var held_index: int = -1         # podniesiona bila ze stojaka (zamiana stojak<->stojak)
var inventory_index: int = 0     # kursor po inwentarzu

# DAS (delayed auto-shift) dla gałki/D-pada:
# kierunki czytane przez polling w _process, zeby jedno wychylenie = jeden ruch.
const NAV_INITIAL_DELAY: float = 0.35   # pauza zanim ruszy auto-powtarzanie
const NAV_REPEAT_DELAY: float = 0.16    # tempo powtarzania przy przytrzymaniu
const SELECT_LIFT: float = 0.3          # uniesienie zaznaczonej bili (w gore, Y)
const SELECT_LIFT_HELD: float = 0.55    # uniesienie bili oznaczonej do wymiany
var _nav_dir: Vector2i = Vector2i.ZERO
var _nav_timer: float = 0.0

# Tooltip: przy myszy goni kursor, przy strzalkach/padzie stoi w miejscu (anchor ze sceny).
var tooltip_follow_mouse: bool = false
var _tooltip_static_offsets: Vector4 = Vector4.ZERO   # offsety kotwic ze sceny (l, t, r, b)
var _tooltip_static_cached: bool = false

func _setup_pad_navigation() -> void:
	nav_zone = ZONE_RACK
	selected_index = 0
	held_index = -1
	inventory_index = 0
	_highlight_selected()

func _describe_event(event: InputEvent) -> String:
	var actions: Array = []
	for a in ["ui_left", "ui_right", "ui_up", "ui_down", "ui_accept", "ui_cancel"]:
		if event.is_action_pressed(a):
			actions.append(a)
	return "%s dev=%d actions=%s" % [event.get_class(), event.device, str(actions)]

func _zone_name() -> String:
	return "INVENTORY" if nav_zone == ZONE_INVENTORY else "RACK"

func _ball_name(ball_data) -> String:
	if ball_data and ball_data is BallData:
		return str(ball_data.display_name)
	return "<brak>"

func _unhandled_input(event: InputEvent) -> void:
	if is_dragging or is_swapping:
		return

	# ui_start = "kliknij" przycisk Play za uzytkownika (dziala w obu strefach)
	if event.is_action_pressed("ui_start"):
		print_debug("[DeckNav] ui_start -> klik przycisku Play")
		if play_button:
			play_button.pressed.emit()
		return

	# Kierunki idą przez polling (_process_navigation), wiec tu logujemy tylko A/B,
	# zeby galka analogowa nie spamowala konsoli setkami eventow JoypadMotion.
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		print_debug("[DeckNav] zona=%s sel=%d held=%d inv=%d | %s" % [
			_zone_name(), selected_index, held_index, inventory_index, _describe_event(event)])

	if nav_zone == ZONE_INVENTORY:
		_handle_inventory_input(event)
	else:
		_handle_rack_input(event)


func _rack_rows() -> Array:
	var deck_size: int = min(PlayerData.current_deck.size(), POSITIONS.size())
	var by_z: Dictionary = {}
	for i in range(deck_size):
		var z: float = POSITIONS[i].z
		if not by_z.has(z):
			by_z[z] = []
		by_z[z].append(i)
	var zs: Array = by_z.keys()
	zs.sort()
	var rows: Array = []
	for z in zs:
		var row: Array = by_z[z]
		row.sort_custom(func(a, b): return POSITIONS[a].x < POSITIONS[b].x)
		rows.append(row)
	return rows

func _find_row_col(rows: Array, idx: int) -> Vector2i:
	for r in range(rows.size()):
		var c: int = rows[r].find(idx)
		if c != -1:
			return Vector2i(r, c)
	return Vector2i(-1, -1)

func _move_rack_horizontal(dir: int) -> void:
	var rows := _rack_rows()
	var rc := _find_row_col(rows, selected_index)
	if rc.x == -1:
		return
	var row: Array = rows[rc.x]
	var c: int = clampi(rc.y + dir, 0, row.size() - 1)
	selected_index = row[c]
	print_debug("[DeckNav] RACK poziomo dir=%d -> rzad=%d kol=%d sel=%d" % [dir, rc.x, c, selected_index])
	_highlight_selected()

func _move_rack_vertical(dir: int) -> void:
	var rows := _rack_rows()
	var rc := _find_row_col(rows, selected_index)
	if rc.x == -1:
		return
	var nr: int = clampi(rc.x + dir, 0, rows.size() - 1)
	if nr == rc.x:
		return                          # juz na skraju (wierzcholek/podstawa)
	# Wyladuj na bili najblizszej w poziomie (po X). Remis -> lewa (mniejszy X).
	var cur_x: float = POSITIONS[selected_index].x
	var best: int = rows[nr][0]
	var best_d: float = absf(POSITIONS[best].x - cur_x)
	for idx in rows[nr]:
		var d: float = absf(POSITIONS[idx].x - cur_x)
		if d < best_d:
			best_d = d
			best = idx
	selected_index = best
	print_debug("[DeckNav] RACK pionowo dir=%d -> rzad=%d sel=%d (najblizej X=%.2f)" % [dir, nr, selected_index, cur_x])
	_highlight_selected()

func _handle_rack_input(event: InputEvent) -> void:
	var deck_size: int = min(PlayerData.current_deck.size(), POSITIONS.size())
	if deck_size == 0:
		return

	# Kierunki (lewo/prawo/gora/dol) obsluguje _process_navigation (DAS).
	# Tu tylko akcje przyciskowe, ktore wysylaja event raz na wcisniecie:
	# 'A' oznacza slot do wymiany i wchodzi do inwentarza, 'B' wraca do mapy.
	if event.is_action_pressed("ui_accept"):
		print_debug("[DeckNav] RACK ui_accept -> oznacz slot=%d do wymiany i wejdz do inwentarza" % selected_index)
		_mark_and_enter_inventory()
	elif event.is_action_pressed("ui_cancel"):
		print_debug("[DeckNav] RACK ui_cancel -> powrot do mapy")
		_on_back_button_pressed()

func _handle_inventory_input(event: InputEvent) -> void:
	# Kierunki obsluguje _process_navigation (DAS). Tu tylko 'A'/'B'.
	if event.is_action_pressed("ui_accept"):
		_pick_from_inventory()
	elif event.is_action_pressed("ui_cancel"):
		print_debug("[DeckNav] INV ui_cancel -> anuluj, powrot na stojak (bez zmian)")
		_exit_inventory()

# Polling kierunkow z DAS: jedno wychylenie galki = jeden ruch,
# przytrzymanie -> powtarzanie po NAV_INITIAL_DELAY w tempie NAV_REPEAT_DELAY.
func _process_navigation(delta: float) -> void:
	if is_dragging or is_swapping:
		return

	var dir := Vector2i.ZERO
	if Input.is_action_pressed("ui_right"):
		dir.x = 1
	elif Input.is_action_pressed("ui_left"):
		dir.x = -1
	if Input.is_action_pressed("ui_up"):
		dir.y = 1
	elif Input.is_action_pressed("ui_down"):
		dir.y = -1
	# przy ukosie galki priorytet ma poziom (zeby nie ruszac dwoma osiami naraz)
	if dir.x != 0:
		dir.y = 0

	if dir == Vector2i.ZERO:
		_nav_dir = Vector2i.ZERO
		_nav_timer = 0.0
		return

	if dir != _nav_dir:
		# nowy kierunek -> ruch natychmiast, potem dluzsza pauza
		_nav_dir = dir
		_nav_timer = NAV_INITIAL_DELAY
		_apply_nav_dir(dir)
	else:
		_nav_timer -= delta
		if _nav_timer <= 0.0:
			_nav_timer = NAV_REPEAT_DELAY
			_apply_nav_dir(dir)

func _apply_nav_dir(dir: Vector2i) -> void:
	if nav_zone == ZONE_INVENTORY:
		# Inwentarz to siatka (3 kolumny) -> pelna nawigacja 2D.
		# Lewo/prawo bylo odwrocone, wiec negujemy dir.x; gora/dol zostaje.
		_inventory_move(-dir.x, dir.y)
	else:
		# mapowanie znakow jak wczesniej (dopasowane do kamery)
		if dir.x == 1:                 # ui_right
			_move_rack_horizontal(-1)
		elif dir.x == -1:              # ui_left
			_move_rack_horizontal(1)
		elif dir.y == 1:               # ui_up
			_move_rack_vertical(1)
		elif dir.y == -1:              # ui_down
			_move_rack_vertical(-1)

# Nawigacja po siatce inwentarza. dx: -1 lewo / +1 prawo, dy: +1 gora / -1 dol.
func _inventory_move(dx: int, dy: int) -> void:
	var items := _inventory_items()
	if items.is_empty():
		_exit_inventory()
		return
	var count: int = items.size()
	var columns: int = 3
	var grid := inventory_grid as GridContainer
	if grid:
		columns = maxi(1, grid.columns)

	var col: int = inventory_index % columns
	var cur_row: int = inventory_index / columns
	var last_row: int = (count - 1) / columns
	var new_index: int = inventory_index

	if dx == 1:                        # prawo (w obrebie rzedu)
		if col < columns - 1 and inventory_index + 1 < count:
			new_index = inventory_index + 1
	elif dx == -1:                     # lewo (w obrebie rzedu)
		if col > 0:
			new_index = inventory_index - 1
	elif dy == 1:                      # gora (ui_up)
		if inventory_index - columns >= 0:
			new_index = inventory_index - columns
	elif dy == -1:                     # dol (ui_down)
		if inventory_index + columns < count:
			new_index = inventory_index + columns
		elif cur_row < last_row:        # niepelny ostatni rzad -> ostatni element
			new_index = count - 1

	if new_index != inventory_index:
		inventory_index = new_index
		print_debug("[DeckNav] INV grid dx=%d dy=%d -> inv=%d (count=%d, cols=%d)" % [
			dx, dy, inventory_index, count, columns])
		_highlight_inventory()
		_scroll_to_selected_inventory()

func _scroll_to_selected_inventory() -> void:
	var items := _inventory_items()
	if inventory_index >= items.size():
		return
	var scroll := inventory_grid.get_parent() as ScrollContainer
	if scroll:
		scroll.ensure_control_visible(items[inventory_index])

# 'A' na stojaku: oznacz wybrany slot (held_index) i przejdź do inwentarza.
func _mark_and_enter_inventory() -> void:
	var items := _inventory_items()
	if items.is_empty():
		print_debug("[DeckNav] Inwentarz pusty -> nie ma czym wymienic, zostajemy na stojaku")
		return
	held_index = selected_index            # slot stojaka, ktory zamienimy
	nav_zone = ZONE_INVENTORY
	inventory_index = 0
	_highlight_selected()                  # zaznaczony slot stojaka zostaje podniesiony
	_highlight_inventory()

# 'B' / wyjście z inwentarza: anuluj oznaczenie i wróć na stojak bez zmian.
func _exit_inventory() -> void:
	nav_zone = ZONE_RACK
	held_index = -1
	_clear_inventory_highlight()
	_highlight_selected()

# 'A' w inwentarzu: wstaw wybraną bilę w oznaczony slot stojaka (held_index) i wróć.
func _pick_from_inventory() -> void:
	var items := _inventory_items()
	if inventory_index >= items.size():
		return
	var item = items[inventory_index]
	if held_index < 0 or held_index >= PlayerData.current_deck.size():
		print_debug("[DeckNav] Brak poprawnego oznaczonego slotu (held=%d) -> anuluj" % held_index)
		_exit_inventory()
		return
	print_debug("[DeckNav] WYMIANA: slot stojaka=%d <- inwentarz idx=%d (%s)" % [
		held_index, inventory_index, _ball_name(item.my_ball_data if "my_ball_data" in item else null)])
	PlayerData.current_deck[held_index] = item.my_ball_data
	_respawn_deck()
	_refresh_inventory_ui()
	_exit_inventory()

func _inventory_items() -> Array:
	var result: Array = []
	if not inventory_grid:
		return result
	for item in inventory_grid.get_children():
		if item is Control and item.visible:
			result.append(item)
	return result

func _highlight_inventory() -> void:
	var items := _inventory_items()
	if inventory_index < items.size():
		var sel_item = items[inventory_index]
		var bd = sel_item.my_ball_data if "my_ball_data" in sel_item else null
		print_debug("[DeckNav] >>> ZAZNACZONA bila w INWENTARZU: inv=%d nazwa=%s" % [
			inventory_index, _ball_name(bd)])
		# opis zaznaczonej kuli z inwentarza w tym samym statycznym miejscu
		_show_tooltip_static_data(bd)
	for i in range(items.size()):
		var target: Color = Color(1, 1, 1, 1) if i == inventory_index else Color(0.55, 0.55, 0.6, 1)
		var tw = create_tween()
		tw.tween_property(items[i], "modulate", target, 0.12)

func _clear_inventory_highlight() -> void:
	for item in _inventory_items():
		item.modulate = Color(1, 1, 1, 1)

func _highlight_selected() -> void:
	var children = balls.get_children()
	for i in range(children.size()):
		var ball = children[i]
		var base_y: float = POSITIONS[i].y if i < POSITIONS.size() else 0.0
		var lift: float = 0.0
		if i == held_index:
			lift = SELECT_LIFT_HELD       # oznaczona do wymiany - wyzej
		elif i == selected_index:
			lift = SELECT_LIFT            # zaznaczona - lekko uniesiona
		var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ball, "position:y", base_y + lift, 0.15)

	# tooltip pokazuj tylko gdy jesteśmy na stojaku (w statycznym miejscu, nie przy myszy)
	if nav_zone == ZONE_RACK and selected_index < children.size():
		var bd = children[selected_index].get_meta("ball_data", null)
		print_debug("[DeckNav] >>> ZAZNACZONA bila na STOJAKU: idx=%d nazwa=%s (held=%d)" % [
			selected_index, _ball_name(bd), held_index])
		_show_tooltip_static(children[selected_index])

func _input(event: InputEvent) -> void:
	if not is_dragging:
		return
		
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_end_drag()
	elif event is InputEventMouseMotion:
		_handle_drag(event)



func _get_viewport_mouse_pos(global_mouse_pos: Vector2) -> Vector2:
	# Convert global screen coordinates to SubViewport coordinates
	# accounting for SubViewportContainer position and stretch_shrink
	if not sub_viewport_container:
		return global_mouse_pos
	
	var local_pos = sub_viewport_container.get_global_transform().affine_inverse() * global_mouse_pos
	# stretch_shrink defaults to 1 if not set, but in this scene it is 2
	var shrink = sub_viewport_container.stretch_shrink
	return local_pos / float(shrink)

func _handle_drag(_event: InputEvent) -> void:
	if not dragged_ball:
		return
	
	var global_mouse_pos = get_viewport().get_mouse_position()
	var vp_mouse_pos = _get_viewport_mouse_pos(global_mouse_pos)
	
	# Raycast to a horizontal plane at drag_plane_y
	var origin = camera.project_ray_origin(vp_mouse_pos)
	var direction = camera.project_ray_normal(vp_mouse_pos)
	
	if abs(direction.y) > 0.001:
		var t = (0.0 - origin.y) / direction.y
		var intersect_pos = origin + direction * t
		dragged_ball.global_position = intersect_pos + drag_offset

func _end_drag() -> void:
	is_dragging = false
	if not dragged_ball:
		return
	
	# Check if we dropped over another rack position
	var global_mouse_pos = get_viewport().get_mouse_position()
	var nearest_slot = get_rack_slot_at_screen_pos(global_mouse_pos)
	
	# If we found a valid slot
	if nearest_slot != -1:
		# Swap logical deck
		var old_index = balls.get_children().find(dragged_ball)
		if old_index != nearest_slot and old_index != -1:
			is_swapping = true
			
			# Visual swap animation
			var other_ball = balls.get_child(nearest_slot)
			var target_pos_A = balls.to_global(POSITIONS[nearest_slot]) # dragged ball dest
			var target_pos_B = balls.to_global(POSITIONS[old_index]) # other ball dest
			
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.set_ease(Tween.EASE_OUT)
			tween.set_parallel(true)
			
			# Animate dragged ball
			tween.tween_property(dragged_ball, "global_position", target_pos_A, 0.3)
			tween.tween_property(dragged_ball, "rotation", _get_face_camera_rotation(target_pos_A), 0.3)
			
			# Animate other ball (if exists)
			if other_ball:
				tween.tween_property(other_ball, "global_position", target_pos_B, 0.3)
				tween.tween_property(other_ball, "rotation", _get_face_camera_rotation(target_pos_B), 0.3)
			
			await tween.finished
			
			# Logical Swap
			var temp = PlayerData.current_deck[old_index]
			PlayerData.current_deck[old_index] = PlayerData.current_deck[nearest_slot]
			PlayerData.current_deck[nearest_slot] = temp
			
			_respawn_deck()
			dragged_ball = null
			is_swapping = false
			return

	# Check if dropped over inventory
	var inventory_item = _get_inventory_item_at_screen_pos(global_mouse_pos)
	if inventory_item:
		var old_index = balls.get_children().find(dragged_ball)
		if old_index != -1:
			# Swap with inventory item
			PlayerData.current_deck[old_index] = inventory_item.my_ball_data
			
			_respawn_deck()
			_refresh_inventory_ui()
			
			dragged_ball = null
			return

	# Return to original
	var old_index = balls.get_children().find(dragged_ball)
	if old_index != -1:
		var target_pos = balls.to_global(POSITIONS[old_index])
		var target_rot = _get_face_camera_rotation(target_pos)
		
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(dragged_ball, "global_position", target_pos, 0.3)
		tween.parallel().tween_property(dragged_ball, "rotation", target_rot, 0.3)

	dragged_ball = null

func _get_inventory_item_at_screen_pos(screen_pos: Vector2) -> Control:
	if not inventory_grid:
		return null
		
	# Check all inventory items (children of grid)
	for item in inventory_grid.get_children():
		if item is Control and item.visible:
			if item.get_global_rect().has_point(screen_pos):
				return item
	return null

func _get_face_camera_rotation(ball_pos: Vector3) -> Vector3:
	var dir_to_cam = (camera.global_position - ball_pos).normalized()
	var angle_y = atan2(dir_to_cam.x, dir_to_cam.z) + PI
	var angle_x = -asin(dir_to_cam.y)
	return Vector3(angle_x, angle_y, 0.0)

func _respawn_deck() -> void:
	# Keep is_dragging state clean just in case
	is_dragging = false
	for child in balls.get_children():
		child.queue_free()
	_spawn_balls()

func receive_inventory_drop(ball_data: BallData, screen_pos: Vector2) -> bool:
	var slot_index = get_rack_slot_at_screen_pos(screen_pos)
	
	if slot_index != -1:
		PlayerData.current_deck[slot_index] = ball_data
		_respawn_deck()
		_refresh_inventory_ui()
		return true
		
	return false

func get_rack_slot_at_screen_pos(screen_pos: Vector2) -> int:
	var vp_mouse_pos = _get_viewport_mouse_pos(screen_pos)
	var origin = camera.project_ray_origin(vp_mouse_pos)
	var direction = camera.project_ray_normal(vp_mouse_pos)
	
	var min_dist_sq = 10000.0 
	var best_idx = -1
	
	for i in range(POSITIONS.size()):
		if i >= PlayerData.current_deck.size():
			continue
			
		var world_pos = balls.to_global(POSITIONS[i])
		var center = world_pos
		var radius = 0.5 # Slightly larger radius for easier dropping
		
		# Check intersection with sphere
		if _ray_intersects_sphere(origin, direction, center, radius):
			var dist = origin.distance_to(center)
			if dist < min_dist_sq:
				min_dist_sq = dist
				best_idx = i
				
	return best_idx

func _ray_intersects_sphere(origin: Vector3, dir: Vector3, center: Vector3, radius: float) -> bool:
	var L = center - origin
	var tca = L.dot(dir)
	if tca < 0: return false
	var d2 = L.dot(L) - tca * tca
	if d2 > radius * radius: return false
	return true

func _on_back_button_pressed() -> void:
	LoadManager.load_scene(ScenePaths.LEVEL_SELECT_MAP)

func _apply_level_shader() -> void:
	if not edge_shader: return
	var mat: ShaderMaterial = edge_shader.mesh.material as ShaderMaterial
	if not mat: mat = edge_shader.get_active_material(0) as ShaderMaterial
	if not mat: return
	
	var params = LEVEL_SHADER_PARAMS.get(PlayerData.current_level, null)
	if params:
		mat.set_shader_parameter("tintColor", params["tintColor"])
		mat.set_shader_parameter("lineShadow", params["lineShadow"])
		mat.set_shader_parameter("tintStrength", params["tintStrength"])

func _on_confirm_button_pressed() -> void:
	emit_signal("deck_selected")
	LoadManager.load_scene(PlayerData.get_level_path())

func _refresh_inventory_ui() -> void:
	if not inventory_grid:
		return
	for child in inventory_grid.get_children():
		child.queue_free()

	var owned_ids = PlayerData.owned_balls
	var deck = PlayerData.current_deck

	for ball_id in owned_ids:
		var ball_data = PlayerData.ball_data_map.get(ball_id)
		if not ball_data or ball_data in deck:
			continue

		var item = INVENTORY_ITEM_SCENE.instantiate()
		inventory_grid.add_child(item)
		item.setup(ball_data)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _spawn_balls() -> void:
	if not PlayerData: return

	var deck = PlayerData.current_deck
	var balls_to_spawn = min(deck.size(), POSITIONS.size())

	for i in range(balls_to_spawn):
		var ball_data: BallData = deck[i]
		if not ball_data or not ball_data.scene:
			continue

		var ball: BallParent = ball_data.scene.instantiate()
		if ball_data.texture:
			var mesh = ball.get_node_or_null("MeshInstance3D")
			if mesh:
				var new_mat = StandardMaterial3D.new()
				new_mat.albedo_texture = ball_data.texture
				mesh.material_override = new_mat

		ball.input_event.connect(_on_ball_input_event.bind(ball))
		ball.mouse_entered.connect(_on_ball_mouse_entered.bind(ball))
		ball.mouse_exited.connect(_on_ball_mouse_exited.bind(ball))
		
		# Metadata for tooltip
		ball.set_meta("ball_data", ball_data)

		balls.add_child(ball)
		ball.position = POSITIONS[i]
		ball.rotation = _get_face_camera_rotation(ball.global_position)
		ball.freeze = true

func _cache_tooltip_static_pos() -> void:
	if tooltip_panel and not _tooltip_static_cached:
		_tooltip_static_offsets = Vector4(
			tooltip_panel.offset_left, tooltip_panel.offset_top,
			tooltip_panel.offset_right, tooltip_panel.offset_bottom)
		_tooltip_static_cached = true

# Ustawia tekst tooltipa z BallData. Zwraca true, jesli pokazano.
func _apply_tooltip_text_data(ball_data: BallData) -> bool:
	if is_dragging or is_swapping:
		return false
	if not ball_data:
		return false
	if not (tooltip_panel and tooltip_label):
		return false
	var desc = ball_data.shop_description
	if desc == null or desc == "":
		return false
	tooltip_label.text = desc
	tooltip_panel.visible = true
	return true

func _apply_tooltip_text(ball_node: Node3D) -> bool:
	return _apply_tooltip_text_data(ball_node.get_meta("ball_data", null) as BallData)

# Najechanie myszka -> tooltip goni kursor.
func _on_ball_mouse_entered(ball_node: Node3D) -> void:
	if _apply_tooltip_text(ball_node):
		tooltip_follow_mouse = true
		_update_tooltip_pos()

# Wybor strzalkami/padem -> tooltip w statycznym miejscu ze sceny (z BallData).
func _show_tooltip_static_data(ball_data: BallData) -> void:
	if _apply_tooltip_text_data(ball_data):
		tooltip_follow_mouse = false
		_cache_tooltip_static_pos()
		# przywroc kotwicowy uklad ze sceny (panel sam usiadzie na dole-srodku)
		tooltip_panel.offset_left = _tooltip_static_offsets.x
		tooltip_panel.offset_top = _tooltip_static_offsets.y
		tooltip_panel.offset_right = _tooltip_static_offsets.z
		tooltip_panel.offset_bottom = _tooltip_static_offsets.w

func _show_tooltip_static(ball_node: Node3D) -> void:
	_show_tooltip_static_data(ball_node.get_meta("ball_data", null) as BallData)

func _on_ball_mouse_exited(_ball_node: Node3D) -> void:
	if tooltip_panel:
		tooltip_panel.visible = false

func _process(delta: float) -> void:
	_process_navigation(delta)
	if tooltip_follow_mouse and tooltip_panel and tooltip_panel.visible:
		_update_tooltip_pos()

func _update_tooltip_pos() -> void:
	if not tooltip_panel: return
	var mouse_pos = get_viewport().get_mouse_position()
	tooltip_panel.position = mouse_pos + Vector2(20, 20)
	
	# Clamp to screen
	var screen_size = get_viewport().get_visible_rect().size
	if tooltip_panel.position.x + tooltip_panel.size.x > screen_size.x:
		tooltip_panel.position.x = mouse_pos.x - tooltip_panel.size.x - 10
	if tooltip_panel.position.y + tooltip_panel.size.y > screen_size.y:
		tooltip_panel.position.y = screen_size.y - tooltip_panel.size.y



func _on_ball_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int, ball_node: Node3D) -> void:
	if is_swapping: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var bd = ball_node.get_meta("ball_data", null)
		print_debug("[DeckNav] !!! MYSZ klik na bile: nazwa=%s (zrodlo=InputEventMouseButton, NIE d-pad) — start drag" % _ball_name(bd))
		if not is_dragging:
			is_dragging = true
			dragged_ball = ball_node
			
			# Start drag logic
			if tooltip_panel:
				tooltip_panel.visible = false
			# Drag at table level (no lifting)
			
			# Calculate correct plane intersection at start to maintain offset
			var global_mouse_pos = get_viewport().get_mouse_position() # Window coords
			var vp_mouse_pos = _get_viewport_mouse_pos(global_mouse_pos)
			
			var origin = camera.project_ray_origin(vp_mouse_pos)
			var direction = camera.project_ray_normal(vp_mouse_pos)
			
			# Intersect with drag_plane_y = 0.0
			if abs(direction.y) > 0.001:
				var t = (0.0 - origin.y) / direction.y
				var intersect_pos = origin + direction * t
				drag_offset = ball_node.global_position - intersect_pos
