extends Control

# --- REFERENCJE DO WĘZŁÓW (Dzięki % działają wszędzie) ---
@onready var resolution_button = %ResolutionButton
@onready var vsync_button = %VSyncButton
@onready var fullscreen_button = %FullscreenButton

@onready var apply_button = %ApplyButton
@onready var apply_hint_label = %ApplyButtonLabel # Upewnij się, że dałeś mu %

@onready var inverted_mouse_button = %InvertedMouseButton
@onready var volume_slider = %VolumeSlider
@onready var volume_value_label = %VolumeValue

# Opcjonalne przyciski (używamy get_node_or_null żeby nie wywaliło błędu jak ich nie ma)
@onready var quit_button = %QuitButton if has_node("%QuitButton") else null
@onready var reset_button = %ResetButton if has_node("%ResetButton") else null

const VSYNC_MODES = {
	"Disabled": DisplayServer.VSYNC_DISABLED,
	"Enabled": DisplayServer.VSYNC_ENABLED,
	"Adaptive": DisplayServer.VSYNC_ADAPTIVE,
	"Mailbox": DisplayServer.VSYNC_MAILBOX,
}

const RESOLUTIONS = [
	Vector2i(640, 480),
	Vector2i(1280, 720),
	Vector2i(1280, 800), # Steam Deck
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const DEFAULT_SETTINGS := {
	"graphics": {
		"vsync_mode": DisplayServer.VSYNC_DISABLED,
		"resolution": Vector2i(1280, 720),
		"fullscreen": false,
	},
	"controls": {
		"inverted_mouse": false,
	},
	"audio": {
		"master_volume": 1.0, 
	},
}

var focused = false

func _ready():
	# --- AUTOMATYCZNE PODŁĄCZANIE SYGNAŁÓW ---
	# Nie musisz tego robić w edytorze, robimy to kodem tutaj:
	apply_button.pressed.connect(_on_apply_pressed)
	volume_slider.value_changed.connect(_on_volume_slider_value_changed)
	
	if quit_button:
		quit_button.pressed.connect(_on_back_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_button_pressed)

	# --- INICJALIZACJA UI ---
	populate_vsync_options()
	populate_resolution_options()
	load_current_settings()

func _input(event) -> void:
	# Obsługa nawigacji padem/klawiaturą
	if !focused and (event is InputEventJoypadButton or event is InputEventKey):
		if event.is_pressed() and (event.is_action("ui_up") or event.is_action("ui_down")):
			resolution_button.grab_focus()
			focused = true
			
	if event.is_action_pressed("ui_cancel"):
		if focused:
			resolution_button.release_focus() # Puszczenie focusu
			focused = false
		_on_back_pressed() # Cofnięcie do menu

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

	# Ustawienie VSync w UI
	for i in range(vsync_button.item_count):
		if vsync_button.get_item_id(i) == vsync_mode:
			vsync_button.select(i)
			break

	# Ustawienie Rozdzielczości w UI
	var res_index = -1
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i] == resolution:
			res_index = i
			break
	
	if res_index != -1:
		resolution_button.select(res_index)
	else:
		# Obsługa niestandardowej rozdzielczości
		resolution_button.add_item("%d x %d (Custom)" % [resolution.x, resolution.y])
		resolution_button.select(resolution_button.item_count - 1)

	fullscreen_button.button_pressed = fullscreen
	inverted_mouse_button.button_pressed = inverted_mouse

	var master_volume = SettingsManager.get_setting("audio", "master_volume")
	if master_volume != null:
		volume_slider.value = master_volume * 100.0
		volume_value_label.text = "%d%%" % int(master_volume * 100.0)

func _on_volume_slider_value_changed(value: float) -> void:
	var linear_volume = value / 100.0
	volume_value_label.text = "%d%%" % int(value)
	
	# Opcjonalnie: Zastosuj głośność od razu (żeby gracz słyszał zmianę)
	SettingsManager.set_setting("audio", "master_volume", linear_volume)
	# SettingsManager.apply_audio_settings() # Odkomentuj jeśli chcesz efekt natychmiastowy

func _on_apply_pressed() -> void:
	# Pobieranie danych z UI
	var resolution_id: int = resolution_button.get_selected_id()
	var new_resolution = RESOLUTIONS[resolution_id] if resolution_id < RESOLUTIONS.size() else SettingsManager.get_setting("graphics", "resolution")

	var vsync_id: int = vsync_button.get_selected_id()
	var new_vsync_mode = vsync_button.get_item_id(vsync_id)

	var new_fullscreen: bool = fullscreen_button.button_pressed
	var new_inverted_mouse: bool = inverted_mouse_button.button_pressed
	
	# Zapis do SettingsManagera
	SettingsManager.set_setting("graphics", "resolution", new_resolution)
	SettingsManager.set_setting("graphics", "vsync_mode", new_vsync_mode)
	SettingsManager.set_setting("graphics", "fullscreen", new_fullscreen)
	SettingsManager.set_setting("controls", "inverted_mouse", new_inverted_mouse)
	
	# Głośność (pobieramy ponownie dla pewności)
	var vol_linear = volume_slider.value / 100.0
	SettingsManager.set_setting("audio", "master_volume", vol_linear)

	# Aplikowanie zmian
	SettingsManager.apply_graphics_settings()
	SettingsManager.apply_audio_settings()
	SettingsManager.save_settings()
	
	print("Ustawienia Zapisane i Zaaplikowane!")

func _on_back_pressed() -> void:
	if LoadManager.previous_scene_path != "":
		LoadManager.load_scene(LoadManager.previous_scene_path)
	else:
		LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)

func _on_reset_button_pressed() -> void:
	# Przywracanie domyślnych w UI
	
	# VSYNC
	var def_vsync = DEFAULT_SETTINGS["graphics"]["vsync_mode"]
	for i in range(vsync_button.item_count):
		if vsync_button.get_item_id(i) == def_vsync:
			vsync_button.select(i)
			break

	# RESOLUTION
	var def_res = DEFAULT_SETTINGS["graphics"]["resolution"]
	for i in range(resolution_button.item_count):
		if RESOLUTIONS[i] == def_res:
			resolution_button.select(i)
			break

	# RESZTA
	fullscreen_button.button_pressed = DEFAULT_SETTINGS["graphics"]["fullscreen"]
	inverted_mouse_button.button_pressed = DEFAULT_SETTINGS["controls"]["inverted_mouse"]

	var vol = DEFAULT_SETTINGS["audio"]["master_volume"]
	volume_slider.value = vol * 100.0
	volume_value_label.text = "%d%%" % int(vol * 100.0)
	
	print("Przywrócono domyślne (kliknij Apply aby zapisać).")
