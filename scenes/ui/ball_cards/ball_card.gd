extends PanelContainer

# Referencje do obiektów wewnątrz SubViewportu
@onready var ball_mesh: MeshInstance3D = $VBoxContainer/SubViewportContainer/SubViewport/Node3D/BallMesh
@onready var name_label: Label = $VBoxContainer/BallName
@onready var sub_viewport: SubViewport = $VBoxContainer/SubViewportContainer/SubViewport
@onready var points_label: Label = $VBoxContainer/PointsLabel
@onready var particles: CPUParticles2D = $VBoxContainer/PointsLabel/CPUParticles2D
# Prędkość obrotu
var rotation_speed: float = 1.0
var is_super_charged: bool = false

func _ready() -> void:
	# To sprawia, że każda karta jest niezależna (ważne przy wielu kartach)
	pivot_offset = size / 2
	if sub_viewport:
		sub_viewport.own_world_3d = true
	


func _process(delta: float) -> void:
	#Obracanie obiektu
	if ball_mesh and rotation_speed > 0:
		ball_mesh.rotation.y += rotation_speed * delta
	if is_super_charged:
		# Ciągłe wibracje (losowy obrót lewo-prawo)
		rotation_degrees = randf_range(-3.0, 3.0)
	else:
		# Płynny powrót do poziomu, gdy nie trzęsie
		rotation_degrees = lerp(rotation_degrees, 0.0, delta * 10)
		

# Funkcja konfiguracyjna (którą wywoła GameplayUI)
func setup_card(name_text: String, texture: Texture2D, ui_color: Color, points: int) -> void:
	name_label.text = name_text
	
	update_points(points)
	# Tworzymy materiał (StandardMaterial3D)
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.2
	mat.metallic = 0.0
	
	# Logika kolorów i tekstur (z Twojego BallData)
	if texture != null:
		# Jeśli jest tekstura (np. numer), używamy jej na białym tle
		mat.albedo_color = Color.WHITE
		mat.albedo_texture = texture
		
		# Kolor UI wykorzystujemy np. do koloru czcionki
		name_label.modulate = ui_color 
	else:
		# Jeśli nie ma tekstury, malujemy kulę na kolor UI
		mat.albedo_color = ui_color
	
	# Przypisujemy materiał do Mesha
	if ball_mesh:
		ball_mesh.mesh = SphereMesh.new()
		ball_mesh.mesh.radius = 0.05
		ball_mesh.mesh.height = 0.1
		ball_mesh.set_surface_override_material(0, mat)

# Funkcja "wyszarzania" po wbiciu
func set_pocketed() -> void:
	# Przyciemniamy cały panel
	modulate = Color(0.4, 0.4, 0.4, 0.5)
	# Zatrzymujemy obrót (opcjonalnie)
	rotation_speed = 0.0
	
func update_points(new_value: int) -> void:
	if not points_label: return
	
	points_label.text = "Pts: " + str(new_value)
	
	if particles:
		particles.restart() # Restart pozwala odpalić efekt raz za razem przy szybkich punktach
		particles.emitting = true
	
	# Uaktualnij środek obrotu na wszelki wypadek (gdyby karta zmieniła rozmiar)
	pivot_offset = size / 2 

	# EFEKT 1: Pulsowanie tekstu (To działało dobrze, zostawiamy)
	var tween = create_tween()
	tween.tween_property(points_label, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(points_label, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BOUNCE)

	# EFEKT 2: "High Score" - Wściekłe trzęsienie (ROTACJA zamiast POZYCJI)
	if new_value >= 1000:
		# POZIOM 3: SUPER MOC (Fioletowy + Ciągłe trzęsienie)
		is_super_charged = true
		points_label.modulate = Color(0.8, 0.2, 1.0) # Fiolet
		
	elif new_value > 500:
		# POZIOM 2: WYSOKI WYNIK (Czerwony + Pojedynczy wstrząs)
		is_super_charged = false
		points_label.modulate = Color(1, 0.2, 0.2) # Czerwony
		
		# Jednorazowy wstrząs (Tween)
		var shake = create_tween()
		shake.tween_property(self, "rotation_degrees", 5.0, 0.05)
		shake.tween_property(self, "rotation_degrees", -5.0, 0.05)
		shake.tween_property(self, "rotation_degrees", 0.0, 0.05)
		
	else:
		# POZIOM 1: NORMALNY (Złoty)
		is_super_charged = false
		points_label.modulate = Color(1, 0.84, 0) # Złoty
