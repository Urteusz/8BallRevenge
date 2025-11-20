extends Node

@export var ball_types: Array[BallData] # nie chce dzialac :/ nie pokazuje mi sie w edytorze z prawej
# a lepiej by bylo tak dodawac typy kul niz wpisywac sciezki

var player_balls: Array[BallData] = [] # Cala lista kul jakie gracz posiada do wyboru
var current_deck: Array[BallData] = [] # 

var current_level: int = 1

var red_ball_data = load("res://scenes/balls/ball_data/red_ball.tres")
var black_ball_data = load("res://scenes/balls/ball_data/black_ball.tres")
var blue_ball_data = load("res://scenes/balls/ball_data/blue_ball.tres")
var green_ball_data = load("res://scenes/balls/ball_data/green_ball.tres")
var purple_ball_data = load("res://scenes/balls/ball_data/purple_ball.tres")
var yellow_ball_data = load("res://scenes/balls/ball_data/yellow_ball.tres")
var bomb_ball_data = load("res://scenes/balls/ball_data/bomb_ball.tres")

const SAVE_PATH = "user://player_progress.save"

func _ready() -> void:
	# Ball spawner ma narazie tylko 6 pozycji wiec max 6 kul
	# Ustawiam tymczasowo bo nie ma jeszcze ui do wyboru kul
	
	current_deck.append(bomb_ball_data)
	current_deck.append(red_ball_data)
	current_deck.append(black_ball_data)
	current_deck.append(blue_ball_data)
	current_deck.append(green_ball_data)
	current_deck.append(yellow_ball_data)
	
	#current_deck.append(bomb_ball_data)
	#current_deck.append(bomb_ball_data)
	#current_deck.append(bomb_ball_data)
	#current_deck.append(bomb_ball_data)
	#current_deck.append(bomb_ball_data)
	#current_deck.append(bomb_ball_data)
	
func save_progress() -> void:
	var save_data = {
		"current_level": current_level,
		"player_balls": [], # Tutaj możesz zapisać ścieżki do BallData
		"current_deck": current_deck
	}

func get_level_path() -> String:
	var level_path = "LEVEL" + str(current_level) + "_PATH"
	
	if level_path in ScenePaths:
		return ScenePaths.get(level_path)
	else:
		push_warning("Nie znaleziono ścieżki dla poziomu: ", current_level)
		return ScenePaths.LEVEL1_PATH

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found, starting from level 1")
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		if save_data and save_data.has("current_level"):
			current_level = save_data.current_level
			print("Progress loaded: Level ", current_level)
		else:
			print("ERROR: Invalid save data")
	else:
		print("ERROR: Could not load progress")

func set_level(level: int) -> void:
	current_level = level
	save_progress()

func advance_level() -> void:
	current_level += 1
	save_progress()
