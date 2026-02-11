extends ColorRect

func _process(_delta):
	# Get the shader material
	var mat = material as ShaderMaterial
	if mat:
		# Get mouse position relative to the ColorRect's size
		var mouse_rel = get_local_mouse_position() / size
		
		# Clamp values to keep the light inside 0-1 range even if mouse leaves window
		mouse_rel.x = clamp(mouse_rel.x, 0.0, 1.0)
		mouse_rel.y = clamp(mouse_rel.y, 0.0, 1.0)
		
		# Send to shader
		mat.set_shader_parameter("mouse_pos", mouse_rel)
