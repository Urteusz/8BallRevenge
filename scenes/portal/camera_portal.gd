extends Portal

@export var player_camera: Camera3D

@onready var portal_camera: Camera3D = $SubViewport/Camera3D

func _process(_delta: float) -> void:
	if not player_camera or not destination_portal:
		return
	
	var relative_transform: Transform3D = self.global_transform.affine_inverse() * player_camera.global_transform
	var destination_portal_transform_flipped: Transform3D = destination_portal.global_transform.rotated_local(Vector3.UP, PI)
	
	portal_camera.global_transform = destination_portal_transform_flipped * relative_transform
