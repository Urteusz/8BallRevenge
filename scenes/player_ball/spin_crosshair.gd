extends MeshInstance3D
## Spin crosshair — a torus ring on the ball surface using external overlay shader.

const CROSSHAIR_RADIUS: float = 0.1
const CROSSHAIR_RING_RADIUS: float = 0.015
const CROSSHAIR_COLOR := Color(1.0, 1.0, 1.0, 0.85)

var overlay_shader: Shader = preload("res://shaders/overlay.gdshader")

func _ready() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = CROSSHAIR_RADIUS - CROSSHAIR_RING_RADIUS
	torus.outer_radius = CROSSHAIR_RADIUS + CROSSHAIR_RING_RADIUS
	torus.rings = 24
	torus.ring_segments = 8
	mesh = torus

	var mat := ShaderMaterial.new()
	mat.shader = overlay_shader
	mat.set_shader_parameter("color", CROSSHAIR_COLOR)
	mat.render_priority = 15
	material_override = mat
