extends PanelContainer

signal purchase_requested(ball_id, cost)

@onready var buy_button: Button = $ContentLayer/BuyButton
@onready var card_anchor: Node3D = $ContentLayer/SubViewportContainer/SubViewport/CardAnchor

# References to nodes inside the instantiated card scene
var card_node: Node3D
# Using exact types if possible, or Node for safety
var name_label: Node
var desc_label: Node
var cost_label: Node
var base_points_label: Node
var ball_parent: Node3D

var ball_id: String = ""
var cost: int = 0

func setup_shop_item(id: String, data: Resource, is_owned: bool, player_points: int) -> void:
	ball_id = id
	cost = data.shop_cost
	
	# Attempt to find the card instance
	if card_anchor.get_child_count() > 0:
		card_node = card_anchor.get_child(0)
		# Disable the card's native movement logic which depends on specific camera setups
		card_node.set_process(false)
		
		# Find visual elements
		# Path in card.tscn: Card/Contents/Name
		name_label = card_node.find_child("Name", true, false)
		desc_label = card_node.find_child("Description", true, false)
		cost_label = card_node.find_child("Points", true, false)
		base_points_label = card_node.find_child("BasePoints", true, false)

		# Hide unrelated/unused elements
		var elements_to_hide = ["Mult", "MultLabel", "Ability", "AbilityIcon"]
		for elem_name in elements_to_hide:
			var node = card_node.find_child(elem_name, true, false)
			if node:
				node.visible = false
		
		# Link Ball Parent
		# We target the one on the card surface first: Card/Ball
		var main_card_sprite = card_node.find_child("Card", true, false)
		if main_card_sprite:
			ball_parent = main_card_sprite.find_child("Ball", true, false)
	
	if name_label:
		name_label.text = data.display_name if (data.display_name and data.display_name != "") else id.capitalize()

	if desc_label:
		desc_label.text = " "#data.shop_description

	if cost_label:
		cost_label.text = str(cost)

	if base_points_label:
		base_points_label.text = str(data.base_value)

	setup_ball_visuals(data)
	
	update_state(is_owned, player_points)
	
	# Connect button
	if buy_button.pressed.is_connected(_on_buy_pressed):
		buy_button.pressed.disconnect(_on_buy_pressed)
	buy_button.pressed.connect(_on_buy_pressed)

func setup_ball_visuals(data: Resource):
	if not ball_parent: return
	
	# Store existing transform to preserve generic position if needed?
	# No, we'll rely on the added child's transform or reset it.
	
	for child in ball_parent.get_children():
		child.queue_free()
		
	var ball_scene = data.scene
	var texture = data.texture
	
	if ball_scene:
		var custom_ball = ball_scene.instantiate()
		ball_parent.add_child(custom_ball)
		custom_ball.position = Vector3.ZERO
		custom_ball.rotation_degrees = Vector3(0, 180, 0) # Turn ball to face camera
		custom_ball.scale = Vector3(0.5, 0.5, 0.5) # Scale down to fit card

		# Disable physics
		if custom_ball is RigidBody3D:
			custom_ball.freeze = true
			custom_ball.collision_layer = 0
			custom_ball.collision_mask = 0
			
		# Fix particle coords
		for part in custom_ball.find_children("*", "GPUParticles3D", true):
			part.local_coords = true
		for part in custom_ball.find_children("*", "CPUParticles3D", true):
			part.local_coords = true
			
		# Apply texture if available and applicable
		if texture:
			var mesh_matches = custom_ball.find_children("*", "MeshInstance3D", true, false)
			if mesh_matches.size() > 0:
				var mesh = mesh_matches[0]
				var new_mat = StandardMaterial3D.new()
				new_mat.albedo_texture = texture
				mesh.material_override = new_mat

func update_state(is_owned: bool, current_points: int) -> void:
	if is_owned:
		buy_button.text = "POSIADASZ"
		buy_button.disabled = true
		# Optional: Dim the whole card?
		modulate = Color(0.9, 0.9, 0.9, 1.0)
	else:
		buy_button.text = "KUP"
		buy_button.disabled = (current_points < cost)
		modulate = Color.WHITE

func _on_buy_pressed():
	purchase_requested.emit(ball_id, cost)

func play_success_anim():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
