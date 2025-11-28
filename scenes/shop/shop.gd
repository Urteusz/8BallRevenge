extends Node3D

enum Mode {
	DEFAULT,
	BALL
};

const POSITIONS: Array = [
	Vector3(1.147, 0.0, -2.0),
	Vector3(1.736, 0.0, -1.0),
	Vector3(0.558, 0.0, -1.0),
	Vector3(1.147, 0.0, 0.0),
	Vector3(2.265, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
]
const BALL_HOVER_Y_OFFSET: float = 0.5
const BALL_ROTATION_SPEED: float = 1.0

@export var camera: Camera3D
@export var ball_scene: PackedScene
@export var ui: CanvasLayer
@onready var balls = $Balls

var mode = Mode.DEFAULT
var ball_original_position = Vector3.ZERO
var ball_original_rotation = Vector3.ZERO
var ball_being_viewed: BallParent = null

func _ready() -> void:
	_spawn_balls()
	
	# placeholder
	for ball_position in POSITIONS:
		var ball: BallParent = ball_scene.instantiate()
		ball.input_event.connect(_on_ball_input_event.bind(ball))
		ball.mouse_entered.connect(_on_ball_mouse_entered.bind(ball))
		ball.mouse_exited.connect(_on_ball_mouse_exited.bind(ball))
		balls.add_child(ball)
		ball.position = ball_position
		ball.global_rotation = (Vector3(0.0, 180, 0.0)) # inshallah scena jest do tylu 
		ball.freeze = true
		#for ball in balls.get_children():
			#ball.input_event.connect(_on_ball_input_event.bind(ball))
			#ball.mouse_entered.connect(_on_ball_mouse_entered.bind(ball))
			#ball.mouse_exited.connect(_on_ball_mouse_exited.bind(ball))
			
func _process(delta_time: float) -> void:
	if ball_being_viewed and mode == Mode.BALL: # jeden z tych warunkow niby by wystarczyl...
		ball_being_viewed.rotate(Vector3.UP, BALL_ROTATION_SPEED * delta_time)
		
func _spawn_balls() -> void:
	pass
	# TODO
	# bierze kule z listy dostepnych do sprzedazy i losuje i spawnuje
	#	albo kazda kula powinna miec swoja wersje specjalnie do sklepu
	#	albo moze nie?

func _on_ball_mouse_entered(ball_node: Node3D) -> void:
	if mode == Mode.DEFAULT:
		var mesh = ball_node.get_node_or_null("MeshInstance3D")
		if mesh:
			_animate_ball_height(mesh, BALL_HOVER_Y_OFFSET)

func _on_ball_mouse_exited(ball_node: Node3D) -> void:
	if mode == Mode.DEFAULT:
		var mesh = ball_node.get_node_or_null("MeshInstance3D")
		if mesh:
			_animate_ball_height(mesh, 0.0)

func _animate_ball_height(mesh: Node3D, target_y: float) -> void:
	if mesh.has_meta("active_tween"):
		var old_tween = mesh.get_meta("active_tween")
		if old_tween.is_valid():
			old_tween.kill()
	var tween = create_tween()
	mesh.set_meta("active_tween", tween)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(mesh, "position:y", target_y, 0.2)

func _on_ball_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int, ball_node: Node3D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match mode:
			Mode.DEFAULT:
				mode = Mode.BALL
				
				ball_original_position = ball_node.global_position
				ball_original_rotation = ball_node.global_rotation
				ball_being_viewed = ball_node
				
				# na wypadek jesli kula byla podniesiona
				var mesh = ball_node.get_node_or_null("MeshInstance3D")
				if mesh:
					_animate_ball_height(mesh, 0.0)
				
				const OFFSET_LEFT = Vector3(-1.0, 0.0, 0.0)
				const DISTANCE_FROM_CAMERA: float = 3.0
				
				var camera_forward = -camera.global_transform.basis.z
				var target_pos = camera.global_position + (camera_forward * DISTANCE_FROM_CAMERA) + OFFSET_LEFT
				var target_rotation = camera.global_rotation
				
				var tween = create_tween()
				tween.set_trans(Tween.TRANS_CUBIC)
				tween.set_ease(Tween.EASE_OUT)
				tween.tween_property(ball_node, "global_position", target_pos, 0.6)
				tween.parallel().tween_property(ball_node, "global_rotation", -target_rotation, 0.6)
				ui.visible = true
				
			Mode.BALL:
				if ball_node == ball_being_viewed:
					mode = Mode.DEFAULT
					ui.visible = false
					var tween = create_tween()
					tween.set_trans(Tween.TRANS_CUBIC)
					tween.set_ease(Tween.EASE_OUT)
					tween.tween_property(ball_node, "global_position", ball_original_position, 0.6)
					tween.parallel().tween_property(ball_node, "global_rotation", ball_original_rotation, 0.6)
					
