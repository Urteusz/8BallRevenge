extends PanelContainer

@onready var ball_mesh: Node3D = $VBoxContainer/SubViewportContainer/SubViewport/Node3D/BallMesh  # 🆕 ZMIENIONE z MeshInstance3D na Node3D
@onready var name_label: Label = $VBoxContainer/BallName
@onready var sub_viewport: SubViewport = $VBoxContainer/SubViewportContainer/SubViewport
@onready var points_label: Label = $VBoxContainer/PointsLabel
@onready var particles: CPUParticles2D = $VBoxContainer/PointsLabel/CPUParticles2D

var rotation_speed: float = 0.5
var is_super_charged: bool = false

func _ready() -> void:
	pivot_offset = size / 2
	if sub_viewport:
		sub_viewport.own_world_3d = true

func _process(delta: float) -> void:
	if ball_mesh and rotation_speed > 0:
		ball_mesh.rotation.y += rotation_speed * delta
	
	if is_super_charged:
		rotation_degrees = randf_range(-3.0, 3.0)
	else:
		rotation_degrees = lerp(rotation_degrees, 0.0, delta * 10)

func setup_card(name_text: String, texture: Texture2D, ui_color: Color, points: int, ball_scene: PackedScene = null) -> void:
	name_label.text = name_text
	update_points(points)
	
	if ball_scene != null:
		print("Ładowanie custom scene dla: ", name_text)
		
		if ball_mesh:
			ball_mesh.queue_free()
		
		var custom_ball = ball_scene.instantiate()
		
		var node_3d = $VBoxContainer/SubViewportContainer/SubViewport/Node3D
		node_3d.add_child(custom_ball)
		
		if custom_ball is RigidBody3D:
			custom_ball.freeze = true
		
		custom_ball.position = Vector3.ZERO
		custom_ball.scale = Vector3(0.1, 0.1, 0.1)
		
		for part in custom_ball.find_children("*", "GPUParticles3D", true):
			part.local_coords = true
		
		if texture != null:
			var mesh = custom_ball.get_node_or_null("MeshInstance3D")
			if mesh:
				var new_mat = StandardMaterial3D.new()
				new_mat.albedo_texture = texture
				mesh.material_override = new_mat
		
		ball_mesh = custom_ball
	else:
		var mat = StandardMaterial3D.new()
		mat.roughness = 0.2
		mat.metallic = 0.0
		
		if texture != null:
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = texture
			
			name_label.modulate = ui_color 
		else:
			mat.albedo_color = ui_color
		
		if ball_mesh:
			ball_mesh.mesh = SphereMesh.new()
			ball_mesh.mesh.radius = 0.05
			ball_mesh.mesh.height = 0.1
			ball_mesh.set_surface_override_material(0, mat)

func set_pocketed() -> void:
	modulate = Color(0.4, 0.4, 0.4, 0.5)
	rotation_speed = 0.0

func update_points(new_value: int) -> void:
	if not points_label:
		return
	
	points_label.text = "Pts: " + str(new_value)
	
	if particles:
		particles.restart()
		particles.emitting = true
	
	pivot_offset = size / 2 

	# EFEKT 1: Pulsowanie tekstu
	var tween = create_tween()
	tween.tween_property(points_label, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(points_label, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BOUNCE)

	# EFEKT 2: "High Score" - Wściekłe trzęsienie
	if new_value >= 1000:
		# POZIOM 3: SUPER MOC (Fioletowy + Ciągłe trzęsienie)
		is_super_charged = true
		points_label.modulate = Color(0.8, 0.2, 1.0) # Fiolet
		
	elif new_value > 500:
		# POZIOM 2: WYSOKI WYNIK (Czerwony + Pojedynczy wstrząs)
		is_super_charged = false
		points_label.modulate = Color(1, 0.2, 0.2) # Czerwony
		
		# Jednorazowy wstrząs (Tween)
		var shake = create_tween()
		shake.tween_property(self, "rotation_degrees", 5.0, 0.05)
		shake.tween_property(self, "rotation_degrees", -5.0, 0.05)
		shake.tween_property(self, "rotation_degrees", 0.0, 0.05)
		
	else:
		# POZIOM 1: NORMALNY (Złoty)
		is_super_charged = false
		points_label.modulate = Color(1, 0.84, 0)
