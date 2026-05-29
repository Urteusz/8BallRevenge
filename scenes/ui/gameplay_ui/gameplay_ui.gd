extends Control

@onready var moves_title_label: Label = $"MovesLeftHUD/MovesTitleLabel"
@onready var moves_count_label: Label = $"MovesLeftHUD/MovesCountLabel"
@onready var game_over_window: Control = $"GameOverWindow"
@onready var win_window: Control = $"WinWindow"
@onready var again_button: TextureButton = $"GameOverWindow/AgainButton"
@onready var exit_button: TextureButton = $"GameOverWindow/ExitButton"
@onready var win_label: Label = $"WinWindow/VBox/LabelWin"
@onready var shop_button: TextureButton = $"WinWindow/VBox/WinButtons/GoToShop"
@onready var win_try_again_button: TextureButton = $"WinWindow/VBox/WinButtons/TryAgainButton"

@onready var hint_label: Label = $"HintLabel"
@onready var ball_list_container: Container = $"BallListContainer"
@onready var win_confetti: CPUParticles2D = $WinConfetti

@export var game_manager: Node3D
@export var shopUI: Control

const BALL_CARD_SCENE = preload("res://scenes/ui/ball_cards/Better_Card.tscn")

var ball_cards: Dictionary = {}
var played_level_number: int = 0

func _ready() -> void:
	# Zapisz numer poziomu na którym zaczynamy grać
	played_level_number = PlayerData.current_level

	if game_manager:
		game_manager.gameplay_ui = self
	
	game_over_window.visible = false
	win_window.visible = false
	again_button.pressed.connect(_on_try_again)
	exit_button.pressed.connect(_on_change_level)
	shop_button.pressed.connect(_on_shop_button)
	win_try_again_button.pressed.connect(_on_try_again)
	_show_hint("Hold LMB to charge\nTab: Change view")
	
	if game_manager:
		if not game_manager.is_connected("moves_changed", _on_moves_changed):
			game_manager.connect("moves_changed", _on_moves_changed)
		if not game_manager.is_connected("player_died", _on_game_over):
			game_manager.connect("player_died", _on_game_over)
		if not game_manager.is_connected("player_win", _on_game_win_simple):
			game_manager.connect("player_win", _on_game_win_simple)
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
		if not game_manager.is_connected("player_win_with_score",_on_game_win):
			game_manager.connect("player_win_with_score",_on_game_win)
		if game_manager.has_method("get_level_balls"):
			_initialize_ball_cards(game_manager.get_level_balls())
		
		_on_moves_changed(game_manager.default_level_move_count)
	_ignore_mouse()
	

func _on_charging_paused() -> void:
	_show_hint("Hold LMB to charge\nTab: Change view")
	

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
	
func _on_game_win_simple() -> void:
	pass

func _on_game_win(score: int, threshold: int) -> void:
	win_window.visible = true
	win_label.text = "Level Complete!"
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enable_mouse()
	if ball_list_container:
		ball_list_container.visible = false
	if win_confetti:
		win_confetti.restart()
		win_confetti.emitting = true

	var star_count = 0
	if threshold > 0:
		var ratio = float(score) / float(threshold)
		if ratio >= 1.0:
			star_count = 3
		elif ratio >= 0.66:
			star_count = 2
		elif ratio >= 0.33:
			star_count = 1

	PlayerData.save_level_stars(played_level_number, star_count)

	# Teraz możemy przejść do następnego poziomu
	PlayerData.advance_level()

	# Label z wynikiem
	var score_label = Label.new()
	score_label.text = str(score) + " / " + str(threshold) + " pts"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_override("font", win_label.get_theme_font("font"))
	score_label.add_theme_font_size_override("font_size", 26)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
	score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	score_label.add_theme_constant_override("outline_size", 3)

	# Kontener gwiazdek
	var star_texture = preload("res://textures/star_texture.png")
	var stars_container = HBoxContainer.new()
	stars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_container.add_theme_constant_override("separation", 0)

	for i in 3:
		var star = TextureRect.new()
		star.texture = star_texture
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.custom_minimum_size = Vector2(70, 70)
		star.pivot_offset = Vector2(35, 35)
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if i < star_count:
			star.modulate = Color(1.0, 0.95, 0.4, 1.0)
		else:
			star.modulate = Color(0.2, 0.2, 0.2, 0.35)
		star.scale = Vector2.ZERO
		stars_container.add_child(star)

	# Separator przed przyciskiem
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)

	# Wstaw elementy do VBox: LabelWin (0) -> score (1) -> stars (2) -> spacer (3) -> GoToShop (4)
	var vbox = win_window.get_node("VBox")
	vbox.add_child(score_label)
	vbox.move_child(score_label, 1)
	vbox.add_child(stars_container)
	vbox.move_child(stars_container, 2)
	vbox.add_child(spacer)
	vbox.move_child(spacer, 3)

	# Animacja gwiazdek - pojawiają się po kolei z efektem bounce
	for i in 3:
		var star = stars_container.get_child(i)
		var delay = 0.3 + i * 0.25
		var tween = create_tween()
		tween.tween_interval(delay)
		if i < star_count:
			tween.tween_property(star, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tween.tween_property(star, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN_OUT)
		else:
			# Szara gwiazdka
			tween.tween_property(star, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
func _on_try_again() -> void:
	# Wróć do poziomu na którym graliśmy (played_level_number został zapisany w _ready)
	PlayerData.set_level(played_level_number)
	LoadManager.load_scene(PlayerData.get_level_path())

func _on_change_level() -> void:
	LoadManager.load_scene(ScenePaths.LEVEL_SELECT_MAP)
	
func _on_shop_button() -> void:
	win_window.visible = false
	_ignore_mouse()
	shopUI.toggle_shop()

var is_charging: bool = false

func _on_charging_started() -> void:
	is_charging = true
	_show_hint("Move mouse: Aim\nW/S: Topspin / Backspin\nA/D: Sidespin\nRelease LMB: SHOOT!\nPress RMB: Cancel\nTab: Change view")

func _on_charging_released() -> void:
	is_charging = false
	_show_hint("Tab: Change view")

func _on_charging_updated(_charge_ratio: float) -> void:
	pass

func _ignore_mouse() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func _enable_mouse() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_disable_camera_input()
	
func _disable_camera_input() -> void:
	if !game_manager:
		return
	var camera = game_manager.get_viewport().get_camera_3d()
	if camera and "input_enabled" in camera:
		camera.input_enabled = false

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
			_show_hint("Hold LMB to charge\nTab: Change view")
	else:
		# Kula ruszyła -> Ukryj instrukcję (ale zostaw Tab)
		# Chyba że ładujemy strzał - wtedy zostawiamy instrukcję ładowania
		if !is_charging:
			_show_hint("Tab: Change view")
