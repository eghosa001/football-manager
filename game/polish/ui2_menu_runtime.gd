extends Node

const UI = preload("res://game/presentation/fd_ui2.gd")
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
	box.add_theme_constant_override("separation", 14)
	var width := 760.0 if title in ["Settings", "New Career"] else 560.0
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
			button.custom_minimum_size = Vector2(440 if title == "FOOTBALL DYNASTY" else width, 46)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		elif child is HBoxContainer or child is GridContainer or child is MarginContainer:
			control.custom_minimum_size.x = width
		elif child is LineEdit or child is OptionButton or child is HSlider or child is SpinBox or child is CheckBox:
			control.custom_minimum_size.x = width
	_style_named_page(box, title)

func _style_named_page(box: VBoxContainer, title: String) -> void:
	var first_label := _first_label(box)
	if first_label != null:
		first_label.add_theme_color_override("font_color", UI.TEXT)
		first_label.add_theme_font_size_override("font_size", 32 if title == "FOOTBALL DYNASTY" else 26)
	if title == "FOOTBALL DYNASTY":
		for child in box.get_children():
			if child is Button:
				var button := child as Button
				if String(button.text) in ["New Career", "Resume Career"]:
					_apply_accent(button, UI.CYAN)
				elif String(button.text) == "Load Career":
					_apply_accent(button, UI.PURPLE)
	elif title == "New Career":
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
