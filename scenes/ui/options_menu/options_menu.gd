extends Control

# --- REFERENCJE DO WĘZŁÓW (Dzięki % działają wszędzie) ---
@onready var resolution_button = %ResolutionButton
@onready var vsync_button = %VSyncButton
@onready var fullscreen_button = %FullscreenButton

@onready var apply_button = %ApplyButton
@onready var apply_hint_label = %ApplyButtonLabel # Upewnij się, że dałeś mu %

@onready var inverted_mouse_button = %InvertedMouseButton
@onready var pad_sensitivity_slider = %PadSensitivitySlider
@onready var pad_sensitivity_value_label = %PadSensitivityValue
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
		"pad_sensitivity": 1.0,
	},
	"audio": {
		"master_volume": 1.0, 
	},
}

var focused = false
var _open_dropdown = null  # aktualnie otwarty OptionButton (lub null)

func _ready():
	# --- AUTOMATYCZNE PODŁĄCZANIE SYGNAŁÓW ---
	# Nie musisz tego robić w edytorze, robimy to kodem tutaj:
	apply_button.pressed.connect(_on_apply_pressed)
	pad_sensitivity_slider.value_changed.connect(_on_pad_sensitivity_slider_value_changed)
	volume_slider.value_changed.connect(_on_volume_slider_value_changed)
	
	if quit_button:
		quit_button.pressed.connect(_on_back_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_button_pressed)

	# --- INICJALIZACJA UI ---
	populate_vsync_options()
	populate_resolution_options()
	load_current_settings()

	_setup_focus_nav()

	# Gdy dropdown jest otwarty, blokujemy nawigacje focusa w tle, zeby ui_down
	# nie przesuwalo jednoczesnie pozycji popupa i ustawien pod spodem.
	for ob in [resolution_button, vsync_button]:
		if ob:
			var popup = ob.get_popup()
			if not popup.about_to_popup.is_connected(_on_dropdown_about_to_popup):
				popup.about_to_popup.connect(_on_dropdown_about_to_popup.bind(ob))
			if not popup.popup_hide.is_connected(_on_dropdown_hidden):
				popup.popup_hide.connect(_on_dropdown_hidden)

# Przypnij sasiadow focusa do samego siebie (^".") -> focus nie ucieka w tle.
func _on_dropdown_about_to_popup(ob) -> void:
	_open_dropdown = ob
	ob.focus_neighbor_left = ^"."
	ob.focus_neighbor_right = ^"."
	ob.focus_neighbor_top = ^"."
	ob.focus_neighbor_bottom = ^"."

func _on_dropdown_hidden() -> void:
	_open_dropdown = null
	_setup_focus_nav()

# Pelny lancuch focusa padem/klawiatura - kazda kontrolka i kazdy przycisk
# (Apply / Default / Return) musi byc osiagalny.
func _setup_focus_nav() -> void:
	var ret = quit_button
	var def = reset_button

	for c in [resolution_button, vsync_button, fullscreen_button,
			inverted_mouse_button, pad_sensitivity_slider, volume_slider, apply_button, ret, def]:
		if c:
			c.focus_mode = Control.FOCUS_ALL

	# Trzy kolumny: LEFT/RIGHT zmienia kolumne, UP/DOWN chodzi po danej kolumnie.
	# A: [Apply, Default, Return], B: [Resolution, VSync, Fullscreen], C: [InvertedMouse, PadSensitivity, Volume]

	# Kolumna B: Graphics
	_nb(resolution_button, apply_button, inverted_mouse_button, fullscreen_button, vsync_button)
	_nb(vsync_button, def if def else apply_button, pad_sensitivity_slider, resolution_button, fullscreen_button)
	_nb(fullscreen_button, ret if ret else (def if def else apply_button), volume_slider, vsync_button, resolution_button)

	# Kolumna C: Controls / Audio
	_nb(inverted_mouse_button, resolution_button, apply_button, volume_slider, pad_sensitivity_slider)
	_nb(pad_sensitivity_slider, vsync_button, def if def else apply_button, inverted_mouse_button, volume_slider)
	_nb(volume_slider, fullscreen_button, ret if ret else (def if def else apply_button), pad_sensitivity_slider, inverted_mouse_button)

	# Kolumna A: Akcje
	if def and ret:
		_nb(apply_button,   inverted_mouse_button,  resolution_button,  ret,          def)
		_nb(def,            pad_sensitivity_slider, vsync_button,       apply_button, ret)
		_nb(ret,            volume_slider,          fullscreen_button,  def,          apply_button)
	elif def:
		_nb(apply_button,   inverted_mouse_button,  resolution_button,  def,          def)
		_nb(def,            pad_sensitivity_slider, vsync_button,       apply_button, apply_button)
	elif ret:
		_nb(apply_button,   inverted_mouse_button,  resolution_button,  ret,          ret)
		_nb(ret,            volume_slider,          fullscreen_button,  apply_button, apply_button)
	else:
		_nb(apply_button,   inverted_mouse_button,  resolution_button,  inverted_mouse_button, inverted_mouse_button)

# Ustawia albo czysci sasiadow focusa. Parametry nietypowane, bo @onready
# w tym pliku sa nietypowane i chcemy uniknac ostrzezen o rzutowaniu.
func _nb(node, left, right, top, bottom) -> void:
	if not node:
		return
	node.focus_neighbor_left = node.get_path_to(left) if left else NodePath()
	node.focus_neighbor_right = node.get_path_to(right) if right else NodePath()
	node.focus_neighbor_top = node.get_path_to(top) if top else NodePath()
	node.focus_neighbor_bottom = node.get_path_to(bottom) if bottom else NodePath()

func _input(event) -> void:
	# Otwarty dropdown: sami obslugujemy akcept/anuluj (pad nie zatwierdza popupa).
	if _open_dropdown:
		if event.is_action_pressed("ui_accept"):
			var popup = _open_dropdown.get_popup()
			var idx: int = popup.get_focused_item()
			if idx >= 0:
				_open_dropdown.select(idx)
				_open_dropdown.item_selected.emit(idx)
			popup.hide()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			_open_dropdown.get_popup().hide()
			get_viewport().set_input_as_handled()
			return

	# Pierwszy ruch padem/klawiatura - zlap focus na pierwszej opcji.
	if !focused and (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") \
			or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		resolution_button.grab_focus()
		focused = true
		get_viewport().set_input_as_handled()
		return

	# B (ui_cancel) / Esc - powrot do poprzedniego menu.
	if event.is_action_pressed("ui_cancel"):
		if focused:
			resolution_button.release_focus()
			focused = false
		_on_back_pressed()

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
	var pad_sensitivity = SettingsManager.get_setting("controls", "pad_sensitivity")

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
	if pad_sensitivity != null:
		pad_sensitivity_slider.value = pad_sensitivity * 100.0
		pad_sensitivity_value_label.text = "%d%%" % int(pad_sensitivity_slider.value)

	var master_volume = SettingsManager.get_setting("audio", "master_volume")
	if master_volume != null:
		volume_slider.value = master_volume * 100.0
		volume_value_label.text = "%d%%" % int(master_volume * 100.0)

func _on_pad_sensitivity_slider_value_changed(value: float) -> void:
	pad_sensitivity_value_label.text = "%d%%" % int(value)

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
	var new_pad_sensitivity: float = pad_sensitivity_slider.value / 100.0
	
	# Zapis do SettingsManagera
	SettingsManager.set_setting("graphics", "resolution", new_resolution)
	SettingsManager.set_setting("graphics", "vsync_mode", new_vsync_mode)
	SettingsManager.set_setting("graphics", "fullscreen", new_fullscreen)
	SettingsManager.set_setting("controls", "inverted_mouse", new_inverted_mouse)
	SettingsManager.set_setting("controls", "pad_sensitivity", new_pad_sensitivity)
	
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
	pad_sensitivity_slider.value = DEFAULT_SETTINGS["controls"]["pad_sensitivity"] * 100.0
	pad_sensitivity_value_label.text = "%d%%" % int(pad_sensitivity_slider.value)

	var vol = DEFAULT_SETTINGS["audio"]["master_volume"]
	volume_slider.value = vol * 100.0
	volume_value_label.text = "%d%%" % int(vol * 100.0)
	
	print("Przywrócono domyślne (kliknij Apply aby zapisać).")
