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
@onready var back_button: Button = $UI/BackContainer/ButtonBack
@onready var play_button: Button = $UI/PlayContainer/ButtonPlay
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

	if "black" not in PlayerData.owned_balls:
		PlayerData.owned_balls.append("black")
	if "speedy" not in PlayerData.owned_balls:
		PlayerData.owned_balls.append("speedy")
	_spawn_balls()
	_refresh_inventory_ui()
	_apply_level_shader()

	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	if play_button:
		play_button.pressed.connect(_on_confirm_button_pressed)

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

func _on_ball_mouse_entered(ball_node: Node3D) -> void:
	if is_dragging or is_swapping: return
	
	var ball_data = ball_node.get_meta("ball_data", null) as BallData
	if not ball_data: return
	
	if tooltip_panel and tooltip_label:
		var name_text = ball_data.display_name
		if name_text == "" and ball_data.resource_path != "":
			name_text = ball_data.resource_path.get_file().get_basename().capitalize()
			
		var desc = ball_data.shop_description
		tooltip_label.text = "%s\n%s" % [name_text, desc]
		tooltip_panel.visible = true
		_update_tooltip_pos()

func _on_ball_mouse_exited(_ball_node: Node3D) -> void:
	if tooltip_panel:
		tooltip_panel.visible = false

func _process(_delta: float) -> void:
	if tooltip_panel and tooltip_panel.visible:
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
