extends PanelContainer

# Referencje do obiektów wewnątrz SubViewportu
@onready var ball_mesh: MeshInstance3D = $VBoxContainer/SubViewportContainer/SubViewport/Node3D/BallMesh
@onready var name_label: Label = $VBoxContainer/BallName
@onready var sub_viewport: SubViewport = $VBoxContainer/SubViewportContainer/SubViewport

# Prędkość obrotu
var rotation_speed: float = 1.0

func _ready() -> void:
	# To sprawia, że każda karta jest niezależna (ważne przy wielu kartach)
	if sub_viewport:
		sub_viewport.own_world_3d = true

func _process(delta: float) -> void:
	#Obracanie obiektu
	if ball_mesh and rotation_speed > 0:
		ball_mesh.rotation.y += rotation_speed * delta
		

# Funkcja konfiguracyjna (którą wywoła GameplayUI)
func setup_card(name_text: String, texture: Texture2D, ui_color: Color) -> void:
	name_label.text = name_text
	
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
