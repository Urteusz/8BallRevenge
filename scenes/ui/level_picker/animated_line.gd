extends Line2D

func _ready() -> void:
	# Ustawienia podstawowe linii
	width = 30.0
	default_color = Color.WHITE
	texture_mode = Line2D.LINE_TEXTURE_STRETCH
	
	# Tworzymy prosty shader w kodzie
	var shader = Shader.new()
	shader.code = """
		shader_type canvas_item;

		void fragment() {
			// Obliczamy odległość od środka szerokości linii
			// UV.y = 0.5 to środek, 0.0 i 1.0 to krawędzie
			float dist = abs(UV.y - 0.5) * 2.0;
			
			// Odwracamy: 1.0 w środku, 0.0 na krawędziach
			float glow = 1.0 - dist;
			
			// Zwiększamy kontrast (im wyższa liczba, tym cieńszy 'rdzeń' lasera)
			glow = pow(glow, 3.0);
			
			// Kolory
			vec3 core_color = vec3(1.0, 1.0, 1.0); // Biały środek
			vec3 beam_color = vec3(0.0, 0.5, 1.0); // Niebieska poświata
			
			// Mieszamy kolory w oparciu o jasność
			vec3 final_color = mix(beam_color, core_color, glow);
			
			COLOR.rgb = final_color;
			// Alfa (przezroczystość) zanika na krawędziach
			COLOR.a = glow; 
		}
	"""

	var mat = ShaderMaterial.new()
	mat.shader = shader
	material = mat
