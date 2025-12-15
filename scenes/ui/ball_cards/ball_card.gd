extends PanelContainer

@onready var ball_icon: TextureRect = $VBoxContainer/BallIcon
@onready var ball_name: Label = $VBoxContainer/BallName

# Funkcja ustawiająca wygląd karty
func setup_card(name_text: String, color: Color) -> void:
	ball_name.text = name_text
	
	# Tworzymy kółko (tak jak wcześniej), chyba że masz już obrazki bil
	var texture = GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	var gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE) 
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.7, Color.WHITE)
	gradient.add_point(0.72, Color(1, 1, 1, 0)) 
	texture.gradient = gradient
	
	ball_icon.texture = texture
	ball_icon.modulate = color

# Funkcja wyszarzająca po wbiciu
func set_pocketed() -> void:
	modulate = Color(0.5, 0.5, 0.5, 0.4) # Przyciemnij całą kartę
	# Opcjonalnie: przekreśl tekst lub zmień ikonę
