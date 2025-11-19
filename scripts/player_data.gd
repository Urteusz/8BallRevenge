extends Node

@export var ball_types: Array[BallData] # nie chce dzialac :/ nie pokazuje mi sie w edytorze z prawej
# a lepiej by bylo tak dodawac typy kul niz wpisywac sciezki

var player_balls: Array[BallData] = [] # Cala lista kul jakie gracz posiada do wyboru
var current_deck: Array[BallData] = [] # 

var red_ball_data = load("res://scenes/balls/ball_data/red_ball.tres")
var black_ball_data = load("res://scenes/balls/ball_data/black_ball.tres")
var blue_ball_data = load("res://scenes/balls/ball_data/blue_ball.tres")
var green_ball_data = load("res://scenes/balls/ball_data/green_ball.tres")
var purple_ball_data = load("res://scenes/balls/ball_data/purple_ball.tres")
var yellow_ball_data = load("res://scenes/balls/ball_data/yellow_ball.tres")
var bomb_ball_data = load("res://scenes/balls/ball_data/bomb_ball.tres")

func _ready() -> void:
	# Ball spawner ma narazie tylko 6 pozycji wiec max 6 kul
	# Ustawiam tymczasowo bo nie ma jeszcze ui do wyboru kul
	current_deck.append(red_ball_data)
	current_deck.append(black_ball_data)
	current_deck.append(blue_ball_data)
	current_deck.append(green_ball_data)
	current_deck.append(yellow_ball_data)
	current_deck.append(bomb_ball_data)
	
	#current_deck.append(bomb_ball_data)
	#current_deck.append(bomb_ball_data)
	#current_deck.append(bomb_ball_data)
	#current_deck.append(bomb_ball_data)
	#current_deck.append(bomb_ball_data)
	#current_deck.append(bomb_ball_data)
	
