extends Control

@onready var moves_title_label: Label = $"MovesLeftHUD/MovesTitleLabel"
@onready var moves_count_label: Label = $"MovesLeftHUD/MovesCountLabel"
@onready var game_over_window: Control = $"GameOverWindow"
@onready var win_window: Control = $"WinWindow"
@onready var again_button: Button = $"GameOverWindow/AgainButton"
@onready var exit_button: Button = $"GameOverWindow/ExitButton"
@onready var win_label: Label = $"WinWindow/LabelWin"
@onready var shop_button: Button = $"WinWindow/GoToShop"
@onready var slider: HSlider = $"PowerSlider/HSlider"
@onready var hint_label: Label = $"HintLabel"
@onready var ball_list_container: Container = $"BallListContainer"
@onready var win_confetti: CPUParticles2D = $WinConfetti

@export var game_manager: Node3D
@export var shopUI: Control

const BALL_CARD_SCENE = preload("res://scenes/ui/ball_cards/BallCard.tscn")

var ball_cards: Dictionary = {}

func _ready() -> void:
	if game_manager:
		game_manager.gameplay_ui = self
	
	game_over_window.visible = false
	win_window.visible = false
	again_button.pressed.connect(_on_try_again)
	exit_button.pressed.connect(_on_main_menu)
	shop_button.pressed.connect(_on_shop_button)
	_show_hint("Przytrzymaj LPM, aby naciągnąć siłę")
	
	if game_manager:
		if not game_manager.is_connected("moves_changed", _on_moves_changed):
			game_manager.connect("moves_changed", _on_moves_changed)
		if not game_manager.is_connected("player_died", _on_game_over):
			game_manager.connect("player_died", _on_game_over)
		if not game_manager.is_connected("player_win", _on_game_win):
			game_manager.connect("player_win", _on_game_win)
		if not game_manager.is_connected("charging_started", _on_charging_started):
			game_manager.connect("charging_started", _on_charging_started)
		if not game_manager.is_connected("charging_updated", _on_charging_updated):
			game_manager.connect("charging_updated", _on_charging_updated)
		if not game_manager.is_connected("charging_released", _on_charging_released):
			game_manager.connect("charging_released", _on_charging_released)
		if not game_manager.is_connected("ball_pocketed", _on_ball_pocketed):
			game_manager.connect("ball_pocketed", _on_ball_pocketed)
		if not game_manager.is_connected("charging_paused",_on_charging_paused):
			game_manager.connect("charging_paused",_on_charging_paused)
		if game_manager.has_method("get_level_balls"):
			_initialize_ball_cards(game_manager.get_level_balls())
		
		_on_moves_changed(game_manager.default_level_move_count)
	_ignore_mouse()
	

func _on_charging_paused() -> void:
	slider.visible = false
	slider.value = 0.0
	_show_hint("Przytrzymaj LPM, aby naciągnąć siłę")
	

func _initialize_ball_cards(balls_data: Array) -> void:
	print("Inicjalizacja kart... Liczba kul: ", balls_data.size())
	
	if ball_list_container:
		for child in ball_list_container.get_children():
			child.queue_free()
	
	ball_cards.clear()
	
	if not ball_list_container:
		print("Błąd: Brak kontenera BallListContainer")
		return

	for data in balls_data:
		print("Tworzę kartę dla: ", data.get("name", "???"))
		var card = BALL_CARD_SCENE.instantiate()
		
		ball_list_container.add_child(card)
		
		if card.has_method("setup_card"):
			var ball_scene = data.get("scene", null)
			var ball_texture = data.get("texture", null)
			var ball_color = data.get("color", Color.WHITE)
			var ball_points = data.get("points", 0)
			var ball_name = data.get("name", "???")
			
			print("Scene: ", ball_scene)
			print("Texture: ", ball_texture)
			
			card.setup_card(ball_name, ball_texture, ball_color, ball_points, ball_scene)
		
		# Zapisujemy referencję
		ball_cards[data["id"]] = card
	
	print("Karty zainicjalizowane!")

func _on_ball_pocketed(ball_id: int) -> void:
	if ball_cards.has(ball_id):
		ball_cards[ball_id].set_pocketed()

func _on_moves_changed(value: int) -> void:
	if(value<=3):
		moves_count_label.add_theme_color_override("font_color",Color(0.663, 0.0, 0.082, 1.0))
	moves_count_label.text = "%d" % value
	moves_title_label.text = "Moves left"

func _on_game_over() -> void:
	game_over_window.visible = true
	moves_title_label.text = "You died"
	moves_count_label.text = ""
	_enable_mouse()
	
func _on_game_win() -> void:
	win_window.visible = true
	win_label.text = "Poziom ukończony! GratulacjÄ™!"
	_enable_mouse()
	if ball_list_container:
		ball_list_container.visible = false
	if win_confetti:
		win_confetti.restart()
		win_confetti.emitting = true

func _on_try_again() -> void:
	LoadManager.load_scene(PlayerData.get_level_path())

func _on_main_menu() -> void:
	LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)
	
func _on_shop_button() -> void:
	win_window.visible = false
	_ignore_mouse()
	shopUI.toggle_shop()

func _on_charging_started() -> void:
	slider.visible = true
	slider.value = 0.0
	_show_hint("Ruszaj myszą: Obrót\nQ i E: Wybierz punkt uderzenia\nPuść LPM: UDERZ!\nNaciśnij PPM: Anuluj\nA i D: Zmień widok")

func _on_charging_released() -> void:
	await get_tree().create_timer(0.1).timeout
	slider.visible = false
	slider.value = 0.0

func _on_charging_updated(charge_ratio: float) -> void:
	slider.value = charge_ratio
	_update_slider_color(charge_ratio)

func _update_slider_color(ratio: float) -> void:
	var color: Color
	if ratio < 0.5:
		var local_ratio = ratio * 2.0
		color = Color(0.0, 1.0, 0.0).lerp(Color(1.0, 1.0, 0.0), local_ratio)
	else:
		var local_ratio = (ratio - 0.5) * 2.0
		color = Color(1.0, 1.0, 0.0).lerp(Color(1.0, 0.0, 0.0), local_ratio)
		
	slider.modulate = color

func _ignore_mouse() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func _enable_mouse() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
func _on_ball_score_updated(new_points: int, ball_id: int) -> void:
	if ball_cards.has(ball_id):
		ball_cards[ball_id].update_points(new_points)
		
func _show_hint(text: String) -> void:
	if not hint_label: return
	
	hint_label.text = text
	
	# Mały efekt "pojawiania się" (Tween)
	if text != "":
		hint_label.modulate.a = 0.0 # Przezroczysty
		var tween = create_tween()
		tween.tween_property(hint_label, "modulate:a", 1.0, 0.3) # Fade In
		
		# Dodatkowy efekt pulsowania, żeby gracz zauważył
		var pulse = create_tween().set_loops()
		pulse.tween_property(hint_label, "scale", Vector2(1.05, 1.05), 0.5)
		pulse.tween_property(hint_label, "scale", Vector2(1.0, 1.0), 0.5)
	else:
		hint_label.text = ""
func _on_aiming_state_changed(is_aiming: bool) -> void:
	if is_aiming:
		# Kula się zatrzymała -> Pokaż instrukcję
		# Sprawdzamy czy nie ma Game Over, żeby nie wyświetlać napisu na ekranie przegranej
		if moves_count_label.text != "0" and !game_over_window.visible: 
			_show_hint("Przytrzymaj LPM, aby naciągnąć siłę")
	else:
		# Kula ruszyła -> Ukryj instrukcję
		_show_hint("")
