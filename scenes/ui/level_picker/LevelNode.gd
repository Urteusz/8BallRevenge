extends Node2D
class_name LevelNode

signal clicked(node: LevelNode)

@export_group("Konfiguracja")
@export var level_number: int = 1
@export var level_scene_path: String = ""
@export var icon_texture: Texture2D

@export_group("Połączenia")
@export var neighbors: Array[LevelNode]

@export_group("Gwiazdki")
@export var star_offset_y: float = -60.0
@export var star_size: Vector2 = Vector2(20, 20)
@export var star_spacing: float = 5.0

@export_group("Label")
@export var show_level_number: bool = true
@export var level_label_offset_y: float = 40.0

@onready var sprite = $Sprite2D
@onready var click_area: Area2D = $ClickArea

var star_container: HBoxContainer
var level_label: Label
var star_texture = preload("res://textures/star_texture.png")
var is_selected: bool = false

func _ready():
	if icon_texture:
		sprite.texture = icon_texture

	_create_star_display()
	_create_level_label()
	_update_stars()
	_setup_click_area()

func _setup_click_area() -> void:
	if not click_area:
		push_warning("ClickArea not found in scene!")
		return

	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("clicked", self)

			if event.double_click:
				pass

func _on_mouse_entered() -> void:
	if not is_selected:
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.15)
		sprite.modulate = Color(1.1, 1.1, 1.1, 1.0)

func _on_mouse_exited() -> void:
	if not is_selected:
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func set_selected(selected: bool) -> void:
	is_selected = selected

	if selected:
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.2)
		sprite.modulate = Color(1.2, 1.2, 1.2, 1.0)
	else:
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _create_star_display() -> void:
	star_container = HBoxContainer.new()
	star_container.alignment = BoxContainer.ALIGNMENT_CENTER
	star_container.add_theme_constant_override("separation", int(star_spacing))
	star_container.position = Vector2(-30, star_offset_y)

	for i in 3:
		var star = TextureRect.new()
		star.texture = star_texture
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.custom_minimum_size = star_size
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.modulate = Color(0.2, 0.2, 0.2, 0.35)
		star_container.add_child(star)

	add_child(star_container)

func _update_stars() -> void:
	if not star_container:
		return

	var stars_earned = PlayerData.get_level_stars(level_number)

	for i in 3:
		var star = star_container.get_child(i)
		if i < stars_earned:
			star.modulate = Color(1.0, 0.95, 0.4, 1.0)
		else:
			star.modulate = Color(0.2, 0.2, 0.2, 0.35)

func refresh_stars() -> void:
	_update_stars()

func _create_level_label() -> void:
	if not show_level_number:
		return

	level_label = Label.new()
	level_label.text = "Level " + str(level_number)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.position = Vector2(-50, level_label_offset_y)
	level_label.custom_minimum_size = Vector2(100, 0)
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.add_theme_color_override("font_outline_color", Color.BLACK)
	level_label.add_theme_constant_override("outline_size", 2)
	add_child(level_label)
