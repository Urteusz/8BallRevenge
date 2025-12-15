extends Node3D

const BALLS_GROUP = "balls"

@export var default_level_move_count: int = 10
@export var player_ball: RigidBody3D
@export var shop_ui: Control
@export var gameplay_ui: Control

var moves_left: int
var game_over := false
var ball_list: Array
var points: int = 500
var turn_move_refunded := false 
var game_win := false

signal player_died
signal player_win
signal moves_changed(moves_left: int)
signal points_changed(points: int)
signal charging_started
signal charging_updated(charge_ratio: float)
signal charging_released
signal ball_pocketed(ball_id: int)

func _ready() -> void:
	moves_left = default_level_move_count
	
	ball_list = get_tree().get_nodes_in_group(BALLS_GROUP)
	
	if ball_list.has(player_ball): # Dodano sprawdzenie czy lista zawiera gracza
		ball_list.erase(player_ball)
	
	if player_ball and player_ball.has_signal("ball_pocketed"):
		player_ball.ball_pocketed.connect(_on_ball_pocketed)
	
	for ball in ball_list:
		if ball.has_signal("ball_pocketed"):
			ball.ball_pocketed.connect(_on_ball_pocketed)
		if ball.has_signal("points_scored"):
			ball.points_scored.connect(_on_points_scored)
		if ball.has_signal("score_updated") and gameplay_ui:
			# bind() przesyła ID kuli, żeby UI wiedziało którą kartę zmienić
			ball.score_updated.connect(gameplay_ui._on_ball_score_updated.bind(ball.get_instance_id()))
	
	if player_ball.has_signal("round_ended"):
		player_ball.round_ended.connect(_on_round_ended)
		
	if player_ball.has_signal("ball_pushed"):
		player_ball.ball_pushed.connect(_on_ball_pushed)
	
	if shop_ui:
		connect("points_changed", shop_ui._on_points_updated)
	if gameplay_ui:
		connect("charging_started", gameplay_ui._on_charging_started)
		connect("charging_updated", gameplay_ui._on_charging_updated)
		connect("charging_released", gameplay_ui._on_charging_released)
		connect("ball_pocketed", gameplay_ui._on_ball_pocketed)
		emit_signal("moves_changed", moves_left)
	print("--- PODŁĄCZANIE KUL DO UI ---")
	for ball in ball_list:
		print("Sprawdzam kulę: ", ball.name)
		
		# Logika standardowa
		if ball.has_signal("ball_pocketed"):
			ball.ball_pocketed.connect(_on_ball_pocketed)
		if ball.has_signal("points_scored"):
			ball.points_scored.connect(_on_points_scored)
			
		# DIAGNOSTYKA PUNKTÓW
		if ball.has_signal("score_updated"):
			if gameplay_ui:
				ball.score_updated.connect(gameplay_ui._on_ball_score_updated.bind(ball.get_instance_id()))
				print("   -> SUKCES: Podłączono sygnał punktów dla: ", ball.name)
			else:
				print("   -> BŁĄD: Brak GameplayUI!")
		else:
			print("   -> BŁĄD: Kula ", ball.name, " NIE MA sygnału score_updated! (Problem z dziedziczeniem?)")

func get_level_balls() -> Array:
	var balls_data_for_ui = []
	
	# Pobieramy świeżą listę kul z grupy
	ball_list = get_tree().get_nodes_in_group(BALLS_GROUP)
	
	# --- NAPRAWA: USUWAMY GRACZA Z LISTY CELÓW ---
	if player_ball and ball_list.has(player_ball):
		ball_list.erase(player_ball)
	# ---------------------------------------------
	
	for ball in ball_list:
		var ui_color = Color.WHITE
		var ui_texture = null
		var ui_points = 0
		
		# 1. Wygląd
		var meshes = ball.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() > 0:
			var mat = meshes[0].get_active_material(0)
			if mat is StandardMaterial3D or mat is ORMMaterial3D:
				ui_color = mat.albedo_color
				ui_texture = mat.albedo_texture
			elif mat is ShaderMaterial:
				if mat.get_shader_parameter("albedo") is Color:
					ui_color = mat.get_shader_parameter("albedo")
		
		# 2. Punkty
		if "total_points" in ball:
			ui_points = ball.total_points
		elif "base_value" in ball:
			ui_points = 0
			
		# 3. Podłączanie sygnałów (Race condition fix)
		if gameplay_ui and ball.has_signal("score_updated"):
			if not ball.score_updated.is_connected(gameplay_ui._on_ball_score_updated):
				ball.score_updated.connect(gameplay_ui._on_ball_score_updated.bind(ball.get_instance_id()))
		
		balls_data_for_ui.append({
			"id": ball.get_instance_id(),
			"color": ui_color,
			"texture": ui_texture,
			"points": ui_points,
			"name": _pretty_ball_name(ball.name)
		})
		
	return balls_data_for_ui

func _process(delta: float) -> void:
	if player_ball and player_ball.charging:
		var charge_ratio = clamp(
			player_ball.charge_timer / player_ball.max_charge_duration, 
			0.0, 
			1.0
		)
		emit_signal("charging_updated", charge_ratio)

func _input(event) -> void:
	if moves_left <= 0 and !player_ball.sleeping:
		return

	if event.is_action_pressed("push_ball") and player_ball:
		if player_ball.can_shoot():
			emit_signal("charging_started")

func _on_ball_pushed(impulse_power: float) -> void:
	emit_signal("charging_released")
	
	moves_left -= 1
	emit_signal("moves_changed", moves_left)
	
	turn_move_refunded = false

func _on_ball_pocketed(ball):
	print("Pocketed")
	if ball == player_ball:
		moves_left -= 1
		emit_signal("moves_changed", moves_left)
		ball.sleeping = true
		ball.position = Vector3(0.093, 0.294, 10.219)
	else:
		if not turn_move_refunded:
			moves_left += 1
			turn_move_refunded = true
			emit_signal("moves_changed", moves_left)
			print("Bila wbita! Ruch zwrócony.")
			
		emit_signal("ball_pocketed", ball.get_instance_id())
		
		ball_list.erase(ball)
		ball.queue_free()
		_check_win_condition()

func _on_round_ended() -> void:
	if game_over or game_win:
		return
	
	if _check_win_condition():
		return
	
	if moves_left < 0: 
		moves_left = 0
		emit_signal("moves_changed", moves_left)
		_on_game_over()
	elif moves_left == 0:
		_on_game_over()

func _check_win_condition() -> bool:
	if ball_list.size() == 0:
		if !game_win and !game_over:
			game_win = true
			points = points * max(moves_left + 1, 1) 
			PlayerData.set_level(3)
			emit_signal("points_changed", points)
			emit_signal("player_win")
			print("WYGRANA! Pozostałe ruchy: ", moves_left)
		return true
	return false

func _on_points_scored(points_earned: int, world_pos: Vector3) -> void:
	points += points_earned
	print_debug("Zdobyto punkty:", points_earned, "Suma:", points)
	emit_signal("points_changed", points)

func _on_game_over() -> void:
	if game_over or game_win:
		return
	
	game_over = true
	emit_signal("player_died")
	print("PRZEGRANA! Brak ruchów.")
	
	# ... (reszta skryptu GameManager.gd)

func _pretty_ball_name(raw_name: String) -> String:
	var n: String = raw_name.strip_edges()
	# usuń leading '@' (występuje w niektórych instancjach)
	if n.begins_with("@"):
		n = n.substr(1).strip_edges()
	# usuń dopiski typu " (Instance)"
	n = n.replace(" (Instance)", "")
	n = n.replace("(Instance)", "")
	# jeśli puste po czyszczeniu -> fallback
	if n == "":
		return "Ball"
	var lower := n.to_lower()
	# Jeżeli nazwa wygląda jak generyczny node -> fallback
	if lower.find("rigid") != -1 or lower.find("body") != -1 or lower.find("node") != -1 or lower.find("instance") != -1:
		return "Ball"
	# zamień podkreślenia i trim
	n = n.replace("_", " ").strip_edges()
	var result := ""
	for c in n:
		var prev := ""
		if result.length() > 0:
			prev = result[result.length() - 1]
		if c != c.to_lower() and prev != " " and prev != "":
			result += " " + c
		else:
			result += c
	n = result.strip_edges()
	# kapitalizuj pierwszą literę
	if n.length() > 0:
		return n.substr(0, 1).to_upper() + n.substr(1)
	return "Ball"
	
