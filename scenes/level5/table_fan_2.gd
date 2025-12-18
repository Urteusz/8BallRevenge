extends AnimatableBody3D

@export var rotation_speed : float = 2.0

func _physics_process(delta):
	# rotate_object_local zapewnia obrót wokół własnej osi Y obiektu, 
	# niezależnie od tego, jak jest obrócony w świecie.
	rotate_object_local(Vector3.UP, rotation_speed * -delta)
