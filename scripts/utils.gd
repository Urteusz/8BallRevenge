extends Node

# Lepiej zmienic na inna nazwe jesli bedzie tu wiecej funkcji

func drop_focus() -> void:
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()
