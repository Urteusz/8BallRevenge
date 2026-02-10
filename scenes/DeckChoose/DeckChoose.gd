extends Node3D

signal deck_selected

enum Mode {
	DEFAULT,
	BALL
}

const POSITIONS: Array = [
	Vector3(1.147, 0.0, -2.0),
	Vector3(1.736, 0.0, -1.0),
	Vector3(0.558, 0.0, -1.0),
	Vector3(1.147, 0.0, 0.0),
	Vector3(2.265, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
]
const BALL_HOVER_Y_OFFSET: float = 0.5
const BALL_VIEW_PITCH: float = 70.0

const INVENTORY_ITEM_SCENE = preload("res://scenes/DeckChoose/InventoryBallItem.tscn")

@onready var camera: Camera3D = $SubViewportContainer/SubViewport/Camera3D
@onready var ui: CanvasLayer = $UI
@onready var panel_container: PanelContainer = $UI/PanelContainer
@onready var button_container: HBoxContainer = $UI/ExitContainer
@onready var confirm_button: Button = $UI/ExitContainer/ButtonContinue
@onready var balls = %Balls
@onready var inventory_grid: Container = $UI/PanelContainer/HBoxContainer/VBoxContainer/ScrollContainer/InventoryGrid

var mode = Mode.DEFAULT
var ball_original_position_index: int = -1
var ball_original_rotation = Vector3.ZERO
var ball_original_local_rotation = Vector3.ZERO
var ball_being_viewed: BallParent = null

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == Mode.BALL:
			# Klik gdziekolwiek poza inventory itemami odkłada kulę
			if not _is_mouse_over_inventory_item():
				_return_ball_to_rack()
				get_viewport().set_input_as_handled()

func _is_mouse_over_inventory_item() -> bool:
	if not inventory_grid or not panel_container or not panel_container.visible:
		return false
	var mouse_pos = get_viewport().get_mouse_position()
	for item in inventory_grid.get_children():
		if item is Control and item.get_global_rect().has_point(mouse_pos):
			return true
	return false

func _return_ball_to_rack() -> void:
	if not ball_being_viewed or ball_original_position_index == -1:
		return

	mode = Mode.DEFAULT
	if panel_container:
		panel_container.visible = false

	# Get original position from POSITIONS array
	var target_position = balls.to_global(POSITIONS[ball_original_position_index])

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ball_being_viewed, "global_position", target_position, 0.6)
	tween.parallel().tween_property(ball_being_viewed, "rotation", ball_original_local_rotation, 0.6)

	ball_being_viewed = null
	ball_original_position_index = -1

func _ready() -> void:
	if "black" not in PlayerData.owned_balls:
		PlayerData.owned_balls.append("black")
	if "speedy" not in PlayerData.owned_balls:
		PlayerData.owned_balls.append("speedy")
	_spawn_balls()
	_refresh_inventory_ui()

	if panel_container:
		panel_container.visible = false

	if button_container:
		button_container.visible = true

	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_button_pressed)

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
		item.clicked.connect(_on_inventory_item_clicked)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _on_inventory_item_clicked(new_ball_data: BallData) -> void:
	if mode == Mode.BALL and ball_being_viewed != null:
		_swap_viewed_ball(new_ball_data)

func _swap_viewed_ball(new_ball_data: BallData) -> void:
	var ball_index = balls.get_children().find(ball_being_viewed)
	if ball_index == -1:
		return

	PlayerData.current_deck[ball_index] = new_ball_data
	var current_global_pos = ball_being_viewed.global_position
	var current_global_rot = ball_being_viewed.global_rotation

	ball_being_viewed.queue_free()

	var new_ball: BallParent = new_ball_data.scene.instantiate()
	if new_ball_data.texture:
		var mesh = new_ball.get_node_or_null("MeshInstance3D")
		if mesh:
			var new_mat = StandardMaterial3D.new()
			new_mat.albedo_texture = new_ball_data.texture
			mesh.material_override = new_mat

	new_ball.input_event.connect(_on_ball_input_event.bind(new_ball))
	new_ball.mouse_entered.connect(_on_ball_mouse_entered.bind(new_ball))
	new_ball.mouse_exited.connect(_on_ball_mouse_exited.bind(new_ball))

	balls.add_child(new_ball)
	balls.move_child(new_ball, ball_index)

	new_ball.global_position = current_global_pos
	new_ball.global_rotation = current_global_rot
	new_ball.freeze = true

	ball_being_viewed = new_ball
	_refresh_inventory_ui()

func _spawn_balls() -> void:
	if not PlayerData:
		return

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

		balls.add_child(ball)
		ball.position = POSITIONS[i]

		# Reset rotation to zero first
		ball.rotation = Vector3.ZERO

		# Calculate direction to camera
		var dir_to_cam = (camera.global_position - ball.global_position).normalized()
		var angle_y = atan2(dir_to_cam.x, dir_to_cam.z) + PI
		var angle_x = -asin(dir_to_cam.y)  # Pitch up towards camera

		ball.rotation = Vector3(angle_x, angle_y, 0.0)
		ball.freeze = true

func _on_ball_mouse_entered(ball_node: Node3D) -> void:
	if mode == Mode.DEFAULT:
		var mesh = ball_node.get_node_or_null("MeshInstance3D")
		if mesh:
			_animate_ball_height(mesh, BALL_HOVER_Y_OFFSET)

func _on_ball_mouse_exited(ball_node: Node3D) -> void:
	if mode == Mode.DEFAULT:
		var mesh = ball_node.get_node_or_null("MeshInstance3D")
		if mesh:
			_animate_ball_height(mesh, 0.0)

func _animate_ball_height(target: Node3D, target_y: float) -> void:
	if target.has_meta("active_tween"):
		var old_tween = target.get_meta("active_tween")
		if old_tween.is_valid():
			old_tween.kill()
	
	var tween = create_tween()
	target.set_meta("active_tween", tween)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(target, "position:y", target_y, 0.2)

func _on_ball_input_event(camera_node: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int, ball_node: Node3D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match mode:
			Mode.DEFAULT:
				mode = Mode.BALL
				# Find ball index in balls container
				var ball_index = balls.get_children().find(ball_node)
				ball_original_position_index = ball_index
				ball_original_rotation = ball_node.global_rotation
				ball_original_local_rotation = ball_node.rotation
				ball_being_viewed = ball_node

				var mesh = ball_node.get_node_or_null("MeshInstance3D")
				if mesh:
					_animate_ball_height(mesh, 0.0)

				var camera_forward = -camera.global_transform.basis.z
				var target_pos = camera.global_position + (camera_forward * 3.0) + Vector3(-1.0, 0.0, 0.0)

				# Calculate simple rotation facing camera
				var dir_to_cam = (camera.global_position - target_pos).normalized()
				var target_angle_y = atan2(dir_to_cam.x, dir_to_cam.z) + PI
				var target_angle_x = -asin(dir_to_cam.y)  # Pitch up towards camera

				var target_rotation = Vector3(target_angle_x, target_angle_y, 0.0)

				var tween = create_tween()
				tween.set_trans(Tween.TRANS_CUBIC)
				tween.set_ease(Tween.EASE_OUT)
				tween.tween_property(ball_node, "global_position", target_pos, 0.6)
				tween.parallel().tween_property(ball_node, "rotation", target_rotation, 0.6)

				if panel_container:
					panel_container.visible = true

			Mode.BALL:
				# Klik na dowolną kulę w trybie BALL — odłóż aktualną
				_return_ball_to_rack()
