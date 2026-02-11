extends BallParent
class_name LavaBall

# Preload the BurnStatus script
const BurnScript = preload("res://scenes/balls/scripts/burn_status.gd")

@export_group("Burn Settings")
@export var burn_duration: float = 7.0
@export var points_per_tick: int = 50
@export var burn_vfx: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	# Enable contact monitoring for collision detection
	contact_monitor = true
	max_contacts_reported = 11

func _on_body_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	# Call parent method to keep base functionality (sound, hit points)
	super._on_body_entered(body_rid, body, body_shape_index, local_shape_index)
	
	if body == self:
		return
	
	# Mechanic: Don't burn the player
	if body.name == "PlayerBall":
		return
	
	# Mechanic: Don't burn other LavaBalls
	if body is LavaBall:
		return
		
	# Apply burn effect to any other BallParent
	if body is BallParent:
		call_deferred("apply_burn_effect", body)

func apply_burn_effect(target: BallParent) -> void:
	# Check if already burning
	if target.has_node("BurnStatus"):
		var existing = target.get_node("BurnStatus")
		# Reset duration if property exists
		if "time_elapsed" in existing:
			existing.time_elapsed = 0.0
	else:
		# Create new burn status
		var burn_node = Node3D.new()
		burn_node.name = "BurnStatus"
		burn_node.set_script(BurnScript)
		
		# Set properties from export vars
		burn_node.duration = burn_duration
		burn_node.points_per_tick = points_per_tick
		burn_node.vfx_scene = burn_vfx
		
		target.add_child(burn_node)
