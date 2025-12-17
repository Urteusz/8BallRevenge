extends Node3D

# to musi byc potem przepisane zeby uzywalo object pool
#	inaczej bedzie lagowac pewnie
# aby dzialalo to z edge detection shaderem ustawilem render priority label3d na 127 i 126

var label = null
var animation_player = null


func _ready() -> void:
	# Znajdź label w kilku możliwych lokalizacjach, bez używania 'or' (które zwraca bool)
	label = get_node_or_null("LabelContainer/Label")
	if not label:
		label = get_node_or_null("Label")
	if not label:
		label = get_node_or_null("Label3D")

	animation_player = get_node_or_null("AnimationPlayer")
	if not animation_player:
		animation_player = get_node_or_null("AnimationPlayer3D")


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


func set_and_play(value: int, ball_name: String = "") -> void:
	if label:
		if ball_name != "":
			var pretty := _pretty_ball_name(ball_name)
			label.text = "%s\n%d" % [pretty, value]
		else:
			label.text = str(value)
	if animation_player:
		animation_player.play("PointsPopupAnimation")


func total_points(value: int, ball_name: String = "") -> void:
	if label:
		if ball_name != "":
			var pretty := _pretty_ball_name(ball_name)
			label.text = "%s\n%d" % [pretty, value]
		else:
			label.text = str(value)
	if animation_player:
		animation_player.play("TotalPointsAnimation")


func remove() -> void:
	queue_free()
