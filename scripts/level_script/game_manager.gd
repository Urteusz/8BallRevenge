extends Node3D

const BALLS_GROUP = "balls"

@export var default_level_move_count: int = 10
@export var player_ball: RigidBody3D
@export var shop_ui: Control

var moves_left: int
var game_over := false
var ball_list: Array
var points: int = 0
var move_again := false

signal player_died
signal player_win
signal moves_changed(moves_left: int)
signal points_changed(points: int)


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
	
	if shop_ui:
		connect("points_changed", shop_ui._on_points_updated)

func _on_ball_pocketed(ball):
	if ball == player_ball:
		moves_left -= 1
		emit_signal("moves_changed", moves_left)
		ball.sleeping = true
		ball.position = Vector3(0.093, 0.294, 10.219)
	else:
		move_again = true
		ball_list.erase(ball)
		ball.queue_free()
		if ball_list.size() == 0:
			emit_signal("player_win")


func _on_round_ended() -> void:
	if game_over:
		return
	if moves_left > 1:
		if !move_again:
			moves_left -= 1
		else:
			move_again = false
		
		emit_signal("moves_changed", moves_left)
	else:
		_on_game_over()

func _on_points_scored(points_earned: int, world_pos: Vector3) -> void:
	points += points_earned
	print_debug("Zdobyto punkty:", points_earned, "Suma:", points)
	emit_signal("points_changed", points)

func _on_game_over() -> void:
	if game_over:
		return
	game_over = true
	emit_signal("player_died")
