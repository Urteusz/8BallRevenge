extends PanelContainer

# przyciski powinny sie blokowac po wcisnieciu
#	zeby nie dalo sie wcisnac play -> i szybko wcisnac opcje

func _on_play_button_pressed() -> void:
	LoadManager.load_scene(PlayerData.get_level_path())


# moze lepiej by bylo sobie darowac ten loading screen tutaj
func _on_options_button_pressed() -> void:
	LoadManager.load_scene(ScenePaths.OPTIONS_MENU_PATH)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
