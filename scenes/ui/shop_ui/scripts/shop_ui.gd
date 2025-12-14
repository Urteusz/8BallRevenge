extends Control

@onready var shop_camera = $SubViewportContainer/SubViewport/Camera3D
@onready var shop_balls = $SubViewportContainer/SubViewport/ShopBalls
@onready var label = $LabelPoints
@onready var buttons_container = $HBoxContainer
@onready var continue_container = $"HBoxContainer2"
@onready var next_button: Button = $"HBoxContainer2/ButtonNextLevel"

var shop_open := false
var shop_positions_set := false
var points: int = 0

# Tablica przycisków
var buttons: Array[Button] = []

func _ready() -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	buttons_container.visible = false
	continue_container.visible = false
	
	next_button.pressed.connect(_on_next_level)
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Pobieramy przyciski i podłączamy sygnały
	for item_button in buttons_container.get_children():
		if item_button is Button:
			buttons.append(item_button)
			item_button.pressed.connect(_on_item_pressed.bind(item_button))
	
	# Sprawdź, co gracz już posiada (żeby nie mógł kupić dwa razy tego samego)
	_check_already_owned()
	
	# Inicjalizacja punktów (możesz tu pobrać punkty z PlayerData jeśli tam są trzymane)
	_on_points_updated(points) 

func _on_next_level() -> void:
	toggle_shop()
	continue_container.visible = false
	PlayerData.set_level(3)
	#PlayerData.advance_level() 
	LoadManager.load_scene(PlayerData.get_level_path())

func _on_points_updated(new_points: int) -> void:
	points = new_points
	label.text = "Punkty: %d" % points

# Helper do mapowania nazwy przycisku na typ kuli i koszt
func _get_item_data(button_text: String) -> Dictionary:
	match button_text:
		"Kulka Magnetyczna": return {"type": "magnetic", "cost": 10}
		"Kulka Zielona": return {"type": "green", "cost": 20}
		"Kulka Niebieska": return {"type": "blue", "cost": 30}
		"Kulka Szybka": return {"type": "speedy", "cost": 40}
		"Kulka Bomba": return {"type": "bomb", "cost": 50}
		_: return {}

# Funkcja sprawdzająca przy starcie, co jest już kupione
func _check_already_owned() -> void:
	for btn in buttons:
		var data = _get_item_data(btn.text)
		if data.is_empty(): 
			continue
			
		# Jeśli gracz ma już tę kulę w 'owned_balls' (z PlayerData)
		if PlayerData.owned_balls.has(data["type"]):
			btn.text = "Kupione"
			btn.disabled = true

func _on_item_pressed(btn: Button) -> void:
	var data = _get_item_data(btn.text)
	
	if data.is_empty():
		print_debug("Nieznany przedmiot: ", btn.text)
		return

	_buy_item(btn, data["cost"], data["type"])

func _buy_item(btn: Button, cost: int, ball_type: String) -> void:
	# 1. Sprawdź czy już posiada (zabezpieczenie logiczne)
	if PlayerData.owned_balls.has(ball_type):
		print_debug("Już posiadasz ten przedmiot!")
		return

	# 2. Sprawdź punkty
	if points >= cost:
		# 3. Spróbuj odblokować w PlayerData
		var success = PlayerData.unlock_ball(ball_type)
		
		if success:
			# Odejmij punkty i zaktualizuj UI
			points -= cost
			label.text = "Punkty: %d" % points
			
			btn.text = "Kupione"
			btn.disabled = true
			
			print_debug("Kupiono:", ball_type)
		else:
			print_debug("Błąd przy odblokowywaniu kuli (może błędna nazwa?)")
	else:
		print_debug("Za mało punktów! Wymagane: ", cost, ", Posiadane: ", points)

func _process(delta) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_shop()

func toggle_shop() -> void:
	shop_open = !shop_open
	continue_container.visible = shop_open
	buttons_container.visible = shop_open
	
	if has_node("QuitButton"):
		$QuitButton.visible = shop_open

	for shop_ball in shop_balls.get_children():
		shop_ball.visible = shop_open

	if shop_open:
		mouse_filter = Control.MOUSE_FILTER_STOP
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if not shop_positions_set:
			align_shop_items()
			shop_positions_set = true
		
		# Odśwież stan przycisków przy otwarciu (na wypadek zmian w innym miejscu)
		_check_already_owned()
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func align_shop_items() -> void:
	await get_tree().process_frame

func _on_quit_button_pressed() -> void:
	LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)
