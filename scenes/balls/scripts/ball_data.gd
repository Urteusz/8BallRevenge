extends Resource

class_name BallData

@export var scene: PackedScene
@export var texture: Texture2D
@export var base_value: int = 100
@export_group("Shop Data")
@export var shop_cost: int = 100
@export_multiline var shop_description: String = "Ball description visible in the shop."
