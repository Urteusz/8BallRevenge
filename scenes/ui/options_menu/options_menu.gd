extends PanelContainer

@onready var resolution_button = $HBoxContainer/Graphics/Resolution/ResolutionButton
@onready var vsync_button = $HBoxContainer/Graphics/VSync/VSyncButton
@onready var fullscreen_button = $HBoxContainer/Graphics/FullscreenButton
@onready var apply_button = $HBoxContainer/Graphics/HBoxContainer/ApplyButton

@onready var inverted_mouse_button = $HBoxContainer/Controls/InvertedMouseButton
@onready var volume_slider = $HBoxContainer/Controls/Volume/VolumeSlider
@onready var volume_value_label = $HBoxContainer/Controls/Volume/VolumeValue

const VSYNC_MODES = {
	"Disabled": DisplayServer.VSYNC_DISABLED,
	"Enabled": DisplayServer.VSYNC_ENABLED,
	"Adaptive": DisplayServer.VSYNC_ADAPTIVE,
	"Mailbox": DisplayServer.VSYNC_MAILBOX,
}

# dodaj wiecej
# razem z rozdzielczoscia powinien zmieniac sie strech shrink, chyba
#	(opcja na subviewport containerach, ktora daje efekt ze jest rozpikselwoane)
# 	inaczej gra bedzie roznie wygladala na roznych rozdzielczosciach
# rozdzielczosc 'telewizorow' (poziom 1) tez powinna byc od tego zalezna
# rozdzielczosc projektu to 1280x720, czyli dla takiej rozdzieloczosci zrobione jest ui
#	nie wiem czy przez to ui nie bedzie rozmazane na wyzszych rozdzielczosciach
# 	Ustawilem, 'keep_aspect_ratio' na false, to tez moze sie psuc, np na steamdecku
#		albo na szerszych monitorach
# na niskich rozdzielczosciach ui jest nieczytelne
const RESOLUTIONS = [
	Vector2i(640, 480), # anbernic
	Vector2i(1280, 720),
	Vector2i(1280, 800), # steamdeck
	Vector2i(1680, 720), # 21:9, do testow
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var focused = false

func _ready():
	populate_vsync_options()
	populate_resolution_options()
	load_current_settings()

func _input(input) -> void:
	if !focused and \
		(input.is_action_pressed("ui_up") or input.is_action_pressed("ui_down") or \
		input.is_action_pressed("ui_left") or input.is_action_pressed("ui_right") or \
		input.is_action_pressed("ui_accept") or input.is_action_pressed("ui_cancel") or \
		input.is_action_pressed("pause")):
		resolution_button.grab_focus()
		focused = true
	elif input.is_action_pressed("ui_cancel"):
		Utils.drop_focus()
		focused = false

func populate_vsync_options() -> void:
	vsync_button.clear()
	for text in VSYNC_MODES:
		var mode_id: int = VSYNC_MODES[text]
		vsync_button.add_item(text, mode_id)


func populate_resolution_options() -> void:
	resolution_button.clear()
	for i in range(RESOLUTIONS.size()):
		var res = RESOLUTIONS[i]
		resolution_button.add_item("%d x %d" % [res.x, res.y], i)


func load_current_settings() -> void:
	var vsync_mode = SettingsManager.get_setting("graphics", "vsync_mode")
	var resolution = SettingsManager.get_setting("graphics", "resolution")
	var fullscreen = SettingsManager.get_setting("graphics", "fullscreen")
	var inverted_mouse = SettingsManager.get_setting("controls", "inverted_mouse")

	for i in range(vsync_button.item_count):
		if vsync_button.get_item_id(i) == vsync_mode:
			vsync_button.select(i)
			break

	for i in range(resolution_button.item_count):
		if RESOLUTIONS[i] == resolution:
			resolution_button.select(i)
			break

	fullscreen_button.button_pressed = fullscreen
	inverted_mouse_button.button_pressed = inverted_mouse

	var master_volume = SettingsManager.get_setting("audio", "master_volume")
	if master_volume != null:
		volume_slider.value = master_volume * 100.0
		volume_value_label.text = "%d%%" % int(master_volume * 100.0)


func _on_volume_slider_value_changed(value: float) -> void:
	var linear_volume = value / 100.0
	volume_value_label.text = "%d%%" % int(value)
	SettingsManager.set_setting("audio", "master_volume", linear_volume)
	SettingsManager.apply_audio_settings()


func _on_apply_pressed() -> void:
	var resolution_id: int = resolution_button.get_selected_id()
	var new_resolution = RESOLUTIONS[resolution_id]

	var vsync_id: int = vsync_button.get_selected_id()
	var new_vsync_mode = vsync_button.get_item_id(vsync_id)

	var new_fullscreen: bool = fullscreen_button.button_pressed
	
	var new_inverted_mouse: bool = inverted_mouse_button.button_pressed

	SettingsManager.set_setting("graphics", "resolution", new_resolution)
	SettingsManager.set_setting("graphics", "vsync_mode", new_vsync_mode)
	SettingsManager.set_setting("graphics", "fullscreen", new_fullscreen)
	
	SettingsManager.set_setting("controls", "inverted_mouse", new_inverted_mouse)

	SettingsManager.apply_graphics_settings()
	SettingsManager.apply_audio_settings()
	SettingsManager.save_settings()

	print("Settings Applied and Saved!")


func _on_back_pressed() -> void:
	if LoadManager.previous_scene_path != "":
		LoadManager.load_scene(LoadManager.previous_scene_path)
	else:
		# Fallback to Main Menu if no previous scene (e.g. started directly in Options)
		LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)
