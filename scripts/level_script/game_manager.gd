extends Node3D

const BALLS_GROUP = "balls"

@export var default_level_move_count: int = 10
@export var player_ball: RigidBody3D
@export var shop_ui: Control
@export var gameplay_ui: Control

var moves_left: int
var game_over := false
var ball_list: Array
var points: int = 500
var turn_move_refunded := false 
var game_win := false

signal player_died
signal player_win
signal moves_changed(moves_left: int)
signal points_changed(points: int)
signal charging_started
signal charging_updated(charge_ratio: float)
signal charging_released

func _ready() -> void:
	moves_left = default_level_move_count
	
	ball_list.erase(player_ball)
	
	if player_ball and player_ball.has_signal("ball_pocketed"):
		player_ball.ball_pocketed.connect(_on_ball_pocketed)
	
	for ball in ball_list:
		if ball.has_signal("ball_pocketed"):
			ball.ball_pocketed.connect(_on_ball_pocketed)
		if ball.has_signal("points_scored"):
			ball.points_scored.connect(_on_points_scored)
	
	if player_ball.has_signal("round_ended"):
		player_ball.round_ended.connect(_on_round_ended)
		
	if player_ball.has_signal("ball_pushed"):
		player_ball.ball_pushed.connect(_on_ball_pushed)
	
	if shop_ui:
		connect("points_changed", shop_ui._on_points_updated)
	if gameplay_ui:
		connect("charging_started", gameplay_ui._on_charging_started)
		connect("charging_updated", gameplay_ui._on_charging_updated)
		connect("charging_released", gameplay_ui._on_charging_released)
		emit_signal("moves_changed", moves_left)

func _process(delta: float) -> void:
	if player_ball and player_ball.charging:
		var charge_ratio = clamp(
			player_ball.charge_timer / player_ball.max_charge_duration, 
			0.0, 
			1.0
		)
		emit_signal("charging_updated", charge_ratio)

func _input(event) -> void:
	if moves_left <= 0 and !player_ball.sleeping:
		return

	if event.is_action_pressed("push_ball") and player_ball:
		if player_ball.current_phase == player_ball.Phase.AIMING:
			emit_signal("charging_started")

func _on_ball_pushed(impulse_power: float) -> void:
	emit_signal("charging_released")
	
	moves_left -= 1
	emit_signal("moves_changed", moves_left)
	
	turn_move_refunded = false

func _on_ball_pocketed(ball):
	print("Pocketed")
	if ball == player_ball:
		moves_left -= 1
		emit_signal("moves_changed", moves_left)
		ball.sleeping = true
		ball.position = Vector3(0.093, 0.294, 10.219)
	else:
		if not turn_move_refunded:
			moves_left += 1
			turn_move_refunded = true
			emit_signal("moves_changed", moves_left)
			print("Bila wbita! Ruch zwrócony.")
		
		ball_list.erase(ball)
		ball.queue_free()
		_check_win_condition()

func _on_round_ended() -> void:
	if game_over or game_win:
		return
	
	if _check_win_condition():
		return
	
	if moves_left < 0: 
		moves_left = 0
		emit_signal("moves_changed", moves_left)
		_on_game_over()
	elif moves_left == 0:
		_on_game_over()

func _check_win_condition() -> bool:
	if ball_list.size() == 0:
		if !game_win and !game_over:
			game_win = true
			points = points * max(moves_left + 1, 1) 
			PlayerData.set_level(3)
			emit_signal("points_changed", points)
			emit_signal("player_win")
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
