extends Line2D

@export var flow_speed: float = 2.0
@export var beam_width: float = 2.5

var time_passed: float = 0.0

func _ready() -> void:
	z_index = 0
	width = 30.0
	default_color = Color.WHITE
	
	texture_mode = Line2D.LINE_TEXTURE_TILE
	
	var gradient = Gradient.new()
	
	# 1. Remove the default Black point (index 0)
	gradient.remove_point(0)
	
	# 2. Recycle the remaining default White point to be your first custom point
	# We set its offset and color instead of removing it
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(0.0, 0.1, 0.6, 0.2))
	
	# 3. Add the rest of the points normally
	gradient.add_point(0.2, Color(0.0, 0.4, 1.0, 0.8))
	gradient.add_point(0.45, Color(0.0, 0.9, 1.0, 1.0))
	gradient.add_point(0.5, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.55, Color(0.0, 0.9, 1.0, 1.0))
	gradient.add_point(0.8, Color(0.0, 0.4, 1.0, 0.8))
	gradient.add_point(1.0, Color(0.0, 0.1, 0.6, 0.2))

	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 256
	texture = gradient_texture

	var shader = Shader.new()
	shader.code = """
		shader_type canvas_item;
		
		uniform float offset;
		uniform float beam_sharpness;

		void fragment() {
			vec2 uv = UV;
			uv.x += offset;
			
			vec4 tex_color = texture(TEXTURE, uv);
			
			float dist_from_center = abs(UV.y - 0.5);
			float glow = 1.0 - (dist_from_center * 2.0);
			glow = clamp(glow, 0.0, 1.0);
			glow = pow(glow, beam_sharpness);
			
			vec3 final_color = tex_color.rgb + (vec3(1.0) * glow * 0.5);
			
			COLOR.rgb = final_color;
			COLOR.a = max(tex_color.a, glow); 
		}
	"""

	var mat = ShaderMaterial.new()
	mat.shader = shader
	material = mat

func _process(delta: float) -> void:
	time_passed += delta
	
	if material:
		material.set_shader_parameter("offset", -time_passed * flow_speed)
		material.set_shader_parameter("beam_sharpness", beam_width)
