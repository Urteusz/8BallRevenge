@tool
extends EditorInspectorPlugin
class_name YParticlesInspectorPlugin
const attr_template := "# @@%s("

var debug: bool = false
var property_groups: Dictionary = {}
var toggle_groups: Dictionary = {}  # Maps toggle properties to their group definitions
var show_if_conditions: Dictionary = {} # Maps properties to their show_if conditions
var hide_if_conditions: Dictionary = {} # Maps properties to their hide_if conditions
#
var double_check_or_hide_if:Dictionary = {}

static var _vcontainers:Array[VBoxContainer] = []
var _property_map: Dictionary = {}
var _current_object: UniParticles3D

func _can_handle(object: Object) -> bool:
	#if debug: print("UniParticleInspectorPlugin: Can handle check for ", object.get_class())
	return object is UniParticles3D

func _cleanup() -> void:
	property_groups.clear()
	toggle_groups.clear()
	show_if_conditions.clear()
	hide_if_conditions.clear()
	double_check_or_hide_if.clear()
	_property_map.clear()
	_current_object = null

	# Clean up any remaining VBoxContainers
	for container in _vcontainers:
		if is_instance_valid(container):
			container.queue_free()
	_vcontainers.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if self != null and is_instance_valid(self):
			_cleanup()

func editor_property_list_changed(property: StringName, value: Variant, field: StringName, changing: bool,object:EditorProperty):
	if object != null:
		#print("Editor property list changed ",object.get_class())

		next_frame_after_editor_property_list_changed.call_deferred(property, value, field, changing, object)

func next_frame_after_editor_property_list_changed(property: StringName, value: Variant, field: StringName, changing: bool,object:EditorProperty):
	if object != null and not ((object as EditorProperty).property_changed.is_connected(editor_property_list_changed.bind(object))):
		verify_change_show_hide_if_conditions.call_deferred()
		object.property_changed.connect(editor_property_list_changed.bind(object), CONNECT_ONE_SHOT)

var already_called_parse_begin:bool = false
func _parse_begin(object: Object) -> void:
	if not object is UniParticles3D:
		return

	# Clean up previous state
	_cleanup()

	if debug: print("UniParticleInspectorPlugin: Beginning parse for UniParticles3D")
	_current_object = object

	_property_map.clear()
	toggle_groups.clear()
	double_check_or_hide_if.clear()

	_parse_single_script(object.get_script())

	if debug: print("Property groups is %s" % property_groups )
	for group_key in property_groups:
		if debug: print ("Group key ", group_key)
		var group = property_groups[group_key]
		if debug: print ("group properties ",group.properties)
		_property_map[group.mode_property] = group
		for mode in group.properties:
			_property_map[mode] = group
	if debug: print("UniParticleInspectorPlugin: Property map: ", _property_map)
	if debug: print("UniParticleInspectorPlugin: Toggle groups: ", toggle_groups)

func _parse_single_script(parse_script : Script):
	if debug: print("UniParticleInspectorPlugin: Parsing script: ", parse_script.resource_path)
	if parse_script.get_base_script() != null:
		_parse_single_script(parse_script.get_base_script())
	var source : String = parse_script.source_code
	var parse_found_prop := ""
	var parse_found_comments := []
	var illegal_starts := ["#".unicode_at(0), " ".unicode_at(0), "\t".unicode_at(0)]
	var characters_parsed := 0

	var last_toggle_group = null
	var last_show_if = ""
	var last_hide_if = ""

	for x in source.split("\n"):
		characters_parsed += x.length() + 1
		if x == "": continue

		if x.begins_with("# @only_show_if("):
			var condition = x.substr(x.find("(") + 1, x.find(")") - x.find("(") - 1).strip_edges()
			last_show_if = condition
			continue

		if x.begins_with("# @only_hide_if("):
			var condition = x.substr(x.find("(") + 1, x.find(")") - x.find("(") - 1).strip_edges()
			last_hide_if = condition
			continue

		if x.begins_with("# !@"):
			var group_def = x.substr(4, x.findn("(") - 4).strip_edges()
			if debug: print("UniParticleInspectorPlugin: %s Found toggle group comment: %s" % [group_def, x])
			var properties = get_params(x.substr(x.find("(")))
			if properties.size() > 0:
				var prop_str = properties[0]
				var always_on = group_def.ends_with("!")
				if always_on:
					group_def = group_def.substr(0,group_def.length()-1)
				last_toggle_group = {
					"name": group_def,
					"properties": prop_str.split(","),
					"always_on": always_on
				}
			continue

		if !x.unicode_at(0) in illegal_starts && ("@export " in x || "@export_" in x):
			var prop_name := get_suffix("var ", source, characters_parsed - x.length())
			if prop_name == "": continue

			if last_show_if != "":
				show_if_conditions[prop_name] = last_show_if
				last_show_if = ""

			if last_hide_if != "":
				hide_if_conditions[prop_name] = last_hide_if
				last_hide_if = ""

			if "vector2i" in x.to_lower() and last_toggle_group != null:
				#print("UniParticleInspectorPlugin: Found toggle bool: ", prop_name)
				toggle_groups[prop_name] = last_toggle_group
				if last_toggle_group.get("always_on", false) == true:
					var get_current_eanbled = _current_object.get(prop_name)
					if get_current_eanbled == null or not get_current_eanbled is Vector2i:
						get_current_eanbled = Vector2i.RIGHT
					get_current_eanbled.x = 1
					_current_object.set(prop_name, get_current_eanbled)
				last_toggle_group = null

			parse_found_prop = prop_name.substr(0, prop_name.rfindn("_"))
			if parse_found_comments is Array and (not parse_found_comments.is_empty()) and parse_found_comments[0] is Array and parse_found_comments[0].size() > 1:
				property_groups[prop_name] = {"name": (parse_found_comments[0][0] as String).strip_edges(), "mode_property" : prop_name, "properties": (parse_found_comments[0][1] if parse_found_comments[0][1] is Array else (parse_found_comments[0][1] as String).split(",",false))}
				if property_groups[prop_name].properties is Array and not property_groups[prop_name].properties.is_empty():
					if property_groups[prop_name].properties[0].contains(","):
						property_groups[prop_name].properties = property_groups[prop_name].properties[0].split(",",false)
			parse_found_comments = []

		if x.begins_with("# @@"):
			parse_found_comments.append([x.substr(4, x.findn("(") - 4), get_params(x.substr(x.find("(")))])

func sibling_moved_into_toggle_group_container(node, object):
	#print("Sibling moved %s class %s" % [node, node.get_class()])
	if node is EditorProperty:
		_process_individual_property_with_map(node, object, _property_map)

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint,
		hint_string: String, usage_flags: int, wide: bool) -> bool:
	#if debug: print("UniParticleInspectorPlugin: Parsing property: ", name)

	# Remove the condition check here since we'll handle it in _process_individual_property_with_map

	if name == "bursts":
		if debug: print("UniParticleInspectorPlugin: Creating burst editor")
		var editor = BurstDefinitionsEditor.new()
		editor.edited_object = object
		add_custom_control(editor)
		return true
	# Check if this is a toggle group boolean
	if name in toggle_groups.keys():
		#print("Checking name %s is in toggle groups %s" % [name,toggle_groups])
		var group = toggle_groups[name]

		# Regular toggle group handling continues as before
		var editor = ToggleGroupEditor.new(group.name)
		add_property_editor(name, editor)
		editor.always_on = group.get("always_on",false)
		# Create container for the controlled properties
		var container = ToggleGroupContainer.new()
		container.name = name
		container.always_on = editor.always_on
		container.properties_inside.append_array(group.properties)
		#print("Creating a toggle group for %s new group %s" % [name,container])
		container.put_sibling_inside.connect(sibling_moved_into_toggle_group_container.bind(object))
		var should_be_visible = object.get(name)
		if should_be_visible is bool:
			container.visible = should_be_visible  # Initially hide if toggle is off
		elif should_be_visible is Vector2i:
			container.visible = should_be_visible.x == 1 and should_be_visible.y == 1
		# Store the container reference in the editor
		editor.properties_container = container

		add_custom_control(container)

		return true

	# Check if property is in a toggle group
	for toggle_prop in toggle_groups:
		var group = toggle_groups[toggle_prop]
		if name in group.properties:
			if not object.get(toggle_prop):
				return true
			return false  # Let the property be added normally


	if name in _property_map:
		var group = _property_map[name]
		if name == group.mode_property:
			return true
		var current_mode = object.get(group.mode_property)
		if current_mode == null:
			current_mode = 0
			object.set(group.mode_property, 0)
		#print(current_mode," for name ",name," mode property ",group.mode_property)
		if name == null:
			return false
		var should_show = name in group.properties[current_mode]
		return not should_show

	return false

func _parse_end(object: Object) -> void:
	if not object is UniParticles3D:
		return
	already_called_parse_begin = false
	var dummy = Control.new()
	dummy.custom_minimum_size = Vector2(0, 0)

	var property_map = _property_map

	# Add cleanup on dummy exit
	dummy.tree_exiting.connect(func():
		if debug: print("UniParticleInspectorPlugin: Dummy cleanup")
		if is_instance_valid(dummy.get_parent()):
			var inspector = dummy.get_parent()
			for child in inspector.get_children():
				if child is VBoxContainer:
					_vcontainers.append(child)
	)

	dummy.ready.connect(func():
		if debug: print("UniParticleInspectorPlugin: Dummy ready, processing sections")
		var inspector = dummy.get_parent()
		_process_inspector_sections_with_map(inspector, object, property_map, 0)
		dummy.queue_free()
	)

	add_custom_control(dummy)
	_current_object = null

func _process_inspector_sections_with_map(node: Node, object: Object, property_map: Dictionary, depth: int = 0) -> void:
	# Add maximum depth protection
	if depth > 100:  # Reasonable max depth for inspector
		push_warning("UniParticles3D: Inspector processing exceeded maximum depth")
		return

	# Process only EditorInspectorSection nodes
	if node.get_class() == "EditorInspectorSection" or node.get_class() == "VBoxContainer":
		var vbox = node as VBoxContainer if node is VBoxContainer else (node.get_child(0) if node.get_child_count() > 0 else null)
		if vbox is VBoxContainer:
			_process_section_properties_with_map(vbox, object, property_map)

	# Process children with depth tracking
	for child in node.get_children():
		if child != node:  # Prevent self-recursion
			_process_inspector_sections_with_map(child, object, property_map, depth + 1)

func _process_section_properties_with_map(vbox: VBoxContainer, object: Object, property_map: Dictionary) -> void:
	var i = 0
	var children_to_process = vbox.get_children()  # Get a copy of children array

	while i < children_to_process.size():
		var child = children_to_process[i]

		# Skip processing if the child has been reparented
		if not is_instance_valid(child) or child.get_parent() != vbox:
			i += 1
			continue

		if child is EditorProperty:
			_process_individual_property_with_map(child, object, property_map)

		i += 1

var can_verify_change_show_hide_conditions:bool = true
func reset_can_verify_show_hide_conditions():
	can_verify_change_show_hide_conditions = true
func verify_change_show_hide_if_conditions():
	if not can_verify_change_show_hide_conditions:
		return
	can_verify_change_show_hide_conditions = false
	reset_can_verify_show_hide_conditions.call_deferred()
	#print("Verify show hide if conditions")
	for property in double_check_or_hide_if:
		for objprop in double_check_or_hide_if[property]:
			#print("Verifying... objprop ",objprop," ",objprop is Array and objprop.size() == 2 and objprop[0] != null and objprop[1] != null)
			if objprop is Array and objprop.size() == 2 and objprop[0] != null and objprop[1] != null:
				do_double_check_show_hide(objprop[0], objprop[1])

func do_double_check_show_hide(child, object) -> bool:
	if child == null or object == null:
		return false
	var property = child.get_edited_property()
	#print("Do double check show hide ",property)

	if show_if_conditions != null and property in show_if_conditions:
		#print("Show if conditions not null and property in")
		var condition_prop = show_if_conditions[property]
		if not double_check_or_hide_if.has(condition_prop):
			double_check_or_hide_if[condition_prop] = []
		var already_has:bool = false
		for check_found in double_check_or_hide_if[condition_prop]:
			if check_found[0] == child:
				already_has = true
				break
		if not already_has:
			double_check_or_hide_if[condition_prop].push_back([child,object])

		if not object.get(condition_prop):
			#print("Hdiing cause of show if %s %s" % [child,child.get_edited_property()])
			child.visible = false
			return true
		else:
			child.visible = true
			return true

	# Check hide_if condition
	if hide_if_conditions != null and property in hide_if_conditions:
		var condition_prop = hide_if_conditions[property]
		if not double_check_or_hide_if.has(condition_prop):
			double_check_or_hide_if[condition_prop] = []
		var already_has:bool = false
		for check_found in double_check_or_hide_if[condition_prop]:
			if check_found[0] == child:
				already_has = true
				break
		if not already_has:
			double_check_or_hide_if[condition_prop].push_back([child,object])

		if object.get(condition_prop):
			#print("Hdiing cause of hide if %s %s" % [child,child.get_edited_property()])
			child.visible = false
			return true
		else:
			child.visible = true
			return true

	return false

func _process_individual_property_with_map(child, object: Object, property_map: Dictionary):
	var property = child.get_edited_property()
#, value: Variant, field: StringName, changing: bool,object:EditorProperty):
	next_frame_after_editor_property_list_changed.call_deferred(property, object.get(property), property, false, child)
	# print(property)
	# Check show_if condition

	# Continue with existing property group visibility logic
	if property in property_map:
		var group = property_map[property]
		var current_mode = object.get(group.mode_property)

		# First check if this property should be visible in current mode
		if not (property in group.properties[current_mode]):
			child.visible = false
			return

		# Property should be visible, show it and add the mode selector
		child.visible = true
		var option = OptionButton.new()
		var property_values_names:Array = (group.properties as Array)
		#print(property_values_names)
		for j in property_values_names.size():
			#print("Add item ",property_values_names[j][0])
			var prop_value_name:String = property_values_names[j]
			prop_value_name = prop_value_name.substr(prop_value_name.rfindn("_"))
			option.add_item(prop_value_name.capitalize(), j)
		option.selected = current_mode
		option.custom_minimum_size.x = 20
		option.flat = true
		option.fit_to_longest_item = false
		option.alignment = HORIZONTAL_ALIGNMENT_RIGHT

		option.get_popup().hide_on_checkable_item_selection = false
		option.text = ""

		option.tooltip_text = "Constant/Random/Curve"

		option.item_selected.connect(func(idx):
			object.set(group.mode_property, idx)
			# Reprocess all properties in this container to update visibility
			var container = child.get_parent()
			while container and not container is ToggleGroupContainer:
				container = container.get_parent()
			if container and container is ToggleGroupContainer:
				for prop in container.vbox_container.get_children():
					if prop is EditorProperty:
						_process_individual_property_with_map(prop, object, property_map)

			object.notify_property_list_changed()
		)

		var base_name = property.split("_")[0].capitalize()
		child.label = group.name

		var property_hbox = null
		for prop_child in child.get_children():
			if prop_child is HBoxContainer:
				property_hbox = prop_child
				break

		if property_hbox:
			# print(property_hbox.get_child_count())
			# if property_hbox.get_child_count() > 0:
				# print(property_hbox.get_child(0).get_class())
			if property_hbox and property.ends_with("random") and property_hbox.get_child_count() > 0 and property_hbox.get_child(0) is VBoxContainer:
				for prop_control in property_hbox.get_child(0).get_children():
					# print("Found control: ", prop_control.get_class()," has text? ", &"label" in prop_control)
					if &"label" in prop_control:
						if prop_control.label == "x":
							prop_control.label = "Min "
						elif prop_control.label == "y":
							prop_control.label = "Max "
			var check_already_has: bool = false
			for checking in property_hbox.get_children():
				if checking is OptionButton:
					check_already_has = true
			if not check_already_has:
				property_hbox.add_child(option)
			else:
				option.queue_free.call_deferred()
		else:
			var existing_control = child.get_child(0)
			var enum_width = 20

			existing_control.custom_minimum_size.x = existing_control.custom_minimum_size.x - enum_width

			option.custom_minimum_size.x = enum_width
			option.size_flags_horizontal = Control.SIZE_SHRINK_END

			child.add_child(option)

	do_double_check_show_hide(child, object)

#region BurstDefinitionEditor
class BurstDefinitionsEditor extends VBoxContainer:
	var edited_object: UniParticles3D
	var table_header: HBoxContainer
	var definitions_container: VBoxContainer
	var content_container: VBoxContainer

	func _ready() -> void:
		# Create foldout header
		var header = Button.new()
		header.text = " >   Bursts"
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.toggle_mode = true
		header.button_pressed = false

		var spacer = Control.new()
		spacer.custom_minimum_size.y = 10
		add_child(spacer)

		# Create stylebox for the arrow states
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.15, 0.15, 0.15)
		normal_style.border_color = Color(0.25, 0.25, 0.25)
		normal_style.border_width_bottom = 1
		normal_style.content_margin_left = 20
		header.add_theme_stylebox_override("normal", normal_style)
		header.add_theme_stylebox_override("pressed", normal_style)
		header.add_theme_stylebox_override("hover", normal_style)
		header.add_theme_stylebox_override("hover_pressed", normal_style)

		# Add header to main container
		add_child(header)

		# Create container for table and add button
		content_container = VBoxContainer.new()
		content_container.add_theme_constant_override("separation", 8)
		add_child(content_container)

		# Create main panel
		var panel = PanelContainer.new()
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.12, 0.12, 0.12)
		panel.add_theme_stylebox_override("panel", panel_style)
		content_container.add_child(panel)

		var main_vbox = VBoxContainer.new()
		main_vbox.add_theme_constant_override("separation", 0)
		panel.add_child(main_vbox)

		table_header = HBoxContainer.new()
		table_header.add_theme_constant_override("separation", 0)

		var headers = ["Time", "Count", "Cycles", "Interval", "Probability", ""]
		for i in headers.size():
			var header_panel = PanelContainer.new()

			if headers[i] == "":
				header_panel.custom_minimum_size.x = 30
			else:
				header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.2, 0.2)
			style.border_color = Color(0.25, 0.25, 0.25)
			style.border_width_bottom = 1
			if i < headers.size() - 1:
				style.border_width_right = 1
			header_panel.add_theme_stylebox_override("panel", style)

			var label = Label.new()
			label.text = headers[i]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.custom_minimum_size.y = 24
			if headers[i] == "":
				label.custom_minimum_size.x = 20
			else:
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header_panel.add_child(label)
			table_header.add_child(header_panel)

		main_vbox.add_child(table_header)

		# Create container for definitions
		definitions_container = VBoxContainer.new()
		definitions_container.add_theme_constant_override("separation", 5)
		definitions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_vbox.add_child(definitions_container)

		# Add button
		var add_button = Button.new()
		add_button.text = "Add Burst"
		add_button.pressed.connect(_on_add_pressed)

		content_container.add_child(add_button)

		# Connect header button
		header.pressed.connect(_on_header_toggled)
		_on_header_toggled()
		_refresh_list()

	func _on_header_toggled() -> void:
		var header_button = get_child(1) as Button
		content_container.visible = header_button.button_pressed

		# Update arrow
		header_button.text = " %s   Bursts" % ("⌄" if header_button.button_pressed else ">")
		if header_button.has_theme_stylebox_override("normal"):
			var style = header_button.get_theme_stylebox("normal") as StyleBoxFlat
			style.content_margin_left = 20

	func _create_definition_row(index: int) -> HBoxContainer:
		var base_idx = index * 9
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)

		# Time spinbox
		var time_cell = _create_cell()
		var time_spin = SpinBox.new()
		time_spin.min_value = 0
		time_spin.step = 0.1
		time_spin.value = edited_object.bursts[base_idx]
		time_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		time_spin.value_changed.connect(_on_time_changed.bind(base_idx))
		time_cell.add_child(time_spin)
		row.add_child(time_cell)

		# Count container
		var count_cell = _create_cell()
		var count_container = HBoxContainer.new()
		count_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var count_mode = OptionButton.new()
		count_mode.fit_to_longest_item = false
		count_mode.add_item("Constant")  # Empty text, will only show arrow
		count_mode.add_item("Random")
		count_mode.selected = edited_object.bursts[base_idx + 1]
		count_mode.flat = true
		count_mode.custom_minimum_size.x = 24
		count_mode.tooltip_text = "Constant/Random"
		count_mode.item_selected.connect(_on_count_mode_changed.bind(base_idx))
		count_mode.text = ""
		var count_min = SpinBox.new()
		count_min.min_value = 1
		count_min.value = edited_object.bursts[base_idx + 2]
		count_min.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count_min.value_changed.connect(_on_count_min_changed.bind(base_idx))

		var count_max = SpinBox.new()
		count_max.min_value = 1
		count_max.value = edited_object.bursts[base_idx + 3]
		count_max.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count_max.visible = edited_object.bursts[base_idx + 1] == 1
		count_max.value_changed.connect(_on_count_max_changed.bind(base_idx))

		count_container.add_child(count_min)
		count_container.add_child(count_max)
		count_container.add_child(count_mode)
		count_cell.add_child(count_container)
		row.add_child(count_cell)

		# Cycles container
		var cycles_cell = _create_cell()
		var cycles_container = HBoxContainer.new()
		cycles_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var cycles_mode = OptionButton.new()
		cycles_mode.fit_to_longest_item = false
		cycles_mode.add_item("Constant")  # Empty text, will only show arrow
		cycles_mode.add_item("Random")
		cycles_mode.selected = edited_object.bursts[base_idx + 4]
		cycles_mode.flat = true
		cycles_mode.custom_minimum_size.x = 24
		cycles_mode.tooltip_text = "Constant/Random"
		cycles_mode.item_selected.connect(_on_cycles_mode_changed.bind(base_idx))
		cycles_mode.text = ""
		var cycles_min = SpinBox.new()
		cycles_min.min_value = 1
		cycles_min.value = edited_object.bursts[base_idx + 5]
		cycles_min.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cycles_min.value_changed.connect(_on_cycles_min_changed.bind(base_idx))

		var cycles_max = SpinBox.new()
		cycles_max.min_value = 1
		cycles_max.value = edited_object.bursts[base_idx + 6]
		cycles_max.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cycles_max.visible = edited_object.bursts[base_idx + 4] == 1
		cycles_max.value_changed.connect(_on_cycles_max_changed.bind(base_idx))

		cycles_container.add_child(cycles_min)
		cycles_container.add_child(cycles_max)
		cycles_container.add_child(cycles_mode)
		cycles_cell.add_child(cycles_container)
		row.add_child(cycles_cell)

		# Interval spinbox
		var interval_cell = _create_cell()
		var interval_spin = SpinBox.new()
		interval_spin.min_value = 0
		interval_spin.step = 0.1
		interval_spin.value = edited_object.bursts[base_idx + 7]
		interval_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		interval_spin.value_changed.connect(_on_interval_changed.bind(base_idx))
		interval_cell.add_child(interval_spin)
		row.add_child(interval_cell)

		# Probability spinbox
		var prob_cell = _create_cell()
		var prob_spin = SpinBox.new()
		prob_spin.min_value = 0
		prob_spin.max_value = 1
		prob_spin.step = 0.01
		prob_spin.value = edited_object.bursts[base_idx + 8]
		prob_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prob_spin.value_changed.connect(_on_probability_changed.bind(base_idx))
		prob_cell.add_child(prob_spin)
		row.add_child(prob_cell)

		# Delete button cell
		var del_cell = _create_cell(true)
		var delete_btn = Button.new()
		delete_btn.text = "X"
		delete_btn.modulate = Color(0.6, 0.2, 0.2)
		delete_btn.custom_minimum_size.x = 20
		delete_btn.pressed.connect(_on_remove_pressed.bind(index))
		del_cell.add_child(delete_btn)
		row.add_child(del_cell)

		return row

	func _create_cell(is_last: bool = false) -> PanelContainer:
		var cell = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.15)
		style.border_color = Color(0.25, 0.25, 0.25)
		style.border_width_bottom = 1
		if not is_last:
			style.border_width_right = 1
		cell.add_theme_stylebox_override("panel", style)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 4)
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		cell.add_child(margin)

		return cell

	func _on_add_pressed() -> void:
		# Add 9 new values for the new burst definition
		var new_array = edited_object.bursts.duplicate()
		new_array.append_array([
			0.0,                    # time
			0,                      # count_mode (0=constant, 1=random)
			10,                     # count_min
			10,                     # count_max
			0,                      # cycle_mode (0=constant, 1=random)
			1,                      # cycles_min
			1,                      # cycles_max
			0.0,                    # interval
			1.0                     # probability
		])
		edited_object.bursts = new_array
		_refresh_list()

	func _on_remove_pressed(index: int) -> void:
		var base_idx = index * 9
		# Remove 9 values at once
		for i in range(9):
			edited_object.bursts.remove_at(base_idx)
		_refresh_list()

	# Update value change handlers
	func _on_time_changed(value: float, base_idx: int) -> void:
		edited_object.bursts[base_idx] = value

	func _on_count_mode_changed(mode: int, base_idx: int) -> void:
		edited_object.bursts[base_idx + 1] = mode
		if mode == 0:  # Constant mode
			edited_object.bursts[base_idx + 3] = edited_object.bursts[base_idx + 2]  # Set max = min
		_refresh_list()

	func _on_count_min_changed(value: int, base_idx: int) -> void:
		edited_object.bursts[base_idx + 2] = value
		if edited_object.bursts[base_idx + 1] == 0:  # Constant mode
			edited_object.bursts[base_idx + 3] = value

	func _on_count_max_changed(value: int, base_idx: int) -> void:
		edited_object.bursts[base_idx + 3] = value

	func _on_cycles_mode_changed(mode: int, base_idx: int) -> void:
		edited_object.bursts[base_idx + 4] = mode
		if mode == 0:  # Constant mode
			edited_object.bursts[base_idx + 6] = edited_object.bursts[base_idx + 5]  # Set max = min
		_refresh_list()

	func _on_cycles_min_changed(value: int, base_idx: int) -> void:
		edited_object.bursts[base_idx + 5] = value
		if edited_object.bursts[base_idx + 4] == 0:  # Constant mode
			edited_object.bursts[base_idx + 6] = value

	func _on_cycles_max_changed(value: int, base_idx: int) -> void:
		edited_object.bursts[base_idx + 6] = value

	func _on_interval_changed(value: float, base_idx: int) -> void:
		edited_object.bursts[base_idx + 7] = value

	func _on_probability_changed(value: float, base_idx: int) -> void:
		edited_object.bursts[base_idx + 8] = value

	func _refresh_list() -> void:
		# Clear existing definition controls
		for child in definitions_container.get_children():
			child.queue_free()

		# Add row for each definition
		for i in range(edited_object.bursts.size() / 9):
			definitions_container.add_child(_create_definition_row(i))

#endregion

#region OptionalParametersHelper
func get_suffix(to_find : String, text : String, start_search_at : int = 0) -> String:
	var unclosed_quote := 0
	var unclosed_quote_char := -1
	var unclosed_paren := 0
	var unclosed_brackets := 0
	var unclosed_stache := 0

	var string_chars_matched := 0

	for i in text.length() - start_search_at:
		i += start_search_at
		if unclosed_quote == 1:
			# Ignore all characters inside " " and ' ', until a matching closing mark found.
			if unclosed_quote_char == text.unicode_at(i):
				unclosed_quote = 0

			continue

		match text.unicode_at(i):
			# Opening " ", ' '
			34, 39:
				unclosed_quote = 1
				unclosed_quote_char = text.unicode_at(i)

			40: unclosed_paren += 1
			41: unclosed_paren -= 1
			91: unclosed_brackets += 1
			93: unclosed_brackets -= 1
			123: unclosed_stache += 1
			125: unclosed_stache -= 1
			var other:
				if (
					unclosed_quote == 0 && unclosed_paren == 0
					&& unclosed_brackets == 0 && unclosed_stache == 0
					&& other == to_find.unicode_at(string_chars_matched)
				):
					string_chars_matched += 1
					if string_chars_matched == to_find.length():
						var result := text.substr(i + 1, text.find(" ", i + 1) - i - 1)
						if result.ends_with(":"):
							result = result.trim_suffix(":")
						return result

				else:
					string_chars_matched = 0

	return ""


func get_params(string : String):
	var unclosed_paren := 0
	var unclosed_quote := 0
	var unclosed_brackets := 0
	var unclosed_stache := 0

	var param_start = 0
	var param_started = false
	var params = []

	# Skip to first opening parenthesis
	var paren_start = string.find("(")
	if paren_start == -1:
		return []

	# Get the content between parentheses
	var paren_end = string.find(")", paren_start)
	if paren_end == -1:
		return []

	# Get the content and trim whitespace
	var content = string.substr(paren_start + 1, paren_end - paren_start - 1).strip_edges()

	# Just split by comma - we don't need the complex parsing for this case
	if content.length() > 0:
		params = [content]

	return params

#endregion

# Add this new class at the top of the file
class ToggleGroupEditor extends EditorProperty:
	var checkbox: CheckBox
	var panel: PanelContainer
	var always_on:bool = false
	var toggle_label: Label
	var updating: bool = false

	const draw_label_property:= &"draw_label"

	var properties_container: ToggleGroupContainer
	func _init(toggle_name: String):
		# Create panel for visual grouping
		panel = PanelContainer.new()
		#print("Creating stylebox")
		#theme = EditorInterface.get_editor_theme()
		panel.ready.connect(panel_ready)
		panel.gui_input.connect(_on_panel_input)

		if draw_label_property in self:
			set(draw_label_property,false)
		else:
			label = ""

		checkable = true
		var hbox = HBoxContainer.new()
		panel.add_child(hbox)

		var spacer := Control.new()
		spacer.custom_minimum_size.x = 8
		hbox.add_child(spacer)

		# Create checkbox
		checkbox = CheckBox.new()
		checkbox.text = ""
		hbox.add_child(checkbox)

		# Create label
		toggle_label = Label.new()
		toggle_label.text = toggle_name
		hbox.add_child(toggle_label)

		if has_method(&"set_label_reference"):
			call(&"set_label_reference",toggle_label)

		# Add panel as child of property editor
		add_child(panel)
		# Make sure the control is able to retain the focus.
		add_focusable(checkbox)
		# Connect to checkbox changes
		checkbox.toggled.connect(_on_toggle)

		# Make the panel take up full width
		#set_bottom_editor(panel)

	func panel_ready():
		var duplicate_stylebox: StyleBoxFlat = get_theme_stylebox("bg", "EditorInspectorCategory").duplicate()
		#duplicate_stylebox.draw_center = true
		duplicate_stylebox.bg_color = get_theme_color("prop_category", "Editor").lightened(0.02)
		duplicate_stylebox.border_color = duplicate_stylebox.bg_color.lightened(0.04)
		panel.add_theme_stylebox_override("panel", duplicate_stylebox)
		toggle_label.add_theme_font_override("font",get_theme_font("font", "HeaderMedium"))

		if always_on:
			checkbox.self_modulate = Color.TRANSPARENT
			checkbox.button_pressed = true
			checkbox.focus_mode = Control.FOCUS_NONE
			checkbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var container_panel = properties_container.get_theme_stylebox("panel")
		container_panel.bg_color = duplicate_stylebox.bg_color.darkened(0.12)

	func _on_panel_input(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var current_value = get_edited_object()[get_edited_property()]
			if current_value is bool or current_value == null:
				current_value = Vector2i.ZERO
			if current_value.x > 0:  # Only toggle visibility if enabled
				current_value.y = 1 - current_value.y  # Toggle visibility
				emit_changed(get_edited_property(), current_value)
				_update_visibility(current_value)

	func _update_visibility(value: Vector2i):
		if properties_container:
			properties_container.visible = value.x > 0  # Show if enabled
			properties_container.content_visible = value.y > 0  # Show content if expanded

	func _update_property():
		label = "                 "
		var new_value = get_edited_object()[get_edited_property()]
		if new_value == null:
			new_value = Vector2i.ZERO
		if new_value is bool:
			new_value = Vector2i.ZERO
		if always_on and new_value.x != 1:
			new_value.x = 1
			checkbox.button_pressed = true
		if new_value.x != int(checkbox.button_pressed):
			var was_updating:bool = updating
			if not was_updating:
				updating = true
			checkbox.button_pressed = new_value.x > 0
			if not was_updating:
				updating = false
		toggle_label.modulate = Color(1, 1, 1, 1 if new_value.x > 0 else 0.3)
		panel.self_modulate = Color(1, 1, 1, 1 if new_value.x > 0 else 0.4)
		_update_visibility(new_value)

	func _on_toggle(pressed: bool):
		if updating:
			return
		updating = true

		var current_value = get_edited_object()[get_edited_property()]
		if current_value is bool or current_value == null:
			current_value = Vector2i.ZERO
		current_value.x = 1 if pressed else 0
		current_value.y = 1 if pressed else 0  # Expand when enabling

		emit_changed(get_edited_property(), current_value)
		toggle_label.modulate = Color(1, 1, 1, 1 if pressed else 0.5)
		panel.modulate = Color(1, 1, 1, 1 if pressed else 0.5)
		_update_visibility(current_value)

		# Notify property list changed to update visibility
		get_edited_object().notify_property_list_changed()

		updating = false

# Add this new class
class ToggleGroupContainer extends PanelContainer:
	var vbox_container: VBoxContainer
	var margin_cont: MarginContainer
	var always_on:bool = false
	var properties_inside:Array[String] = []
	var content_visible: bool = true:
		set(value):
			content_visible = value
			if margin_cont:
				margin_cont.visible = value
	signal put_sibling_inside(sibling)

	func _init():
		# Set up the panel styling
		var stylebox = StyleBoxFlat.new()
		stylebox.content_margin_left = 8
		stylebox.content_margin_right = 8
		stylebox.content_margin_top = 4
		stylebox.content_margin_bottom = 4
		add_theme_stylebox_override("panel", stylebox)
		margin_cont = MarginContainer.new()
		add_child(margin_cont)  # Remove deferred call
		margin_cont.add_theme_constant_override("margin_bottom", 5)
		margin_cont.add_theme_constant_override("margin_left", 5)
		margin_cont.add_theme_constant_override("margin_right", 5)
		margin_cont.add_theme_constant_override("margin_top", 5)
		vbox_container = VBoxContainer.new()
		margin_cont.add_child(vbox_container)  # Remove deferred call

		# Wait one frame before moving siblings
		call_deferred("attempt_put_others_inside")

	func attempt_put_others_inside():
		var parent = get_parent()
		if not parent:
			return

		var siblings = []
		# Collect valid siblings until we hit another toggle group or category
		for sibling in parent.get_children():
			if sibling == self or sibling.get_parent() == self:
				continue
			#print("%s Checking if should add %s ... should? %s" % [name, sibling.get_edited_property() if (sibling is EditorProperty) else "??", not ((not sibling is EditorProperty) or not sibling.get_edited_property() in properties_inside)])
			if (sibling is BurstDefinitionsEditor) and "emission_type" in properties_inside:
				siblings.append(sibling)
				continue
			if (not sibling is EditorProperty) or not sibling.get_edited_property() in properties_inside:
				continue
			## Stop when we hit another toggle group or category
			#if sibling is ToggleGroupContainer or sibling.get_class() == "EditorInspectorSection":
				#break

			siblings.append(sibling)
		#if siblings.is_empty():
			#print("%s EMPTY! Should have added %s" % [name, properties_inside])
		# Move collected siblings
		for sibling in siblings:
			sibling.reparent(vbox_container)

			put_sibling_inside.emit(sibling)
