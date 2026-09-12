extends Node

# Screenshot-driven layout safety net for all UI2 screens. It keeps screen
# headers compact even when global readability/theme runtimes touch controls.
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
	_next_scan = now + 300
	_scan()

func _scan_node(node: Node) -> void:
	if node is VBoxContainer and String(node.name).ends_with("UI2"):
		_fix_screen(node as VBoxContainer)
	for child in node.get_children():
		_scan_node(child)

func _fix_screen(root: VBoxContainer) -> void:
	if root.get_child_count() == 0:
		return
	var first := root.get_child(0)
	if first is HBoxContainer:
		var bar := first as HBoxContainer
		bar.custom_minimum_size.y = 62
		bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		for child in bar.get_children():
			if child is Control:
				(child as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if child is Button and String((child as Button).text).contains("CONTINUE"):
				var button := child as Button
				button.custom_minimum_size = Vector2(150, 42)
				button.size_flags_horizontal = Control.SIZE_SHRINK_END
				button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			elif child is VBoxContainer and not String(child.name).contains("Title"):
				(child as Control).custom_minimum_size.x = maxf((child as Control).custom_minimum_size.x, 96.0)
	match String(root.name):
		"DashboardUI2":
			_fix_dashboard(root)
		"TacticsUI2":
			_fix_tactics(root)
		_:
			pass
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _fix_dashboard(root: VBoxContainer) -> void:
	for child in root.get_children():
		if child is HBoxContainer:
			var row := child as HBoxContainer
			var panels: Array[Control] = []
			for item in row.get_children():
				if item is PanelContainer:
					panels.append(item as Control)
			if panels.size() >= 4:
				for panel in panels:
					panel.custom_minimum_size.x = minf(panel.custom_minimum_size.x, 205.0)

func _fix_tactics(root: VBoxContainer) -> void:
	for child in root.get_children():
		if child is HBoxContainer:
			var row := child as HBoxContainer
			var panels: Array[Control] = []
			for item in row.get_children():
				if item is PanelContainer:
					panels.append(item as Control)
			if panels.size() == 2:
				panels[0].custom_minimum_size.x = minf(panels[0].custom_minimum_size.x, 560.0)
				panels[1].custom_minimum_size.x = minf(panels[1].custom_minimum_size.x, 300.0)
	_cap_wide_controls(root)

func _cap_wide_controls(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if control.custom_minimum_size.x >= 600.0:
				control.custom_minimum_size.x = 540.0
		_cap_wide_controls(child)
