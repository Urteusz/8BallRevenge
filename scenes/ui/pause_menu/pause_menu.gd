extends CanvasLayer

@export var shop_ui: Control # Reference to ShopUI Control

var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # Always process to catch unpause

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if shop_ui and shop_ui.shop_open:
			shop_ui.toggle_shop()
			return
			
		_toggle_pause()

func _toggle_pause() -> void:
	visible = !visible
	get_tree().paused = visible
	
	if visible:
		previous_mouse_mode = Input.mouse_mode
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
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
