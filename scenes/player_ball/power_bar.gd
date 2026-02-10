extends Node3D
## Power bar scene — builds all meshes at _ready using external shaders.

const POWER_BAR_HEIGHT: float = 1.5
const POWER_BAR_WIDTH: float = 0.18
const POWER_BAR_DEPTH: float = 0.02
const MARKER_WIDTH: float = 0.28
const MARKER_HEIGHT: float = 0.045
const FRAME_THICKNESS: float = 0.035
const TICK_COUNT: int = 4
const TICK_HEIGHT: float = 0.012
const TICK_OUTLINE: float = 0.006

var overlay_shader: Shader = preload("res://shaders/overlay.gdshader")
var gradient_shader: Shader = preload("res://shaders/power_bar_gradient.gdshader")

var bar_bg: MeshInstance3D = null
var marker: MeshInstance3D = null
var marker_material: ShaderMaterial = null

func _ready() -> void:
	var half_w := POWER_BAR_WIDTH / 2.0
	var half_h := POWER_BAR_HEIGHT / 2.0
	var frame_col := Color(0.05, 0.05, 0.08, 0.96)

	# --- Frame (4 sides) ---
	_add_frame_side(Vector3(FRAME_THICKNESS, POWER_BAR_HEIGHT + FRAME_THICKNESS * 2.0, POWER_BAR_DEPTH),
		Vector3(-(half_w + FRAME_THICKNESS / 2.0), 0.0, 0.0), frame_col)
	_add_frame_side(Vector3(FRAME_THICKNESS, POWER_BAR_HEIGHT + FRAME_THICKNESS * 2.0, POWER_BAR_DEPTH),
		Vector3(half_w + FRAME_THICKNESS / 2.0, 0.0, 0.0), frame_col)
	_add_frame_side(Vector3(POWER_BAR_WIDTH, FRAME_THICKNESS, POWER_BAR_DEPTH),
		Vector3(0.0, half_h + FRAME_THICKNESS / 2.0, 0.0), frame_col)
	_add_frame_side(Vector3(POWER_BAR_WIDTH, FRAME_THICKNESS, POWER_BAR_DEPTH),
		Vector3(0.0, -(half_h + FRAME_THICKNESS / 2.0), 0.0), frame_col)

	# --- Gradient bar ---
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(POWER_BAR_WIDTH, POWER_BAR_HEIGHT, POWER_BAR_DEPTH)

	var bar_mat := ShaderMaterial.new()
	bar_mat.shader = gradient_shader
	bar_mat.render_priority = 11

	bar_bg = MeshInstance3D.new()
	bar_bg.name = "PowerBarBG"
	bar_bg.mesh = bar_mesh
	bar_bg.material_override = bar_mat
	bar_bg.position = Vector3.ZERO
	add_child(bar_bg)

	# --- Tick marks ---
	for i in range(TICK_COUNT):
		var frac := float(i + 1) / float(TICK_COUNT + 1)
		var tick_y := -half_h + frac * POWER_BAR_HEIGHT

		# Outline behind tick
		_add_box(Vector3(POWER_BAR_WIDTH + 0.01, TICK_HEIGHT + TICK_OUTLINE * 2.0, POWER_BAR_DEPTH),
			Vector3(0.0, tick_y, 0.0), Color(0.0, 0.0, 0.0, 0.85), 12)

		# Tick line
		_add_box(Vector3(POWER_BAR_WIDTH, TICK_HEIGHT, POWER_BAR_DEPTH),
			Vector3(0.0, tick_y, 0.0), Color(0.0, 0.0, 0.0, 0.9), 12)

	# --- Marker ---
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(MARKER_WIDTH, MARKER_HEIGHT, POWER_BAR_DEPTH)

	marker_material = _make_overlay_mat(Color(1.0, 1.0, 1.0, 0.95), 13)

	marker = MeshInstance3D.new()
	marker.name = "PowerBarMarker"
	marker.mesh = marker_mesh
	marker.material_override = marker_material
	marker.position = Vector3(0.0, -POWER_BAR_HEIGHT / 2.0, 0.0)
	add_child(marker)


func _add_frame_side(size: Vector3, pos: Vector3, col: Color) -> void:
	_add_box(size, pos, col, 10)


func _add_box(size: Vector3, pos: Vector3, col: Color, priority: int) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _make_overlay_mat(col, priority)
	inst.position = pos
	add_child(inst)


func _make_overlay_mat(color: Color, priority: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = overlay_shader
	mat.set_shader_parameter("color", color)
	mat.render_priority = priority
	return mat
