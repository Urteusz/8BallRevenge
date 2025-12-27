extends MeshInstance3D

var position_offset: float = PI
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position_offset += delta
	print_debug(sin(position_offset))
	position.x += sin(position_offset)
