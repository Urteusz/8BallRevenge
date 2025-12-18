extends Node

# --- DANE KUL ---
@export var ball_types: Array[BallData] 

# Zmieniamy nazwy zmiennych dla jasności
var owned_balls: Array[String] = []  # Lista posiadanych kul (Inventory)
var current_deck: Array[BallData] = [] # Lista decku kul (Active Deck)
const MAX_DECK_SIZE = 6

var current_level: int = 1


var red_ball_data = load("res://scenes/balls/ball_data/red_ball.tres")
var black_ball_data = load("res://scenes/balls/ball_data/black_ball.tres")
var blue_ball_data = load("res://scenes/balls/ball_data/blue_ball.tres")
var green_ball_data = load("res://scenes/balls/ball_data/green_ball.tres")
var purple_ball_data = load("res://scenes/balls/ball_data/purple_ball.tres")
var yellow_ball_data = load("res://scenes/balls/ball_data/yellow_ball.tres")
var bomb_ball_data = load("res://scenes/balls/ball_data/bomb_ball.tres")
var speedy_ball_data = load("res://scenes/balls/ball_data/speedy_ball.tres")
var bouncy_ball_data = load("res://scenes/balls/ball_data/bouncy_ball.tres")
var magnetic_ball_data = load("res://scenes/balls/ball_data/magnetic_ball.tres")
var ice_ball_data = load("res://scenes/balls/ball_data/ice_ball.tres")
var magneticmin_ball_data = load("res://scenes/balls/magnetic_ball_min.tscn")

var ball_data_map = {
	"red": red_ball_data,
	"black": black_ball_data,
	"blue": blue_ball_data,
	"green": green_ball_data,
	"purple": purple_ball_data,
	"yellow": yellow_ball_data,
	"bomb": bomb_ball_data,
	"speedy": speedy_ball_data,
	"magnetic": magnetic_ball_data,
	"magnetic-": magneticmin_ball_data,
	"ice": ice_ball_data,
	"bouncy": bouncy_ball_data
}

const SAVE_PATH = "user://player_progress.save"

func _ready() -> void:
	# Domyślny start (jeśli nie ma zapisu)
	if owned_balls.is_empty():
		owned_balls = ["red", "blue", "purple", "yellow", "speedy", "green"]
	
	# Jeśli deck jest pusty, wypełnij go pierwszymi dostępnymi kulami
	if current_deck.is_empty():
		refresh_deck_from_owned()
	print("Dupa: "+str(current_level))

# Funkcja do odblokowania nowej kuli
func unlock_ball(ball_type: String) -> bool:
	if not ball_data_map.has(ball_type):
		push_error("Nieznany typ kuli: ", ball_type)
		return false
		
	if ball_type not in owned_balls:
		owned_balls.append(ball_type)
		save_progress()
		print("Odblokowano nową kulę: ", ball_type)
		return true
	
	print("Gracz już posiada tę kulę: ", ball_type)
	return false

# Funkcja do ustawiania kuli w konkretnym slocie ekwipunku
# index: 0-5 (slot w UI)
# ball_type: nazwa kuli (np. "bomb")
func equip_ball_in_slot(index: int, ball_type: String) -> bool:
	if index < 0 or index >= MAX_DECK_SIZE:
		push_error("Nieprawidłowy indeks slotu: ", index)
		return false

	# Sprawdzamy czy gracz w ogóle posiada tę kulę!
	if ball_type not in owned_balls:
		push_warning("Próba wyboru nieposiadanej kuli: ", ball_type)
		return false
		
	var new_ball_data = ball_data_map[ball_type]
	
	# Upewniamy się, że tablica ma odpowiedni rozmiar
	while current_deck.size() <= index:
		current_deck.append(null)
		
	current_deck[index] = new_ball_data
	save_progress()
	print("Wybrano kulę ", ball_type, " do slotu ", index)
	return true

func refresh_deck_from_owned():
	current_deck.clear()
	for i in range(min(owned_balls.size(), MAX_DECK_SIZE)):
		var type = owned_balls[i]
		if ball_data_map.has(type):
			current_deck.append(ball_data_map[type])


func save_progress() -> void:
	# Musimy zamienić obiekty BallData z decku z powrotem na stringi, żeby je zapisać
	var deck_as_strings = []
	for ball in current_deck:
		if ball != null:
			# Znajdź klucz dla tego zasobu (trochę wolne, ale przy zapisie ok)
			var found_key = ""
			for key in ball_data_map:
				if ball_data_map[key] == ball:
					found_key = key
					break
			if found_key != "":
				deck_as_strings.append(found_key)
	
	var save_data = {
		"current_level": current_level,
		"owned_balls": owned_balls,      # Zapisujemy listę stringów
		"current_deck_ids": deck_as_strings # Zapisujemy listę stringów
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("Zapisano postęp.")

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("Brak zapisu, start od nowa.")
		_ready()
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		if save_data:
			if save_data.has("current_level"):
				current_level = save_data.current_level
			
			if save_data.has("owned_balls"):
				owned_balls = save_data.owned_balls
			
			# Odtwórz deck na podstawie zapisanych ID
			if save_data.has("current_deck_ids"):
				current_deck.clear()
				for ball_id in save_data.current_deck_ids:
					if ball_data_map.has(ball_id):
						current_deck.append(ball_data_map[ball_id])
						
			print("Wczytano postęp: Poziom ", current_level)
		else:
			print("ERROR: Uszkodzony plik zapisu")
	else:
		print("ERROR: Nie można otworzyć pliku zapisu")


func get_level_path() -> String:
	var expected_path = "res://scenes/level"+ str(current_level) + "/level" + str(current_level) + ".tscn"

	if ResourceLoader.exists(expected_path):
		return expected_path
	else:
		push_warning("Poziom " + str(current_level) + " nie istnieje! Wracam do poziomu 1.")
		current_level = 1
		save_progress() 
		return "res://scenes/level1/level1.tscn"

func set_level(level: int) -> void:
	current_level = level
	save_progress()

func advance_level() -> void:
	current_level += 1
	save_progress()
