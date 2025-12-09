@tool
extends EditorPlugin

const UniParticleInspectorPlugin = preload("uniparticles_inspector_plugin.gd")
const preview_scene = preload("res://addons/UniParticles3D/uniparticle_preview.tscn")

const ParticleGizmoShapeePlugin = preload("res://addons/UniParticles3D/particle_gizmo_shape_plugin.gd")

var gizmo_plugin = ParticleGizmoShapeePlugin.new()

var inspector_plugin
var preview
var current_main_screen_name: String

func _enter_tree():
	add_node_3d_gizmo_plugin(gizmo_plugin)
	add_custom_type("UniParticles3D", "Node3D", preload("UniParticles3D.gd"), preload("icon.svg"))
	inspector_plugin = UniParticleInspectorPlugin.new()
	add_inspector_plugin(inspector_plugin)

	# Setup preview
	main_screen_changed.connect(_on_main_screen_changed)
	var get_main_screen_parent:Node = EditorInterface.get_editor_main_screen()
	for i in get_main_screen_parent.get_children():
		if i.visible:
			current_main_screen_name = i.get_class().get_basename()
	EditorInterface.get_selection().selection_changed.connect(_on_editor_selection_changed)
	if current_main_screen_name.contains("3D"):
		_on_editor_selection_changed()

func _exit_tree():
	remove_node_3d_gizmo_plugin(gizmo_plugin)
	remove_custom_type("UniParticles3D")
	remove_inspector_plugin(inspector_plugin)
	if main_screen_changed.is_connected(_on_main_screen_changed):
		main_screen_changed.disconnect(_on_main_screen_changed)
	if EditorInterface.get_selection().selection_changed.is_connected(_on_editor_selection_changed):
		EditorInterface.get_selection().selection_changed.disconnect(_on_editor_selection_changed)
	if preview:
		preview.queue_free()
		preview = null
	has_instantiated_viewport_preview = false

	# Remove tool menu button
	remove_tool_menu_item("Import Unity Particles")

var has_instantiated_viewport_preview:bool = false

func _on_main_screen_changed(screen_name: String) -> void:
	current_main_screen_name = screen_name
	if preview != null:
		preview.unlink_particles()
	_on_editor_selection_changed()

func _on_editor_selection_changed() -> void:
	if not current_main_screen_name.contains("3D"):
		if preview != null and preview.visible:
			preview.visible = false
			preview.view_changed(false)
		return

	if not has_instantiated_viewport_preview:
		has_instantiated_viewport_preview = true
		var main_screen = EditorInterface.get_editor_main_screen()
		var viewport_control = _find_3d_viewport_control(main_screen)
		if viewport_control:
			preview = preview_scene.instantiate()
			preview.request_hide()
			#print("Found viewport control, adding preview")
			viewport_control.add_child(preview)

	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	var uni_particles = find_uni_particles_or_null(selected_nodes)

	if uni_particles:
		preview.link_with_particles(uni_particles)
		preview.request_show()
		preview.view_changed(true)
	else:
		preview.request_hide()
		preview.view_changed(false)

func find_uni_particles_or_null(nodes: Array[Node]) -> UniParticles3D:
	for node in nodes:
		if node is UniParticles3D:
			return node
	return null

# Helper function to find the 3D viewport control
func _find_3d_viewport_control(node: Node) -> Control:
	# First find the Node3DEditorViewport
	var editor_viewport = _find_node_by_class(node, "Node3DEditorViewport")
	if not editor_viewport:
		return null
	# Find the Control node that's a sibling of the SubViewportContainer
	for child in editor_viewport.get_children():
		if child is Control and child.get_class() != "SubViewportContainer":
			return child
	return null

# Helper function to find a node by its class name
func _find_node_by_class(node: Node, find_class_name: String) -> Node:
	if node.get_class() == find_class_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_class(child, find_class_name)
		if found:
			return found
	return null
