extends PanelContainer

@onready var label = $Label # Upewnij się, że Label jest dzieckiem PanelContainer

func _ready():
	hide() # Ukryj na starcie
	add_to_group("tooltip_popup") # Dodajemy do grupy, żeby kulka nas znalazła

func _process(delta):
	if visible:
		# Ustaw pozycję dymka w miejscu myszki + małe przesunięcie (np. 15px)
		global_position = get_global_mouse_position() + Vector2(15, 15)

# Tę funkcję wywoła kulka
func show_message(text_to_show: String):
	label.text = text_to_show
	show() # Pokaż dymek
	# Opcjonalnie: ustaw rozmiar na minimalny przy zmianie tekstu
	reset_size() 

# Tę funkcję też wywoła kulka
func hide_message():
	hide()
