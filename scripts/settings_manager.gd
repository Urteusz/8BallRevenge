extends Node

const SETTINGS_PATH = "user://settings.cfg"
var settings_data = { }

const DEFAULTS = {
	"graphics": {
		"resolution": Vector2i(1920, 1080),
		"vsync_mode": DisplayServer.VSYNC_ENABLED,
		"fullscreen": true,
	},
	"controls": {
		"inverted_mouse": false,
	},
	"audio": {
		"master_volume": 1.0,
	}
}


func _ready():
	load_settings()
	apply_audio_settings()


func load_settings():
	settings_data = DEFAULTS.duplicate(true)
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)

	if err != OK:
		print("No settings file found or file corrupted. Using defaults.")
		save_settings()
		apply_graphics_settings()
		return

	for section in config.get_sections():
		if settings_data.has(section):
			for key in config.get_section_keys(section):
				if settings_data[section].has(key):
					settings_data[section][key] = config.get_value(section, key)

	save_settings()
	apply_graphics_settings()


func save_settings():
	var config = ConfigFile.new()

	for section in settings_data:
		for key in settings_data[section]:
			config.set_value(section, key, settings_data[section][key])

	config.save(SETTINGS_PATH)


func apply_graphics_settings():
	var gfx = settings_data["graphics"]
	DisplayServer.window_set_vsync_mode(gfx["vsync_mode"])

	if gfx["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	DisplayServer.window_set_size(gfx["resolution"])


func apply_audio_settings():
	var volume = settings_data["audio"]["master_volume"]
	var bus_index = AudioServer.get_bus_index("Master")
	if volume <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(volume))


func set_setting(section, key, value):
	if not settings_data.has(section):
		settings_data[section] = { }
	settings_data[section][key] = value


func get_setting(section, key):
	return settings_data.get(section, { }).get(key, null)
