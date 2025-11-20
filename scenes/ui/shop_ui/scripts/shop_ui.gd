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
var ilosc_zakupionych = 0

var item_bought = []
var buttons = []

func _ready() -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
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
	points = new_points
	label.text = "Punkty: %d" % points

func _on_item_pressed(item_name: String) -> void:
	match item_name:
		"Kulka Czerwona": _buy_item(item_name, 1000, "red")
		"Kulka Zielona": _buy_item(item_name, 2000, "green")
		"Kulka Niebieska": _buy_item(item_name, 3000, "blue")
		"Kulka Szybka": _buy_item(item_name, 4000, "speedy")
		"Kulka Bomba": _buy_item(item_name, 5000, "bomb")

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
	if Input.is_action_just_pressed("ui_cancel"):
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
