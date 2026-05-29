extends VBoxContainer

signal clicked(ball_data)

var my_ball_data: BallData
@onready var pivot: Node3D = $SubViewportContainer/SubViewport/Pivot
@onready var ball_name_label: Label = $BallNameLabel

# Tooltip variables
var tooltip_popup: PanelContainer = null
var tooltip_layer: CanvasLayer = null # Store the layer reference

func setup(ball_data: BallData) -> void:
	my_ball_data = ball_data
	
	if ball_data.scene:
		var ball_instance = ball_data.scene.instantiate()
		pivot.add_child(ball_instance)
		ball_instance.position = Vector3.ZERO
		
		if ball_data.texture:
			var mesh = ball_instance.get_node_or_null("MeshInstance3D")
			if mesh:
				var new_mat = StandardMaterial3D.new()
				new_mat.albedo_texture = ball_data.texture
				mesh.material_override = new_mat
		
		if ball_instance is RigidBody3D:
			ball_instance.freeze = true
	
	if ball_name_label:
		var name_text = ball_data.display_name
		if name_text == null or name_text == "":
			name_text = _derive_name_from_resource(ball_data)
		ball_name_label.text = name_text
		ball_name_label.add_theme_font_size_override("font_size", 22)

func _derive_name_from_resource(ball_data: BallData) -> String:
	var path = ball_data.resource_path
	if path == "": return "???"
	var filename = path.get_file().get_basename()
	var parts = filename.split("_")
	var result = []
	for part in parts:
		if part.length() > 0:
			result.append(part.capitalize())
	return " ".join(result)

@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport

# Drag state
var is_dragging: bool = false
var drag_preview: Control = null
var drag_start_pos: Vector2 = Vector2.ZERO

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_pos = event.global_position
			elif is_dragging:
				_end_drag(event.global_position)
	
	elif event is InputEventMouseMotion:
		if is_dragging:
			if not drag_preview:
				if event.global_position.distance_to(drag_start_pos) > 5.0:
					_start_drag_visual()
			
			if drag_preview:
				drag_preview.global_position = event.global_position - (drag_preview.size / 2.0)

func _start_drag_visual() -> void:
	if tooltip_popup:
		tooltip_popup.visible = false
	
	drag_preview = TextureRect.new()
	drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview.custom_minimum_size = Vector2(80, 80)
	drag_preview.size = Vector2(80, 80)
	
	var img = sub_viewport.get_texture().get_image()
	if img:
		var tex = ImageTexture.create_from_image(img)
		drag_preview.texture = tex
	elif my_ball_data.texture:
		drag_preview.texture = my_ball_data.texture
	
	var canvas = get_tree().root
	canvas.add_child(drag_preview)
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.modulate = Color(1, 1, 1, 0.8)
	drag_preview.z_index = 200

func _end_drag(release_pos: Vector2) -> void:
	is_dragging = false
	
	if drag_preview:
		var deck_choose = find_parent("DeckChoose")
		if not deck_choose:
			var root = get_tree().current_scene
			if root.name == "DeckChoose":
				deck_choose = root
		
		var success = false
		if deck_choose and deck_choose.has_method("receive_inventory_drop"):
			success = deck_choose.receive_inventory_drop(my_ball_data, release_pos)
		
		drag_preview.queue_free()
		drag_preview = null

func _ready() -> void:
	custom_minimum_size = Vector2(100, 130) 
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	_create_tooltip()

func _create_tooltip() -> void:
	# 1. Create the Layer ONCE and keep a reference
	tooltip_layer = CanvasLayer.new()
	tooltip_layer.layer = 100
	tooltip_layer.name = "TooltipLayer"
	# odroczone, bo przy tworzeniu inwentarza root jest w trakcie budowy drzewa
	get_tree().root.add_child.call_deferred(tooltip_layer)
	
	# 2. Create the Popup
	tooltip_popup = PanelContainer.new()
	tooltip_popup.visible = false
	tooltip_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.92)
	style.border_color = Color(0.5, 0.5, 0.6, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10.0
	style.content_margin_top = 6.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 6.0
	tooltip_popup.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.name = "DescriptionLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(180, 0)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
	tooltip_popup.add_child(label)
	
	# 3. Add Popup to Layer immediately
	tooltip_layer.add_child(tooltip_popup)

func _on_mouse_entered() -> void:
	if is_dragging: return
	if not my_ball_data or not tooltip_popup:
		return
	
	var desc = my_ball_data.shop_description
	if desc == null or desc == "":
		return
	
	var desc_label = tooltip_popup.get_node("DescriptionLabel") as Label
	if desc_label:
		desc_label.text = desc
	
	# 4. Only toggle visibility and update position
	tooltip_popup.visible = true
	_update_tooltip_position()

func _on_mouse_exited() -> void:
	if tooltip_popup:
		tooltip_popup.visible = false

func _update_tooltip_position() -> void:
	if not tooltip_popup or not tooltip_popup.visible:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	tooltip_popup.position = Vector2(mouse_pos.x - tooltip_popup.size.x - 10, mouse_pos.y - 10)
	
	var screen_size = get_viewport().get_visible_rect().size
	if tooltip_popup.position.x < 0:
		tooltip_popup.position.x = mouse_pos.x + 15
	if tooltip_popup.position.y < 0:
		tooltip_popup.position.y = 0
	if tooltip_popup.position.y + tooltip_popup.size.y > screen_size.y:
		tooltip_popup.position.y = screen_size.y - tooltip_popup.size.y

func _process(_delta: float) -> void:
	if tooltip_popup and tooltip_popup.visible:
		_update_tooltip_position()

func _exit_tree() -> void:
	# 5. Clean up the layer (which automatically deletes the child popup)
	if tooltip_layer and is_instance_valid(tooltip_layer):
		tooltip_layer.queue_free()
	
	if drag_preview and is_instance_valid(drag_preview):
		drag_preview.queue_free()
