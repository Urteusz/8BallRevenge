extends Node3D

const BALLS_GROUP = "balls"

@export var default_level_move_count: int = 10
@export var player_ball: RigidBody3D
@export var shop_ui: Control
@export var gameplay_ui: Control
@export var returnPoint: Node3D
@export var star_score_treshold = 25000

var moves_left: int
var game_over := false
var ball_list: Array
var points: int = 500
var turn_move_refunded := false 
var game_win := false
var is_aiming_possible := false

signal player_died
signal player_win
signal moves_changed(moves_left: int)
signal points_changed(points: int)
signal charging_started
signal charging_updated(charge_ratio: float)
signal charging_released
signal ball_pocketed(ball_id: int)
signal charging_paused
signal player_win_with_score(score: int, treshould: int)
signal aiming_state_changed(is_aiming: bool)

func _ready() -> void:
	moves_left = default_level_move_count
	
	var all_balls = get_tree().get_nodes_in_group(BALLS_GROUP)
	ball_list = []
	
	for ball in all_balls:
		if ball == player_ball:
			continue
		ball_list.append(ball)
	
	if player_ball:
		if player_ball.has_signal("ball_pocketed"):
			player_ball.ball_pocketed.connect(_on_ball_pocketed)
		if player_ball.has_signal("shoot_requested"):
			player_ball.shoot_requested.connect(_on_shoot_requested)
		if player_ball.has_signal("turn_started"):
			player_ball.turn_started.connect(_on_turn_started)
		if player_ball.has_signal("ball_pushed"):
			player_ball.ball_pushed.connect(_on_ball_pushed)
		if player_ball.has_signal("charging_cancelled"):
			player_ball.charging_cancelled.connect(_on_charging_cancelled)

	if shop_ui:
		connect("points_changed", shop_ui._on_points_updated)
	if gameplay_ui:
		connect("charging_started", gameplay_ui._on_charging_started)
		connect("charging_updated", gameplay_ui._on_charging_updated)
		connect("charging_released", gameplay_ui._on_charging_released)
		connect("ball_pocketed", gameplay_ui._on_ball_pocketed)
		connect("aiming_state_changed", gameplay_ui._on_aiming_state_changed)
		emit_signal("moves_changed", moves_left)
	
	for ball in ball_list:
		if ball.has_signal("ball_pocketed"):
			ball.ball_pocketed.connect(_on_ball_pocketed)
		if ball.has_signal("points_scored"):
			ball.points_scored.connect(_on_points_scored)
		if ball.has_signal("score_updated"):
			if gameplay_ui:
				ball.score_updated.connect(gameplay_ui._on_ball_score_updated.bind(ball.get_instance_id()))
			else:
				print("BŁĄD: Brak GameplayUI!")

func _process(delta: float) -> void:
	# Aktualizacja charge ratio
	if player_ball and player_ball.charging:
		var charge_ratio = clamp(
			player_ball.charge_timer / player_ball.max_charge_duration,
			0.0,
			1.0
		)
		emit_signal("charging_updated", charge_ratio)

	# Check aiming state
	var current_aiming_state = (moves_left > 0) and !game_over and !game_win
	if player_ball and player_ball.has_method("can_shoot"):
		current_aiming_state = current_aiming_state and player_ball.can_shoot()
	else:
		current_aiming_state = current_aiming_state and _are_all_balls_stopped()
		
	if current_aiming_state != is_aiming_possible:
		is_aiming_possible = current_aiming_state
		emit_signal("aiming_state_changed", is_aiming_possible)

	# Check game over only when ALL balls are stopped
	if moves_left == 0 and _are_all_balls_stopped():
		if !game_over and !game_win:
			_on_game_over()

func _are_all_balls_stopped() -> bool:
	# Check if player ball is stopped
	if player_ball and not player_ball.is_fully_stopped():
		return false

	# Check if all other balls are stopped
	for ball in ball_list:
		if is_instance_valid(ball):
			var is_stopped = ball.sleeping or (
				ball.linear_velocity.length_squared() < 0.01 and
				ball.angular_velocity.length_squared() < 0.01
			)
			if not is_stopped:
				return false

	return true

func _input(event) -> void:
	if event.is_action_pressed("push_ball") and player_ball:
		if player_ball.can_shoot():
			emit_signal("charging_started")

func _on_shoot_requested() -> void:
	if moves_left > 0:
		player_ball.execute_shot()
	else:
		if player_ball.charging:
			player_ball.charging = false
			if player_ball.power_bar_root:
				player_ball.power_bar_root.visible = false
			if player_ball.crosshair:
				player_ball.crosshair.visible = false
			player_ball.charge_timer = 0.0
			player_ball.current_power_ratio = 0.0
			print("Brak ruchów! Poczekaj aż piłki staną.")

func _on_turn_started() -> void:
	moves_left -= 1
	moves_left = max(moves_left, 0)
	emit_signal("moves_changed", moves_left)
	turn_move_refunded = false
	print("Nowa tura. Ruchy: ", moves_left)
	
	if moves_left == 0:
		player_ball.allow_shooting(false)

func _on_charging_cancelled() -> void:
	emit_signal("charging_paused")

func _on_ball_pushed(impulse_power: float) -> void:
	emit_signal("charging_released")

func _on_ball_pocketed(ball):
	print("Pocketed")
	if ball == player_ball:
		moves_left -= 1
		moves_left = max(moves_left, 0)
		emit_signal("moves_changed", moves_left)
		ball.sleeping = true
		ball.position = returnPoint.position
	else:
		if not turn_move_refunded:
			moves_left += 1
			turn_move_refunded = true
			emit_signal("moves_changed", moves_left)
			print("Bila wbita! Ruch zwrócony. Ruchy: ", moves_left)
		if moves_left > 0 and player_ball:
			player_ball.allow_shooting(true)
		
		emit_signal("ball_pocketed", ball.get_instance_id())
		
		ball_list.erase(ball)
		ball.queue_free()
		_check_win_condition()

func _check_win_condition() -> bool:
	if ball_list.size() == 0:
		if !game_win and !game_over:
			game_win = true
			points = points * max(moves_left + 1, 1)
			# NIE inkrementujemy current_level tutaj - gwiazdki muszą być zapisane najpierw!
			# PlayerData.advance_level() wywoła się w gameplay_ui po zapisaniu gwiazdek
			emit_signal("points_changed", points)
			emit_signal("player_win")
			emit_signal("player_win_with_score",points,star_score_treshold)
			print("WYGRANA! Pozostałe ruchy: ", moves_left)
		return true
	return false

func _on_points_scored(points_earned: int, world_pos: Vector3) -> void:
	points += points_earned
	print_debug("Zdobyto punkty:", points_earned, "Suma:", points)
	emit_signal("points_changed", points)

func _on_game_over() -> void:
	if game_over or game_win:
		return
	
	game_over = true
	emit_signal("player_died")
	print("PRZEGRANA! Brak ruchów.")

func get_level_balls() -> Array:
	var balls_data_for_ui = []
	
	var balls_to_process = []
	
	balls_to_process = ball_list.duplicate()

	var deck = PlayerData.current_deck
	
	var count = min(balls_to_process.size(), deck.size())
	
	for i in range(count):
		var ball = balls_to_process[i]
		var ball_data: BallData = deck[i]
		
		var ui_color = Color.WHITE
		var ui_texture = null
		var ui_scene = null
		var ui_points = 0
		
		if ball_data:
			ui_scene = ball_data.scene
			ui_texture = ball_data.texture
			
			if "ui_color" in ball_data:
				ui_color = ball_data.ui_color
			elif ball_data.has_meta("ui_color"):
				ui_color = ball_data.get_meta("ui_color")
			else:
				var meshes = ball.find_children("*", "MeshInstance3D", true, false)
				if meshes.size() > 0:
					var mat = meshes[0].get_active_material(0)
					if mat is StandardMaterial3D or mat is ORMMaterial3D:
						ui_color = mat.albedo_color
		
		if "total_points" in ball:
			ui_points = ball.total_points
		elif "base_value" in ball:
			ui_points = 0
		
		if gameplay_ui and ball.has_signal("score_updated"):
			if not ball.score_updated.is_connected(gameplay_ui._on_ball_score_updated):
				ball.score_updated.connect(gameplay_ui._on_ball_score_updated.bind(ball.get_instance_id()))
		
		balls_data_for_ui.append({
			"id": ball.get_instance_id(),
			"color": ui_color,
			"texture": ui_texture,
			"scene": ui_scene,
			"points": ui_points,
			"name": _pretty_ball_name(ball.name)
		})
		
	return balls_data_for_ui

# Pomocnicza funkcja tymczasowa bo zrobimy se w .tres nazwy a nie takie gówno
func _pretty_ball_name(raw_name: String) -> String:
	var n: String = raw_name.strip_edges()
	if n.begins_with("@"):
		n = n.substr(1).strip_edges()
	n = n.replace(" (Instance)", "")
	n = n.replace("(Instance)", "")
	if n == "":
		return "Ball"
	var lower := n.to_lower()
	if lower.find("rigid") != -1 or lower.find("body") != -1 or lower.find("node") != -1 or lower.find("instance") != -1:
		return "Ball"
	n = n.replace("_", " ").strip_edges()
	var result := ""
	for c in n:
		var prev := ""
		if result.length() > 0:
			prev = result[result.length() - 1]
		if c != c.to_lower() and prev != " " and prev != "":
			result += " " + c
		else:
			result += c
	n = result.strip_edges()
	if n.length() > 0:
		return n.substr(0, 1).to_upper() + n.substr(1)
	return "Ball"
	
