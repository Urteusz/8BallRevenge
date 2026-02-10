extends Control

@export var shop_card_scene: PackedScene
@export var items_to_sell: Array[String] = ["bomb", "speedy", "magnetic", "blue", "green"]

@onready var label_points = $LabelPoints
@onready var buttons_container = %ButtonsContainer 
@onready var continue_container = $ContinueContainer
@onready var next_button: Button = %ButtonNextLevel
@onready var choose_button: Button = %ButtonChoose
@onready var quit_button = $QuitButton
@onready var scored_label = $PointsScored


var shop_open := false
var points: int = 0
var default_score_y: float = 0.0
var generated_cards: Array = []

var _score_tween: Tween

func _ready() -> void:
	label_points.add_theme_color_override("font_color", Color.WHITE)
	
	if scored_label:
		default_score_y = scored_label.position.y
		scored_label.visible = false
		scored_label.modulate.a = 0.0
	
	buttons_container.visible = false
	continue_container.visible = false
	if quit_button: quit_button.visible = false
	
	if not next_button.pressed.is_connected(_on_next_level):
		next_button.pressed.connect(_on_next_level)
		
	if not choose_button.pressed.is_connected(_on_choose):
		choose_button.pressed.connect(_on_choose)
		
	if quit_button: 
		if not quit_button.pressed.is_connected(_on_quit_button_pressed):
			quit_button.pressed.connect(_on_quit_button_pressed)
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_generate_shop_cards()
	
	_update_points_display()

func _generate_shop_cards() -> void:
	for child in buttons_container.get_children():
		child.queue_free()
	generated_cards.clear()
	
	if not shop_card_scene:
		push_error("ShopUI: Nie przypisano sceny ShopCard w inspektorze!")
		return

	for ball_id in items_to_sell:
		if not PlayerData.ball_data_map.has(ball_id):
			push_warning("ShopUI: Nieznane ID kuli w PlayerData: " + ball_id)
			continue
			
		var data = PlayerData.ball_data_map[ball_id]
		
		var card = shop_card_scene.instantiate()
		buttons_container.add_child(card)
		generated_cards.append(card)
		
		var is_owned = PlayerData.owned_balls.has(ball_id)
		if card.has_method("setup_shop_item"):
			card.setup_shop_item(ball_id, data, is_owned, points)
		
		if card.has_signal("purchase_requested"):
			card.purchase_requested.connect(_on_card_purchase_requested)

func _on_card_purchase_requested(ball_id: String, cost: int) -> void:
	if points >= cost:
		if PlayerData.unlock_ball(ball_id):
			points -= cost
			_update_points_display()
			
			print("Kupiono: ", ball_id)
			
			_refresh_all_cards_state()
			
			for card in generated_cards:
				if card.ball_id == ball_id and card.has_method("play_success_anim"):
					card.play_success_anim()
		else:
			print("Błąd: Nie udało się odblokować kuli (już posiadana?)")
	else:
		print("Za mało punktów! Masz: ", points, " Potrzeba: ", cost)

func _refresh_all_cards_state() -> void:
	for card in generated_cards:
		if card.has_method("update_state"):
			var is_owned = PlayerData.owned_balls.has(card.ball_id)
			card.update_state(is_owned, points)

func _on_points_updated(new_points: int) -> void:
	var delta = new_points - points
	points = new_points
	_update_points_display()
	
	if delta > 0:
		show_score_popup(delta)
	
	if shop_open:
		_refresh_all_cards_state()

func _update_points_display() -> void:
	label_points.text = "Punkty: %d" % points

func toggle_shop() -> void:
	shop_open = !shop_open
	
	continue_container.visible = shop_open
	buttons_container.visible = shop_open
	if quit_button: quit_button.visible = shop_open
	
	if shop_open:
		mouse_filter = Control.MOUSE_FILTER_STOP
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		_refresh_all_cards_state()
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_shop()


func _on_next_level() -> void:
	toggle_shop()
	continue_container.visible = false
	LoadManager.load_scene(PlayerData.get_level_path())

func _on_choose() -> void:
	LoadManager.load_scene(ScenePaths.DECK_CHOOSE)

func _on_quit_button_pressed() -> void:
	LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)


func show_score_popup(amount: int) -> void:
	if not scored_label: return
	
	scored_label.text = "+%d" % amount
	scored_label.reset_size()
	scored_label.pivot_offset = scored_label.size / 2
	var center_x = (size.x / 2) - (scored_label.size.x / 2)
	scored_label.position = Vector2(center_x, default_score_y)
	
	scored_label.visible = true
	scored_label.modulate = Color.WHITE
	scored_label.rotation_degrees = 0
	scored_label.scale = Vector2(0, 0)
	
	if _score_tween:
		_score_tween.kill()
	
	_score_tween = create_tween()
	
	var wait_time = 0.5 
	
	if amount < 500:
		_score_tween.tween_property(scored_label, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		wait_time = 0.5
		
	elif amount >= 500 and amount < 3000:
		scored_label.modulate = Color(1, 0.84, 0)
		
		_score_tween.set_parallel(true)
		_score_tween.tween_property(scored_label, "scale", Vector2(1.5, 1.5), 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_score_tween.tween_property(scored_label, "rotation_degrees", 15, 0.2).set_ease(Tween.EASE_OUT)
		_score_tween.set_parallel(false)
		
		_score_tween.tween_property(scored_label, "rotation_degrees", 0, 0.2).set_trans(Tween.TRANS_BOUNCE)
		
		wait_time = 1.0

	else:
		scored_label.modulate = Color(1, 0.2, 0.4)
		
		wait_time = 2.0 
		
		_score_tween.set_parallel(true)
		_score_tween.tween_property(scored_label, "scale", Vector2(2.0, 2.0), 2.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_score_tween.tween_property(scored_label, "rotation_degrees", 720, 2.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_score_tween.set_parallel(false)

	_score_tween.tween_interval(wait_time)
	
	_score_tween.set_parallel(true)
	_score_tween.tween_property(scored_label, "modulate:a", 0.0, 0.8) 
	_score_tween.tween_property(scored_label, "position:y", scored_label.position.y - 80, 0.8) 
	
	_score_tween.set_parallel(false)
	_score_tween.tween_callback(scored_label.hide)
