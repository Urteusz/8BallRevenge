extends MeshInstance3D

@onready var particles = get_node("UniParticles3D") 

func start_particles():
	if particles:
		particles.play()

func stop_particles():
	if particles:
		particles.stop(true)

func _ready() -> void:
	var mat0 = get_active_material(0)
	if mat0:
		var unique_mat0 = mat0.duplicate(true)
		set_surface_override_material(0, unique_mat0)

	var mat1 = get_active_material(1)
	if mat1:
		var unique_mat1 = mat1.duplicate(true)
		set_surface_override_material(1, unique_mat1)


func _process(delta: float) -> void:
	rotation.y += delta*2
	if particles:
		particles.global_rotation = Vector3.ZERO

func _on_mouse_entered():
	start_particles()
	get_tree().call_group("tooltip_popup", "show_message", "BOMB\nOn collision with other balls, sends a shockwave.")
	var current_mat = get_active_material(0)
	
	if current_mat and current_mat.next_pass and current_mat.next_pass.next_pass:
		var target_material = current_mat.next_pass.next_pass
		target_material.set_shader_parameter("outline_color", Color.REBECCA_PURPLE)
		target_material.set_shader_parameter("outline_thickness", 0.05)
	
func _on_static_body_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			LoadManager.load_scene(ScenePaths.LEVEL1_PATH)

func _on_mouse_exited():
	stop_particles()
	get_tree().call_group("tooltip_popup", "hide_message")
	var current_mat = get_active_material(0)
	
	if current_mat and current_mat.next_pass and current_mat.next_pass.next_pass:
		
		var target_material = current_mat.next_pass.next_pass
		
		target_material.set_shader_parameter("outline_color", Color.WHITE)
		target_material.set_shader_parameter("outline_thickness", 0.035)
