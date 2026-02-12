extends PanelContainer

signal purchase_requested(ball_id, cost)

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var price_label: Label = $VBoxContainer/PriceLabel
@onready var buy_button: Button = $VBoxContainer/BuyLabel 

@onready var ball_parent: Node3D = $VBoxContainer/SubViewportContainer/SubViewport/Node3D
@onready var ball_mesh_node: Node3D = $VBoxContainer/SubViewportContainer/SubViewport/Node3D/BallMesh

var rotation_speed: float = 0.5
var ball_id: String = ""
var cost: int = 0

func setup_shop_item(id: String, data: Resource, is_owned: bool, player_points: int) -> void:
	if not $VBoxContainer.has_node("Spacer"):
		var spacer := Control.new()
		spacer.name = "Spacer"
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		$VBoxContainer.add_child(spacer)
		$VBoxContainer.move_child(spacer, buy_button.get_index())
	ball_id = id
	cost = data.shop_cost
	
	name_label.text = data.display_name if ("display_name" in data and data.display_name != "") else id.capitalize()
	
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var desc = data.shop_description
	tooltip_text = "%s\n\n%s" % [name_label.text.to_upper(), desc]
	
	buy_button.tooltip_text = tooltip_text

	update_state(is_owned, player_points)
	
	var ball_scene = data.scene 
	var texture = data.texture
	
	if ball_scene:
		if ball_mesh_node:
			ball_mesh_node.queue_free()
			
		var custom_ball = ball_scene.instantiate()
		ball_parent.add_child(custom_ball) 
		
		custom_ball.position = Vector3.ZERO
		custom_ball.scale = Vector3(0.15, 0.15, 0.15)
		
		if custom_ball is RigidBody3D:
			custom_ball.freeze = true
			custom_ball.collision_layer = 0
			custom_ball.collision_mask = 0

		# Fix particlesów
		for part in custom_ball.find_children("*", "GPUParticles3D", true):
			part.local_coords = true
		for part in custom_ball.find_children("*", "CPUParticles3D", true):
			part.local_coords = true
			
		if texture:
			var mesh_matches = custom_ball.find_children("*", "MeshInstance3D", true, false)
			if mesh_matches.size() > 0:
				var mesh = mesh_matches[0]
				var new_mat = StandardMaterial3D.new()
				new_mat.albedo_texture = texture
				mesh.material_override = new_mat
		
		ball_mesh_node = custom_ball

	if buy_button.is_connected("pressed", _on_buy_pressed):
		buy_button.disconnect("pressed", _on_buy_pressed)
	buy_button.pressed.connect(_on_buy_pressed)

func update_state(is_owned: bool, current_points: int) -> void:
	if is_owned:
		buy_button.text = "OWNED"
		buy_button.disabled = true
		price_label.text = str(cost) + " pts"
		# Fix zielonego odcienia:
		modulate = Color.WHITE 
	else:
		buy_button.text = "BUY"
		price_label.text = str(cost) + " pts"
		modulate = Color.WHITE
		buy_button.disabled = (current_points < cost)

func _on_buy_pressed() -> void:
	purchase_requested.emit(ball_id, cost)

func play_success_anim() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
