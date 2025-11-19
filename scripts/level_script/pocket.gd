extends Area3D

func _ready() -> void:
	body_entered.connect(_on_pocket_body_entered)


func _on_pocket_body_entered(body: Node3D) -> void:
	if body is BallParent:
		print("DUPA")
		body.pocketed()
