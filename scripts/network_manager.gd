extends Node

const DEFAULT_PORT: int = 9999
const MAX_CLIENTS: int = 2

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var peer_id: int = 0
var opponent_id: int = 0

signal player_connected(id: int)
signal player_disconnected(id: int)
signal all_players_ready
signal connection_failed
signal server_created

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func host_game(port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		peer = null
		return error
	multiplayer.multiplayer_peer = peer
	is_host = true
	peer_id = 1
	print("Server created on port ", port)
	server_created.emit()
	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		peer = null
		return error
	multiplayer.multiplayer_peer = peer
	is_host = false
	print("Connecting to ", address, ":", port)
	return OK

func is_multiplayer_active() -> bool:
	return peer != null and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func disconnect_from_game() -> void:
	if peer:
		multiplayer.multiplayer_peer = null
		peer = null
	is_host = false
	peer_id = 0
	opponent_id = 0

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	opponent_id = id
	player_connected.emit(id)
	if is_host:
		all_players_ready.emit()

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	opponent_id = 0
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	peer_id = multiplayer.get_unique_id()
	print("Connected to server. My ID: ", peer_id)
	player_connected.emit(1)
	all_players_ready.emit()

func _on_connection_failed() -> void:
	print("Connection failed!")
	peer = null
	is_host = false
	connection_failed.emit()

@rpc("authority", "call_remote", "reliable")
func load_level(level_path: String, deck_data: Array) -> void:
	# Called on client by host to load the same level
	PlayerData.current_deck = []
	for ball_data_path in deck_data:
		var ball_data = load(ball_data_path)
		if ball_data:
			PlayerData.current_deck.append(ball_data)
	LoadManager.load_scene(level_path)

func host_start_level(level_path: String) -> void:
	# Host calls this to start the level on both instances
	var deck_paths: Array = []
	for ball_data in PlayerData.current_deck:
		if ball_data and ball_data.resource_path:
			deck_paths.append(ball_data.resource_path)
	load_level.rpc(level_path, deck_paths)
	LoadManager.load_scene(level_path)
