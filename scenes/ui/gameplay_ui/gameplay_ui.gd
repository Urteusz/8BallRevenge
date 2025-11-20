extends Control

@onready var moves_title_label: Label = $"MovesLeftHUD/MovesTitleLabel"
@onready var moves_count_label: Label = $"MovesLeftHUD/MovesCountLabel"
@onready var game_over_window: Control = $"GameOverWindow"
@onready var win_window: Control = $"WinWindow"
@onready var again_button: Button = $"GameOverWindow/AgainButton"
@onready var exit_button: Button = $"GameOverWindow/ExitButton"
@onready var win_label: Label = $"WinWindow/LabelWin"
@onready var shop_button: Button = $"WinWindow/GoToShop"

@export var game_manager: Node3D
@export var shopUI: Control

func _ready() -> void:
	game_over_window.visible = false
	win_window.visible = false
	again_button.pressed.connect(_on_try_again)
	exit_button.pressed.connect(_on_main_menu)
	shop_button.pressed.connect(_on_shop_button)
	if game_manager:
		game_manager.connect("moves_changed", _on_moves_changed)
		game_manager.connect("player_died", _on_game_over)
		game_manager.connect("player_win", _on_game_win)
		_on_moves_changed(game_manager.default_level_move_count)
	_ignore_mouse()

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
	win_label.text = "Gratuluję ukończyłeś poziom"
	_enable_mouse()

func _on_try_again() -> void:
	LoadManager.load_scene(ScenePaths.LEVEL1_PATH)

func _on_main_menu() -> void:
	LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)
	
func _on_shop_button() -> void:
	win_window.visible = false
	_ignore_mouse()
	shopUI.toggle_shop()

func _ignore_mouse() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func _enable_mouse() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
