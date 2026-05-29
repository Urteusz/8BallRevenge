extends CanvasLayer

@export var shop_ui: Control # Reference to ShopUI Control

var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

@onready var resume_button: Button = %ResumeButton
@onready var change_level_button: Button = %ChangeLevelButton
@onready var options_button: Button = %OptionsButton
@onready var main_menu_button: Button = %MainMenuButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # Always process to catch unpause
	_setup_focus_nav()

# Nawigacja padem/klawiatura: gora/dol po liscie z zawijaniem.
func _setup_focus_nav() -> void:
	var btns := [resume_button, change_level_button, options_button, main_menu_button]
	var n := btns.size()
	for i in range(n):
		var b: Control = btns[i]
		if not b:
			continue
		b.focus_mode = Control.FOCUS_ALL
		var up: Control = btns[(i - 1 + n) % n]
		var down: Control = btns[(i + 1) % n]
		b.focus_neighbor_top = b.get_path_to(up)
		b.focus_neighbor_bottom = b.get_path_to(down)
		b.focus_previous = b.get_path_to(up)
		b.focus_next = b.get_path_to(down)

func _input(event: InputEvent) -> void:
	# Wejscie/wyjscie: Esc lub Start na padzie (akcja pause).
	if event.is_action_pressed("pause"):
		if shop_ui and shop_ui.shop_open:
			shop_ui.toggle_shop()
			return

		_toggle_pause()
	# Zamkniecie otwartego menu przyciskiem B na padzie (ui_cancel).
	elif visible and event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _toggle_pause() -> void:
	visible = !visible
	get_tree().paused = visible

	if visible:
		previous_mouse_mode = Input.mouse_mode
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# Ustaw focus na pierwszej pozycji, zeby gora/dol dzialalo od razu padem.
		if resume_button:
			resume_button.grab_focus.call_deferred()
	else:
		Input.set_mouse_mode(previous_mouse_mode)

func _on_resume_button_pressed() -> void:
	_toggle_pause()

func _on_change_level_button_pressed() -> void:
	get_tree().paused = false
	LoadManager.load_scene(ScenePaths.LEVEL_SELECT_MAP)

func _on_options_button_pressed() -> void:
	# Keep paused? Options menu usually replaces current view.
	# If Options is a separate scene that doesn't use SceneTree.paused, we might need to unpause.
	# Existing code unpaused. Let's keep it consistent.
	get_tree().paused = false
	LoadManager.load_scene(ScenePaths.OPTIONS_MENU_PATH)

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)
