extends Line2D

@export var flow_speed: float = 2.0

var time_passed: float = 0.0

func _ready() -> void:
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.3, 0.6, 0.9, 0.3))
	gradient.add_point(0.25, Color(0.5, 0.8, 1.0, 0.7))
	gradient.add_point(0.5, Color(0.7, 0.9, 1.0, 1.0))
	gradient.add_point(0.75, Color(0.5, 0.8, 1.0, 0.7))
	gradient.add_point(1.0, Color(0.3, 0.6, 0.9, 0.3))

	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 256

	texture = gradient_texture
	texture_mode = Line2D.LINE_TEXTURE_TILE

	# ===== ZMIANA: shader zamiast texture_offset =====
	var shader = Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform float offset;

		void fragment() {
			vec2 uv = UV;
			uv.x += offset;
			COLOR = texture(TEXTURE, uv) * COLOR;
		}
	"""

	var mat = ShaderMaterial.new()
	mat.shader = shader
	material = mat

func _process(delta: float) -> void:
	time_passed += delta
	
	if material:
		material.set_shader_parameter("offset", time_passed * flow_speed)
