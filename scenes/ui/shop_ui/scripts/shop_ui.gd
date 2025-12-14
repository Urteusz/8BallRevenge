extends Control

@onready var shop_camera = $SubViewportContainer/SubViewport/Camera3D
@onready var shop_balls = $SubViewportContainer/SubViewport/ShopBalls
@onready var label = $LabelPoints
@onready var buttons_container = $HBoxContainer
@onready var continue_container = $"HBoxContainer2"
@onready var next_button: Button = $"HBoxContainer2/ButtonNextLevel"
@onready var scoredLabel = $PointsScored

var shop_open := false
var shop_positions_set := false
var points: int = 0

# Tablica przycisków
var buttons: Array[Button] = []

func _ready() -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	
	if scoredLabel:
		scoredLabel.visible = false
		scoredLabel.modulate.a = 0.0 # Przezroczystość na 0
	
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
	# 1. Oblicz różnicę zanim zaktualizujesz zmienną 'points'
	var delta = new_points - points
	# 2. Aktualizacja stanu
	points = new_points
	label.text = "Punkty: %d" % points
	# 3. Jeśli punkty zostały dodane (delta > 0), pokaż animację
	if delta > 0:
		show_score_popup(delta)

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

# Zmienna pomocnicza do przerywania poprzedniej animacji, 
# jeśli punkty wpadają bardzo szybko
var _score_tween: Tween


func show_score_popup(amount: int) -> void:
	if not scoredLabel: return
	
	# 1. Reset
	scoredLabel.text = "+%d" % amount
	scoredLabel.reset_size()
	scoredLabel.pivot_offset = scoredLabel.size / 2
	scoredLabel.position = (size / 2) - (scoredLabel.size / 2)
	
	scoredLabel.visible = true
	scoredLabel.modulate = Color.WHITE
	scoredLabel.rotation_degrees = 0
	scoredLabel.scale = Vector2(0, 0)
	
	# Zabijamy poprzednią animację (ważne!)
	if _score_tween:
		_score_tween.kill()
	
	_score_tween = create_tween()
	
	# --- LOGIKA PROGÓW ---
	
	# Zmienna, która określi, jak długo napis ma wisieć po animacji wejścia
	var wait_time = 0.5 
	
	# TIER 1: Normalny (< 500)
	if amount < 500:
		_score_tween.tween_property(scoredLabel, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		wait_time = 0.5
		
	# TIER 2: Epicki (500 - 3000)
	elif amount >= 500 and amount < 3000:
		scoredLabel.modulate = Color(1, 0.84, 0) # Gold
		
		_score_tween.set_parallel(true)
		_score_tween.tween_property(scoredLabel, "scale", Vector2(1.5, 1.5), 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		
		_score_tween.tween_property(scoredLabel, "rotation_degrees", 15, 0.2).set_ease(Tween.EASE_OUT)
		_score_tween.set_parallel(false)
		
		# Powrót rotacji do 0 (już sekwencyjnie)
		_score_tween.tween_property(scoredLabel, "rotation_degrees", 0, 0.2).set_trans(Tween.TRANS_BOUNCE)
		
		wait_time = 1.0

	# TIER 3: Legendarny (> 3000) - TU ZMIENIAMY CZASY
	else:
		scoredLabel.modulate = Color(1, 0.2, 0.4) # Red/Pink
		
		wait_time = 2.0 # Napis będzie wisiał przez 2 sekundy po zakończeniu obrotu
		
		_score_tween.set_parallel(true)
		
		# 1. Skalowanie: Wydłużone do 2.0 sekund
		_score_tween.tween_property(scoredLabel, "scale", Vector2(2.0, 2.0), 2.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		# 2. Obrót: Również 2.0 sekundy
		_score_tween.tween_property(scoredLabel, "rotation_degrees", 720, 2.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		
		_score_tween.set_parallel(false)

	# --- ZNIKANIE (Wspólne) ---
	
	# Czekaj (wartość ustawiona w if/else powyżej)
	_score_tween.tween_interval(wait_time)
	
	# Zanikanie i lot w górę
	_score_tween.set_parallel(true)
	_score_tween.tween_property(scoredLabel, "modulate:a", 0.0, 0.8) # Powolne znikanie (0.8s)
	_score_tween.tween_property(scoredLabel, "position:y", scoredLabel.position.y - 80, 0.8) # Wyższy lot
	
	_score_tween.set_parallel(false)
	_score_tween.tween_callback(scoredLabel.hide)
