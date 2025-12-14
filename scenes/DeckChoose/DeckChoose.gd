extends Node3D

signal deck_selected  # NOWY SYGNAŁ

enum Mode {
	DEFAULT,
	BALL
};

const POSITIONS: Array = [
	Vector3(1.147, 0.0, -2.0),
	Vector3(1.736, 0.0, -1.0),
	Vector3(0.558, 0.0, -1.0),
	Vector3(1.147, 0.0, 0.0),
	Vector3(2.265, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
]
const BALL_HOVER_Y_OFFSET: float = 0.5
const BALL_ROTATION_SPEED: float = 1.0

const INVENTORY_ITEM_SCENE = preload("res://scenes/DeckChoose/InventoryBallItem.tscn")

@export var camera: Camera3D
@export var ui: CanvasLayer
@export var panel_container: PanelContainer
@export var button_container: HBoxContainer
@export var confirm_button: Button
@onready var balls = $Balls

@export var inventory_grid: Container

var mode = Mode.DEFAULT
var ball_original_position = Vector3.ZERO
var ball_original_rotation = Vector3.ZERO
var ball_being_viewed: BallParent = null

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
	print("Talia potwierdzona! Rozpoczynanie gry...")
	emit_signal("deck_selected")

func _refresh_inventory_ui() -> void:
	if not inventory_grid:
		return
	for child in inventory_grid.get_children():
		child.queue_free()
	
	var owned_ids = PlayerData.owned_balls
	var deck = PlayerData.current_deck
	
	for ball_id in owned_ids:
		var ball_data = PlayerData.ball_data_map.get(ball_id)
		
		if not ball_data:
			continue
			
		if ball_data in deck:
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
	else:
		print("Wybierz najpierw kulę ze stołu, aby ją podmienić.")

func _swap_viewed_ball(new_ball_data: BallData) -> void:
	var ball_index = balls.get_children().find(ball_being_viewed)
	
	if ball_index == -1:
		push_error("Nie znaleziono oglądanej kuli w strukturze Balls!")
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


func _process(delta_time: float) -> void:
	if ball_being_viewed and mode == Mode.BALL:
		ball_being_viewed.rotate(Vector3.UP, BALL_ROTATION_SPEED * delta_time)

func _spawn_balls() -> void:
	if not PlayerData:
		push_error("PlayerData nie istnieje!")
		return
	
	var deck = PlayerData.current_deck
	
	var balls_to_spawn = min(deck.size(), POSITIONS.size())
	
	for i in range(balls_to_spawn):
		var ball_data: BallData = deck[i]
		if not ball_data or not ball_data.scene:
			push_warning("Brak BallData lub sceny dla kuli ", i)
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
		ball.global_rotation = Vector3(0.0, 180, 0.0)
		ball.freeze = true
		print(ball.name)

func _on_ball_mouse_entered(ball_node: Node3D) -> void:
	if mode == Mode.DEFAULT:
		_animate_ball_height(ball_node, BALL_HOVER_Y_OFFSET)

func _on_ball_mouse_exited(ball_node: Node3D) -> void:
	if mode == Mode.DEFAULT:
		_animate_ball_height(ball_node, 0.0)

func _animate_ball_height(node: Node3D, target_y: float) -> void:
	if node.has_meta("active_tween"):
		var old_tween = node.get_meta("active_tween")
		if old_tween.is_valid():
			old_tween.kill()
	var tween = create_tween()
	node.set_meta("active_tween", tween)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "position:y", target_y, 0.2)

func _on_ball_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int, ball_node: Node3D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match mode:
			Mode.DEFAULT:
				mode = Mode.BALL
				
				ball_original_position = ball_node.global_position
				ball_original_position.y = 0.0
				ball_original_rotation = ball_node.global_rotation
				ball_being_viewed = ball_node
				
				var mesh = ball_node.get_node_or_null("MeshInstance3D")
				if mesh:
					_animate_ball_height(mesh, 0.0)
				
				const OFFSET_LEFT = Vector3(-1.0, 0.0, 0.0)
				const DISTANCE_FROM_CAMERA: float = 3.0
				
				var camera_forward = -camera.global_transform.basis.z
				var target_pos = camera.global_position + (camera_forward * DISTANCE_FROM_CAMERA) + OFFSET_LEFT
				var target_rotation = camera.global_rotation
				
				var tween = create_tween()
				tween.set_trans(Tween.TRANS_CUBIC)
				tween.set_ease(Tween.EASE_OUT)
				tween.tween_property(ball_node, "global_position", target_pos, 0.6)
				tween.parallel().tween_property(ball_node, "global_rotation", -target_rotation, 0.6)
				
				if panel_container:
					panel_container.visible = true
				
			Mode.BALL:
				if ball_node == ball_being_viewed:
					mode = Mode.DEFAULT
					
					if panel_container:
						panel_container.visible = false
					
					var tween = create_tween()
					tween.set_trans(Tween.TRANS_CUBIC)
					tween.set_ease(Tween.EASE_OUT)
					tween.tween_property(ball_node, "global_position", ball_original_position, 0.6)
					tween.parallel().tween_property(ball_node, "global_rotation", ball_original_rotation, 0.6)
