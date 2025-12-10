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
var ilosc_zakupionych = 0

var item_bought = []
var buttons = []

func _ready() -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	
	if scoredLabel:
		scoredLabel.visible = false
		scoredLabel.modulate.a = 0.0 # Przezroczystość na 0
	
	buttons_container.visible = false
	continue_container.visible = false
	next_button.pressed.connect(_on_next_level)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item_button in buttons_container.get_children():
		buttons.append(item_button)
		item_button.connect("pressed", Callable(self, "_on_item_pressed").bind(item_button.text))

func _on_next_level() -> void:
	toggle_shop()
	continue_container.visible = false
	PlayerData.set_level(3)
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

func _on_item_pressed(item_name: String) -> void:
	match item_name:
		"Kulka Magnetyczna": _buy_item(item_name, 10, "magnetic")
		"Kulka Zielona": _buy_item(item_name, 20, "green")
		"Kulka Niebieska": _buy_item(item_name, 30, "blue")
		"Kulka Szybka": _buy_item(item_name, 40, "speedy")
		"Kulka Bomba": _buy_item(item_name, 50, "bomb")

func _buy_item(item_name: String, cost: int, ball_type: String) -> void:
	if item_name in item_bought:
		print_debug("Kupiono już ten prodkut")
		return
	if points >= cost:
		# Sprawdź czy gracz ma kulę do zamiany
		if PlayerData.current_deck.size() == 0:
			print_debug("Brak kul w decku do zamiany!")
			return
		# Odejmij punkty
		points -= cost
		label.text = "Punkty: %d" % points
		
		var success = PlayerData.replace_ball_in_deck(ilosc_zakupionych, ball_type)
		ilosc_zakupionych+=1
		item_bought.append(item_name)
		for btn in buttons:
			if btn.text == item_name:
				btn.text = "Sold out"
		
		if success:
			print_debug("Kupiono:", item_name, "- zamieniono kulę w decku")
		else:
			print_debug("Błąd: nie udało się zamienić kuli")
			# Zwróć punkty jeśli się nie udało
			points += cost
			label.text = "Punkty: %d" % points
	else:
		print_debug("Za mało punktów na", item_name)

func _process(delta) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_shop()

func toggle_shop() -> void:
	shop_open = !shop_open
	continue_container.visible = shop_open
	buttons_container.visible = shop_open
	$QuitButton.visible = shop_open

	for shop_ball in shop_balls.get_children():
		shop_ball.visible = shop_open

	if shop_open:
		mouse_filter = Control.MOUSE_FILTER_STOP
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if not shop_positions_set:
			align_shop_items()
			shop_positions_set = true
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
		
		# Dodajemy lekkie bujnięcie jako osobną sekwencję wewnątrz
		# Uwaga: W Godot 4 łączenie parallel z sekwencjami jest tricky, 
		# więc zrobimy proste wychylenie w jedną stronę, które wygląda dynamicznie
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
		
		# 1. Skalowanie: Wydłużone do 2.0 sekund (było 0.8)
		# Zmieniłem TRANS_BOUNCE na TRANS_ELASTIC dla płynniejszego efektu przy długim czasie
		_score_tween.tween_property(scoredLabel, "scale", Vector2(2.5, 2.5), 2.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		# 2. Obrót: Również 2.0 sekundy.
		# Dzięki temu 720 stopni rozłoży się w czasie i będzie widać ruch.
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
