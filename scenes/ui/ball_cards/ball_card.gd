extends PanelContainer

@onready var card_anchor: Node3D = $ContentLayer/SubViewportContainer/SubViewport/CardAnchor
@onready var sub_viewport: SubViewport = $ContentLayer/SubViewportContainer/SubViewport

var is_super_charged: bool = false
var is_pocketed: bool = false
var card_node: Node3D
var name_label: Node
var points_label: Node
var ball_parent: Node3D
@onready var particles: CPUParticles2D = $ContentLayer/CPUParticles2D

var physical_ball: Node3D = null
var is_aimed: bool = false
var base_z_index: int = 0

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

var target_rotation: float = 0.0

func _process(delta: float) -> void:
	if is_super_charged:
		rotation_degrees = randf_range(target_rotation - 3.0, target_rotation + 3.0)
	else:
		rotation_degrees = lerp(rotation_degrees, target_rotation, delta * 10)
		
	if is_instance_valid(physical_ball):
		if ball_parent and ball_parent.get_child_count() > 0:
			var model = ball_parent.get_child(0)
			# Sync rotation with the physical ball on the table
			model.global_transform.basis = physical_ball.global_transform.basis
			
			var speed = 0.0
			if physical_ball.is_class("RigidBody3D"):
				speed = physical_ball.linear_velocity.length()
				
			if speed > 6.0:
				var shake = min((speed - 6.0) * 0.5, 3.0)
				if card_node:
					card_node.position = Vector3(
						randf_range(-shake, shake) * 0.01,
						randf_range(-shake, shake) * 0.01,
						0
					)
			else:
				if card_node:
					card_node.position = card_node.position.lerp(Vector3.ZERO, delta * 10)

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
	is_pocketed = true
	modulate = Color(0.4, 0.4, 0.4, 0.5)

func bind_to_physical_ball(node: Node3D) -> void:
	physical_ball = node
	if physical_ball.has_signal("aimed_at"):
		physical_ball.connect("aimed_at", _on_aimed_at)
	if physical_ball.has_signal("unaimed_at"):
		physical_ball.connect("unaimed_at", _on_unaimed_at)

func _on_aimed_at() -> void:
	if is_pocketed: return
	is_aimed = true
	z_index = 5
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15)
	modulate = Color(1.2, 1.2, 1.2, 1.0) # Lekki glow

func _on_unaimed_at() -> void:
	if is_pocketed: return
	is_aimed = false
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_callback(func(): z_index = base_z_index)
	modulate = Color(1.0, 1.0, 1.0, 1.0)

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
