extends Node3D

@onready var inner_sphere: MeshInstance3D = $Sphere
@onready var outer_sphere: MeshInstance3D = $Sphere_002

@export_group("Star Settings")
@export var level_number: int = 1
@export var collected_color: Color = Color(1.0, 0.617, 0.0, 1.0)
@export var uncollected_color: Color = Color(0.3, 0.3, 0.3, 0.294)
@export var star_spacing: float = 0.5
@export var star_x_offset: float = 1.4
@export var star_scale: Vector3 = Vector3(0.15, 0.15, 0.15)
@export var fade_speed: float = 5.0

@export_group("Physics")
@export var drag_sensitivity: float = 0.005
@export var pad_sensitivity: float = 15.0
@export var outer_damping: float = 10.0
@export var inner_damping: float = 2.0
@export var min_inner_speed: float = 0.2
@export var inertia_transfer: float = 5.0

var star_model_path: String = "res://models/star2.obj"

var is_dragging: bool = false
var current_velocity: Vector2 = Vector2.ZERO
var inner_velocity: Vector2 = Vector2(min_inner_speed, 0.0)
var outer_velocity: Vector2 = Vector2.ZERO

var collected_mat: StandardMaterial3D
var uncollected_mat: StandardMaterial3D
var current_alpha: float = 0.0
var is_currently_focused: bool = false

func _ready() -> void:
	var parsed_lvl = name.trim_prefix("Level").to_int()
	if parsed_lvl > 0:
		level_number = parsed_lvl
		
	var stars_earned = PlayerData.get_level_stars(level_number)
	
	var star_mesh: Mesh = null
	if star_model_path != "":
		var loaded_res = load(star_model_path)
		if loaded_res is Mesh:
			star_mesh = loaded_res
			
	collected_mat = StandardMaterial3D.new()
	collected_mat.albedo_color = collected_color
	collected_mat.albedo_color.a = 0.0
	collected_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	collected_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	collected_mat.metallic = 1.0
	collected_mat.roughness = 0.1
	collected_mat.metallic_specular = 1.0
	
	uncollected_mat = StandardMaterial3D.new()
	uncollected_mat.albedo_color = uncollected_color
	uncollected_mat.albedo_color.a = 0.0
	uncollected_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	uncollected_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	uncollected_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	for i in range(3):
		var star = MeshInstance3D.new()
		if star_mesh:
			star.mesh = star_mesh
		star.scale = star_scale
		
		if i < stars_earned:
			star.material_override = collected_mat
		else:
			star.material_override = uncollected_mat
			
		inner_sphere.add_child(star)
		
		var y_pos = (1 - i) * star_spacing
		star.position = Vector3(star_x_offset, y_pos, 0)
		star.rotation = Vector3(deg_to_rad(-90), 0.0, 0.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			if _is_hovering(event.position):
				is_dragging = true
		else:
			is_dragging = false
			
	if event is InputEventMouseMotion and is_dragging:
		current_velocity += event.relative

func _process(delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var target_alpha = 0.0
	if _is_hovering(mouse_pos) or (is_currently_focused and Input.get_vector("ui_look_left", "ui_look_right", "ui_look_up", "ui_look_down").length() > 0.1):
		target_alpha = 1.0
	elif is_currently_focused:
		target_alpha = 1.0
		
	if current_alpha != target_alpha:
		current_alpha = move_toward(current_alpha, target_alpha, delta * fade_speed)
		
		if collected_mat:
			var col = collected_color
			col.a = col.a * current_alpha
			collected_mat.albedo_color = col
			
		if uncollected_mat:
			var uncol = uncollected_color
			uncol.a = uncol.a * current_alpha
			uncollected_mat.albedo_color = uncol

	var pad_vector = Input.get_vector("ui_look_left", "ui_look_right", "ui_look_up", "ui_look_down")
	
	if is_currently_focused and pad_vector.length() > 0.1:
		is_dragging = false
		var pad_vel = pad_vector * pad_sensitivity
		outer_velocity = pad_vel
		inner_velocity = inner_velocity.lerp(pad_vel, inertia_transfer * delta)
	elif is_dragging:
		if delta > 0.0:
			var drag_vel = (current_velocity * drag_sensitivity) / delta
			outer_velocity = drag_vel
			if current_velocity != Vector2.ZERO:
				inner_velocity = inner_velocity.lerp(drag_vel, inertia_transfer * delta)
		current_velocity = Vector2.ZERO
	else:
		outer_velocity = outer_velocity.move_toward(Vector2.ZERO, outer_damping * delta)
		
	if not is_dragging and (not is_currently_focused or pad_vector.length() <= 0.1):
		inner_velocity = inner_velocity.move_toward(Vector2.ZERO, inner_damping * delta)
	
	if inner_velocity.length() < min_inner_speed:
		if inner_velocity.is_zero_approx():
			inner_velocity = Vector2(min_inner_speed, 0.0)
		else:
			inner_velocity = inner_velocity.normalized() * min_inner_speed

	var camera = get_viewport().get_camera_3d()
	if camera:
		var cam_right = camera.global_transform.basis.x.normalized()
		var cam_up = camera.global_transform.basis.y.normalized()
		
		inner_sphere.global_rotate(cam_up, inner_velocity.x * delta)
		inner_sphere.global_rotate(cam_right, inner_velocity.y * delta)
		
		outer_sphere.global_rotate(cam_up, outer_velocity.x * delta)
		outer_sphere.global_rotate(cam_right, outer_velocity.y * delta)

func _is_hovering(mouse_pos: Vector2) -> bool:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return false
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	var center = outer_sphere.global_position
	var radius = 1.0
	if outer_sphere.mesh:
		radius = outer_sphere.mesh.get_aabb().size.length() * 0.5 * outer_sphere.scale.x
		
	var l = center - ray_origin
	var tca = l.dot(ray_dir)
	if tca < 0.0:
		return false
		
	var d2 = l.dot(l) - tca * tca
	return d2 <= radius * radius
