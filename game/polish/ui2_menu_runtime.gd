extends Node

const UI = preload("res://game/presentation/fd_ui2.gd")
const LandingArt = preload("res://game/presentation/landing_art.gd")

var _next_scan: int = 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _scan() -> void:
	_scan_node(get_tree().root)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 350
	_scan()

func _scan_node(node: Node) -> void:
	if node is VBoxContainer:
		_try_style_page(node as VBoxContainer)
	for child in node.get_children():
		_scan_node(child)

func _try_style_page(box: VBoxContainer) -> void:
	if box.has_meta("ui2_menu_styled") or _contains_career_tabs(box):
		return
	var title := _page_title(box)
	if title not in ["FOOTBALL DYNASTY", "Settings", "Your first season", "Load Career", "New Career"]:
		return
	box.set_meta("ui2_menu_styled", true)
	if title == "FOOTBALL DYNASTY":
		_build_landing_screen(box)
		return
	_style_secondary_page(box, title)

func _build_landing_screen(source_box: VBoxContainer) -> void:
	var screen := _screen_root(source_box)
	if screen == null or screen.has_node("FDLandingScreen"):
		return

	var actions := _collect_actions(source_box)
	if not actions.has("New Career"):
		return

	# Keep the original controls alive as the source of truth for callbacks,
	# but replace their developer-menu presentation with a designed cover screen.
	source_box.visible = false

	var landing := Control.new()
	landing.name = "FDLandingScreen"
	landing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	landing.mouse_filter = Control.MOUSE_FILTER_PASS
	screen.add_child(landing)

	var art := LandingArt.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	landing.add_child(art)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 68)
	safe.add_theme_constant_override("margin_right", 58)
	safe.add_theme_constant_override("margin_top", 54)
	safe.add_theme_constant_override("margin_bottom", 42)
	landing.add_child(safe)

	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	safe.add_child(columns)

	var copy := VBoxContainer.new()
	copy.custom_minimum_size.x = 500
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 10)
	columns.add_child(copy)

	var eyebrow := Label.new()
	eyebrow.text = "THE BEAUTIFUL GAME. YOUR DECISIONS."
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", UI.CYAN)
	copy.add_child(eyebrow)

	var title := Label.new()
	title.text = "FOOTBALL\nDYNASTY"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("f7f9fc"))
	title.add_theme_constant_override("line_spacing", -8)
	copy.add_child(title)

	var rule := ColorRect.new()
	rule.color = UI.CYAN
	rule.custom_minimum_size = Vector2(76, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	copy.add_child(rule)

	var subtitle := Label.new()
	subtitle.text = "Build a club. Shape careers. Define an era."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.83, 0.90, 1.0))
	copy.add_child(subtitle)

	var description := Label.new()
	description.text = "Every selection, signing and tactical call becomes part of your football story."
	description.custom_minimum_size.x = 430
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color(0.55, 0.63, 0.72, 1.0))
	copy.add_child(description)

	var gap := Control.new()
	gap.custom_minimum_size.y = 22
	copy.add_child(gap)

	var primary_name := "Resume Career" if actions.has("Resume Career") else "New Career"
	var primary := _landing_button(primary_name, true)
	primary.pressed.connect(_forward_action.bind(actions[primary_name]))
	copy.add_child(primary)

	var career_row := HBoxContainer.new()
	career_row.add_theme_constant_override("separation", 10)
	copy.add_child(career_row)
	if primary_name != "New Career":
		var new_career := _landing_button("New Career", false)
		new_career.pressed.connect(_forward_action.bind(actions["New Career"]))
		career_row.add_child(new_career)
	if actions.has("Load Career"):
		var load_career := _landing_button("Load Career", false)
		load_career.pressed.connect(_forward_action.bind(actions["Load Career"]))
		career_row.add_child(load_career)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.add_child(spacer)

	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 6)
	copy.add_child(secondary)
	for action_name in ["Settings", "Club database editor", "How to play", "Quit"]:
		if not actions.has(action_name):
			continue
		var compact := _secondary_button(_secondary_label(action_name))
		compact.tooltip_text = action_name
		compact.pressed.connect(_forward_action.bind(actions[action_name]))
		secondary.add_child(compact)

	var footer := Label.new()
	footer.text = "FOOTBALL DYNASTY  •  CAREER SIMULATION"
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(0.38, 0.47, 0.57, 1.0))
	copy.add_child(footer)

	var visual_space := Control.new()
	visual_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(visual_space)

	var identity := VBoxContainer.new()
	identity.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	identity.position = Vector2(-275, -128)
	identity.size = Vector2(240, 90)
	identity.add_theme_constant_override("separation", 2)
	landing.add_child(identity)
	var label := Label.new()
	label.text = "WELCOME TO MATCHDAY"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UI.CYAN)
	identity.add_child(label)
	var line := Label.new()
	line.text = "YOUR CLUB. YOUR WORLD."
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_theme_font_size_override("font_size", 18)
	line.add_theme_color_override("font_color", Color("f4f7fb"))
	identity.add_child(line)

func _landing_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text.to_upper()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(214 if not primary else 390, 54 if primary else 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 15 if primary else 13)
	button.add_theme_color_override("font_color", Color("f7fbff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.085, 0.13, 0.92) if not primary else Color(0.04, 0.56, 0.60, 0.96)
	normal.border_color = Color(0.16, 0.32, 0.40, 0.92) if not primary else Color(0.35, 0.96, 0.96, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.07, 0.16, 0.22, 0.98) if not primary else Color(0.05, 0.69, 0.71, 1.0)
	hover.border_color = UI.CYAN
	button.add_theme_stylebox_override("hover", hover)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.03, 0.39, 0.44, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)
	var focus := hover.duplicate()
	focus.border_color = Color.WHITE
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	return button

func _secondary_button(text: String) -> Button:
	var button := Button.new()
	button.text = text.to_upper()
	button.custom_minimum_size = Vector2(88, 34)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color(0.65, 0.72, 0.80, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.055, 0.085, 0.74)
	normal.border_color = Color(0.16, 0.25, 0.32, 0.75)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.05, 0.13, 0.17, 0.95)
	hover.border_color = UI.CYAN
	button.add_theme_stylebox_override("hover", hover)
	return button

func _secondary_label(action_name: String) -> String:
	match action_name:
		"Club database editor": return "Database"
		"How to play": return "Guide"
		_: return action_name

func _forward_action(source: Button) -> void:
	if is_instance_valid(source):
		source.emit_signal("pressed")

func _collect_actions(box: VBoxContainer) -> Dictionary:
	var actions: Dictionary = {}
	for child in box.get_children():
		if child is Button:
			var button := child as Button
			var key := String(button.text).strip_edges()
			if key != "" and not actions.has(key):
				actions[key] = button
	return actions

func _screen_root(node: Node) -> Control:
	var cursor: Node = node
	var candidate: Control = null
	while cursor != null and not cursor is Viewport:
		if cursor is Control:
			candidate = cursor as Control
		cursor = cursor.get_parent()
	return candidate

func _style_secondary_page(box: VBoxContainer, title: String) -> void:
	box.add_theme_constant_override("separation", 14)
	var width := 760.0 if title in ["Settings", "New Career"] else 640.0
	var seen_buttons: Dictionary = {}
	for child in box.get_children():
		if not child is Control:
			continue
		var control := child as Control
		control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if child is Label:
			var label := child as Label
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.custom_minimum_size.x = width
		elif child is Button:
			var button := child as Button
			var key := String(button.text).strip_edges()
			if key != "" and seen_buttons.has(key):
				button.visible = false
				continue
			seen_buttons[key] = true
			button.custom_minimum_size = Vector2(width, 46)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_style_form_button(button)
		elif child is HBoxContainer or child is GridContainer or child is MarginContainer:
			control.custom_minimum_size.x = width
		elif child is LineEdit or child is OptionButton or child is HSlider or child is SpinBox or child is CheckBox:
			control.custom_minimum_size.x = width
	_style_named_page(box, title)

func _style_form_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.045, 0.075, 0.11, 0.96)
	normal.border_color = Color(0.14, 0.23, 0.31, 0.95)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.border_color = UI.CYAN
	hover.bg_color = Color(0.055, 0.12, 0.15, 1.0)
	button.add_theme_stylebox_override("hover", hover)

func _style_named_page(box: VBoxContainer, title: String) -> void:
	var first_label := _first_label(box)
	if first_label != null:
		first_label.add_theme_color_override("font_color", UI.TEXT)
		first_label.add_theme_font_size_override("font_size", 30 if title == "New Career" else 27)
	if title == "New Career":
		for child in box.get_children():
			if child is HBoxContainer:
				for nested in child.get_children():
					if nested is Button and String((nested as Button).text) == "Create Career":
						_apply_accent(nested as Button, UI.CYAN)

func _apply_accent(button: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color.r, color.g, color.b, 0.22)
	normal.border_color = Color(color.r, color.g, color.b, 0.75)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", normal)

func _page_title(box: VBoxContainer) -> String:
	var label := _first_label(box)
	return String(label.text) if label != null else ""

func _first_label(box: VBoxContainer) -> Label:
	for child in box.get_children():
		if child is Label:
			return child as Label
	return null

func _contains_career_tabs(node: Node) -> bool:
	for child in node.get_children():
		if child is TabContainer:
			var tabs := child as TabContainer
			for i in range(tabs.get_tab_count()):
				if String(tabs.get_tab_control(i).name) == "Dashboard":
					return true
		if _contains_career_tabs(child):
			return true
	return false
