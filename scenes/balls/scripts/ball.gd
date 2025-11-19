extends RigidBody3D

class_name BallParent

# Idiotyczne ale nie chcialo mi sie szukac lepszego sposobu 😏
@export var hit_particles: PackedScene
@export var hit_particles2: PackedScene
@export var hit_particles3: PackedScene

signal points_scored(points, world_position)
signal ball_pocketed(ball)


var points_popup = preload(ScenePaths.POINTS_POPUP_PATH)

# Bazowa ilosc punktow za zderzenie
@export var base_value: int = 100
#@export var point_multiplier: int = 1

var total_points: int = 0 # Suma punktow jaka sie dostanie za wbicie kuli
var total_bounces_round: int = 0 # Suma odbic w jednej rundzie (do momentu zatrzymania sie bialej bili)
var total_score_popup_instance = null


func pocketed() -> void:
	points_scored.emit(total_points, global_position)
	emit_signal("ball_pocketed", self)

func on_hit() -> void:
	total_bounces_round += 1

	var points_gained: int = _calculate_points()
	total_points += points_gained

	_show_popup(global_position, points_gained) # global_position -> miejsce kuli w momencie zderzenia
	_show_particles(global_position)


# Inne kule zmienialyby implementacje tego
func _calculate_points() -> int:
	return base_value * total_bounces_round


func _show_popup(hit_position: Vector3, points_gained: int) -> void:
	var popup_instance = points_popup.instantiate()
	get_parent().add_child(popup_instance)
	popup_instance.global_position = hit_position
	popup_instance.set_and_play(points_gained)
	print_debug(points_gained)

func _show_particles(hit_position: Vector3) -> void:
	if !hit_particles or !hit_particles2 or !hit_particles3:
		push_warning("Hit particles scene missing")
		return
	var particle_instance: GPUParticles3D = hit_particles.instantiate()
	var particle_instance2: GPUParticles3D = hit_particles2.instantiate()
	var particle_instance3: GPUParticles3D = hit_particles3.instantiate()
	get_tree().root.add_child(particle_instance)
	get_tree().root.add_child(particle_instance2)
	get_tree().root.add_child(particle_instance3)
	particle_instance.global_position = hit_position
	particle_instance2.global_position = hit_position
	particle_instance3.global_position = hit_position
	

func _on_body_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	$AudioStreamPlayer3D.play() # Narazie nie ma zadnego dzwieku ustawionego
	if body.is_in_group("table"):
		return
	on_hit()


func start_being_aimed_at() -> void:
	if !total_score_popup_instance:
		total_score_popup_instance = points_popup.instantiate()
		get_parent().add_child(total_score_popup_instance)
		total_score_popup_instance.global_position = global_position
		total_score_popup_instance.total_points(total_points)


func stop_being_aimed_at() -> void:
	if total_score_popup_instance:
		total_score_popup_instance.remove()
		total_score_popup_instance = null
	print_debug(name, " stopped getting aimed at")


func _on_round_ended() -> void:
	total_bounces_round = 0


func _ready() -> void:
	var error = body_shape_entered.connect(_on_body_entered)
	if error != OK:
		push_error("BŁĄD PODŁĄCZENIA body_entered dla:", name, " Error:", error)
