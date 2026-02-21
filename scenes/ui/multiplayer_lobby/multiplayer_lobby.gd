extends Control

@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var ip_field: LineEdit = %IpField
@onready var status_label: Label = %StatusLabel
@onready var back_button: Button = %BackButton
@onready var start_button: Button = %StartButton

var both_connected: bool = false

func _ready() -> void:
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.all_players_ready.connect(_on_all_players_ready)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_created.connect(_on_server_created)
	start_button.visible = false
	status_label.text = ""

func _on_host_button_pressed() -> void:
	var error := NetworkManager.host_game()
	if error != OK:
		status_label.text = "Nie udalo sie utworzyc serwera!"
		return
	host_button.disabled = true
	join_button.disabled = true
	ip_field.editable = false

func _on_server_created() -> void:
	status_label.text = "Serwer utworzony. Czekam na gracza..."

func _on_join_button_pressed() -> void:
	var address := ip_field.text.strip_edges()
	if address == "":
		address = "127.0.0.1"
	var error := NetworkManager.join_game(address)
	if error != OK:
		status_label.text = "Nie udalo sie polaczyc!"
		return
	host_button.disabled = true
	join_button.disabled = true
	ip_field.editable = false
	status_label.text = "Laczenie z " + address + "..."

func _on_player_connected(_id: int) -> void:
	status_label.text = "Gracz polaczony!"

func _on_player_disconnected(_id: int) -> void:
	status_label.text = "Gracz rozlaczony."
	both_connected = false
	start_button.visible = false

func _on_all_players_ready() -> void:
	both_connected = true
	status_label.text = "Obaj gracze gotowi!"
	if NetworkManager.is_host:
		start_button.visible = true

func _on_connection_failed() -> void:
	status_label.text = "Polaczenie nieudane!"
	host_button.disabled = false
	join_button.disabled = false
	ip_field.editable = true

func _on_start_button_pressed() -> void:
	if NetworkManager.is_host and both_connected:
		_notify_client_waiting.rpc()
		LoadManager.load_scene(ScenePaths.LEVEL_SELECT_MAP)

@rpc("authority", "call_remote", "reliable")
func _notify_client_waiting() -> void:
	status_label.text = "Host wybiera level..."
	host_button.disabled = true
	join_button.disabled = true
	start_button.visible = false

func _on_back_button_pressed() -> void:
	NetworkManager.disconnect_from_game()
	LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)
