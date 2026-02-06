extends Area3D

@export var pocket_effect: PackedScene

func _ready() -> void:
	body_entered.connect(_on_pocket_body_entered)
	print("Pocket ready, effect assigned: ", pocket_effect != null)

func _on_pocket_body_entered(body: Node3D) -> void:
	print("Body entered pocket: ", body.name, self.name)
	
	if body is BallParent:
		print("Body is BallParent!")
		_show_pocket_effect(body.global_position)
		
		if body.has_method("pocketed"):
			body.pocketed()
		else:
			push_warning("BallParent doesn't have pocketed() method")
	else:
		print("Body is NOT BallParent, it's: ", body.get_class())

func _show_pocket_effect(pocket_position: Vector3) -> void:
	if !pocket_effect:
		push_warning("Pocket effect scene missing")
		return
	
	var effect_instance = pocket_effect.instantiate()
	get_tree().root.add_child(effect_instance)
	effect_instance.global_position = pocket_position
	
	print("Effect spawned at: ", pocket_position)
	
	effect_instance.emitting = true
