extends MeshInstance3D

# Obiekt ktory ma powodowac ze niewidzialne sciany zmieniaja kolor
#	w momencie pisania ustawione na biala bile
@export var object_node: Node3D

var _material: ShaderMaterial


func _ready() -> void:
	_material = self.get_active_material(0)


	if not object_node:
		print_debug("Fade shader warning: 'Object to Track' is not set.")
	if not _material:
		print_debug("Fade shader warning: No ShaderMaterial found on surface 0.")


func _process(_delta: float) -> void:
	if object_node and _material:
		var object_pos: Vector3 = object_node.global_position
		_material.set_shader_parameter("object_position", object_pos)
	else:
		print_debug("object node or material are null, not pushing object position")
