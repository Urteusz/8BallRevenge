extends PanelContainer

@onready var card_anchor: Node3D = $ContentLayer/SubViewportContainer/SubViewport/CardAnchor
@onready var sub_viewport: SubViewport = $ContentLayer/SubViewportContainer/SubViewport

var is_super_charged: bool = false
var card_node: Node3D
var name_label: Node
var points_label: Node
var ball_parent: Node3D
@onready var particles: CPUParticles2D = $ContentLayer/CPUParticles2D

func _ready() -> void:
	pivot_offset = size / 2
	if sub_viewport:
		sub_viewport.own_world_3d = true
		
	if card_anchor and card_anchor.get_child_count() > 0:
		card_node = card_anchor.get_child(0)
		card_node.set_process(false)
		
		name_label = card_node.find_child("Name", true, false)
		points_label = card_node.find_child("BasePoints", true, false)
		
		var main_card_sprite = card_node.find_child("Card", true, false)
		if main_card_sprite:
			ball_parent = main_card_sprite.find_child("Ball", true, false)

		var elements_to_hide = ["Mult", "MultLabel", "Ability", "AbilityIcon", "Description", "Points", "PointsLabel"]
		for elem_name in elements_to_hide:
			var node = card_node.find_child(elem_name, true, false)
			if node:
				node.visible = false

func _process(delta: float) -> void:
	if is_super_charged:
		rotation_degrees = randf_range(-3.0, 3.0)
	else:
		rotation_degrees = lerp(rotation_degrees, 0.0, delta * 10)

func setup_card(name_text: String, texture: Texture2D, ui_color: Color, points: int, ball_scene: PackedScene = null) -> void:
	if name_label:
		name_label.text = name_text
	update_points(points)
	
	if ball_scene != null:
		print("Ładowanie custom scene dla: ", name_text)
		
		if ball_parent:
			for child in ball_parent.get_children():
				child.queue_free()
		
			var custom_ball = ball_scene.instantiate()
			ball_parent.add_child(custom_ball)
			
			if custom_ball is RigidBody3D:
				custom_ball.freeze = true
				custom_ball.collision_layer = 0
				custom_ball.collision_mask = 0
			
			custom_ball.position = Vector3.ZERO
			custom_ball.rotation_degrees = Vector3(0, 180, 0)
			custom_ball.scale = Vector3(0.5, 0.5, 0.5)
			
			for part in custom_ball.find_children("*", "GPUParticles3D", true):
				part.local_coords = true
			for part in custom_ball.find_children("*", "CPUParticles3D", true):
				part.local_coords = true
			
			if texture != null:
				var mesh_matches = custom_ball.find_children("*", "MeshInstance3D", true, false)
				if mesh_matches.size() > 0:
					var mesh = mesh_matches[0]
					var new_mat = StandardMaterial3D.new()
					new_mat.albedo_texture = texture
					mesh.material_override = new_mat
	else:
		if ball_parent:
			for child in ball_parent.get_children():
				child.queue_free()
			var mat = StandardMaterial3D.new()
			mat.roughness = 0.2
			mat.metallic = 0.0
			
			if texture != null:
				mat.albedo_color = Color.WHITE
				mat.albedo_texture = texture
				if name_label:
					name_label.modulate = ui_color 
			else:
				mat.albedo_color = ui_color
			
			var mesh_inst = MeshInstance3D.new()
			mesh_inst.mesh = SphereMesh.new()
			mesh_inst.mesh.radius = 0.5
			mesh_inst.mesh.height = 1.0
			mesh_inst.set_surface_override_material(0, mat)
			ball_parent.add_child(mesh_inst)

func set_pocketed() -> void:
	modulate = Color(0.4, 0.4, 0.4, 0.5)

func update_points(new_value: int) -> void:
	if not points_label:
		return
	
	points_label.text = str(new_value)
	
	if particles:
		particles.restart()
		particles.emitting = true
	
	pivot_offset = size / 2 

	var tween = create_tween()
	tween.tween_property(points_label, "scale", Vector3(1.3, 1.3, 1.3), 0.05)
	tween.tween_property(points_label, "scale", Vector3(1.0, 1.0, 1.0), 0.1).set_trans(Tween.TRANS_BOUNCE)

	if new_value >= 1000:
		is_super_charged = true
		points_label.modulate = Color(0.8, 0.2, 1.0) # Fiolet
		
	elif new_value > 500:
		is_super_charged = false
		points_label.modulate = Color(1, 0.2, 0.2) # Czerwony
		
		var shake = create_tween()
		shake.tween_property(self, "rotation_degrees", 5.0, 0.05)
		shake.tween_property(self, "rotation_degrees", -5.0, 0.05)
		shake.tween_property(self, "rotation_degrees", 0.0, 0.05)
		
	else:
		is_super_charged = false
		points_label.modulate = Color(1, 0.84, 0)
