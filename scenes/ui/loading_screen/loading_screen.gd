extends CanvasLayer

signal loading_screen_has_full_coverage

@export_category("Video Files")
@export var file_fill: String = "res://0001-0075.ogv"
@export var file_empty: String = "res://0075-0150.ogv"

# Reference both players
@onready var player_fill: VideoStreamPlayer = $VideoLayer_Fill
@onready var player_empty: VideoStreamPlayer = $VideoLayer_Empty
@onready var progress_bar: ProgressBar = $Panel/ProgressBar

var _is_loading_finished: bool = false
var _fill_finished: bool = false

func _ready() -> void:
	# Setup Player Empty (The second one)
	# We load it early, but keep it hidden or paused
	player_empty.stream = load(file_empty)
	player_empty.hide() # Hide it so it doesn't interfere yet
	
	# Setup Player Fill (The first one)
	player_fill.stream = load(file_fill)
	player_fill.finished.connect(_on_fill_finished)
	player_fill.play()

func _update_progress_bar(new_value: float) -> void:
	progress_bar.set_value_no_signal(new_value * 100)

func _start_outro_animation() -> void:
	_is_loading_finished = true
	_check_and_start_outro()

# --- Logic ---

func _on_fill_finished() -> void:
	_fill_finished = true
	
	# FREEZE the top player. It now acts as a static "screenshot" 
	# covering the transition logic.
	player_fill.paused = true
	
	loading_screen_has_full_coverage.emit()
	_check_and_start_outro()

func _check_and_start_outro() -> void:
	if _fill_finished and _is_loading_finished:
		_transition_to_empty()

func _transition_to_empty() -> void:
	# 1. Prepare the bottom player (Empty)
	player_empty.show()
	player_empty.play()
	
	# 2. WAIT A FRAME (Crucial!)
	# We need to give the video decoder 1-2 frames to actually put 
	# pixels on the texture. If we hide the top layer immediately, 
	# we might still see a black flash from the bottom layer starting up.
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 3. Now that the bottom video is definitely running, delete the top one.
	# The user won't notice the switch because the images should be identical.
	player_fill.queue_free()
	
	# 4. Handle end of second video
	await player_empty.finished
	queue_free()
