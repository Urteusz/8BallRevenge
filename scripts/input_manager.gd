extends Node

signal input_device_changed(device_type: String)

var current_device: String = "keyboard" # or "gamepad"

var prompts_keyboard = {
	"aim": "Move mouse",
	"spin_y": "Mouse up/down",
	"spin_x": "A/D",
	"charge": "LMB",
	"cancel": "RMB",
	"change_view": "Tab",
	"nav_hint": "Arrow Keys - Navigate",
	"select_hint": "Click/Enter (Hold) - Select Level",
	"back_hint": "ESC - Back to Menu",
	"start_game": "Click Play",
	"swap": "Click / Enter",
	"buy": "Click / Enter",
	"nav_only": "Arrow Keys"
}

var prompts_gamepad = {
	"aim": "[img=40]res://textures/ui/pad_icon/xbox_stick_l.png[/img]",
	"spin_y": "[img=40]res://textures/ui/pad_icon/xbox_stick_l_vertical.png[/img]",
	"spin_x": "[img=40]res://textures/ui/pad_icon/xbox_stick_l_horizontal.png[/img]",
	"charge": "[img=40]res://textures/ui/pad_icon/xbox_button_a.png[/img]",
	"cancel": "[img=40]res://textures/ui/pad_icon/xbox_button_b.png[/img]",
	"change_view": "[img=40]res://textures/ui/pad_icon/xbox_dpad_right.png[/img]",
	"nav_hint": "[img=40]res://textures/ui/pad_icon/xbox_stick_l.png[/img] - Navigate",
	"select_hint": "[img=40]res://textures/ui/pad_icon/xbox_button_a.png[/img] - Select Level (Hold)",
	"back_hint": "[img=40]res://textures/ui/pad_icon/xbox_button_b.png[/img] - Back",
	"start_game": "Click - [img=40]res://textures/ui/pad_icon/xbox_button_start.png[/img]",
	"swap": "[img=40]res://textures/ui/pad_icon/xbox_button_a.png[/img]",
	"buy": "[img=40]res://textures/ui/pad_icon/xbox_button_a.png[/img]",
	"nav_only": "[img=40]res://textures/ui/pad_icon/xbox_stick_l.png[/img]"
}

func _ready() -> void:
	# Domyślnie sprawdzamy czy jakiś pad jest podłączony na start (opcjonalnie)
	if Input.get_connected_joypads().size() > 0:
		current_device = "gamepad"

func _input(event: InputEvent) -> void:
	var new_device = current_device
	
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		new_device = "keyboard"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and abs(event.axis_value) < 0.2:
			pass # Ignoruj minimalne drgnięcia gałek
		else:
			new_device = "gamepad"
			
	if new_device != current_device:
		current_device = new_device
		emit_signal("input_device_changed", current_device)

func parse_prompts(text: String) -> String:
	var dict = prompts_keyboard if current_device == "keyboard" else prompts_gamepad
	var parsed_text = text
	for key in dict.keys():
		parsed_text = parsed_text.replace("[act:" + key + "]", dict[key])
	return parsed_text
