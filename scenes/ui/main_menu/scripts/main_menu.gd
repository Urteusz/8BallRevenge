extends PanelContainer

@onready var play_button: TextureButton = %PlayButtonTextured
@onready var options_button: TextureButton = %OptionsButtonTextured
@onready var quit_button: TextureButton = %QuitButtonTextured

var focused = false

func _input(input) -> void:
	if !focused and \
		(input.is_action_pressed("ui_up") or input.is_action_pressed("ui_down") or \
		input.is_action_pressed("ui_left") or input.is_action_pressed("ui_right") or \
		input.is_action_pressed("ui_accept") or input.is_action_pressed("ui_cancel") or \
		input.is_action_pressed("pause")):
		play_button.grab_focus()
		focused = true
	elif input.is_action_pressed("ui_cancel"):
		Utils.drop_focus()
		focused = false

func _on_play_button_pressed() -> void:
	if play_button.disabled: return
	await get_tree().create_timer(0.15).timeout
	_lock_buttons()
	play_button.set_pressed_no_signal(true)
	LoadManager.load_scene(ScenePaths.LEVEL_SELECT_MAP)


# moze lepiej by bylo sobie darowac ten loading screen tutaj
func _on_options_button_pressed() -> void:
	_lock_buttons() 
	LoadManager.load_scene(ScenePaths.OPTIONS_MENU_PATH)


func _on_quit_button_pressed() -> void:
	_lock_buttons() 
	get_tree().quit()

func _lock_buttons() -> void:
	play_button.disabled = true
	options_button.disabled = true
	quit_button.disabled = true
