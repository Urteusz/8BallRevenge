extends PanelContainer

@onready var label = $Label

func _ready():
	hide()
	add_to_group("tooltip_popup")

func _process(delta):
	if visible:
		global_position = get_global_mouse_position() + Vector2(15, 15)

func show_message(text_to_show: String):
	label.text = text_to_show
	show()
	reset_size() 

func hide_message():
	hide()
