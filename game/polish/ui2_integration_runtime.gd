extends Node

const UI = preload("res://game/presentation/fd_ui2.gd")

# Runtime bridge that guarantees the UI2 presentation actually replaces the
# legacy career tab layouts. This deliberately bypasses fragile script-path
# discovery and resolves the live CareerApp/session by capabilities instead.

var _next_scan: int = 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 250
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer:
		var tabs: TabContainer = node as TabContainer
		if _looks_like_career_tabs(tabs):
			_force_ui2(tabs)
	for child_node: Node in node.get_children():
		_scan_node(child_node)

func _looks_like_career_tabs(tabs: TabContainer) -> bool:
	return _tab_index(tabs, "Dashboard") >= 0 and _tab_index(tabs, "Squad") >= 0 and _tab_index(tabs, "Tactics") >= 0

func _force_ui2(tabs: TabContainer) -> void:
	var app: Node = _career_app(tabs)
	if app == null:
		return
	var session_value: Variant = app.get("session")
	if session_value == null or not session_value is Object:
		return
	var session: Object = session_value as Object
	var world_value: Variant = session.get("world")
	if typeof(world_value) != TYPE_DICTIONARY:
		return
	var world: Dictionary = world_value
	if world.is_empty():
		return

	if not bool(tabs.get_meta("career_navigation_shell", false)):
		NavigationRuntime.wire_tabs(tabs)
	tabs.tabs_visible = false
	tabs.set_meta("ui2_active", true)
	tabs.set_meta("dashboard_complete", true)
	tabs.set_meta("advanced_squad_tools", true)
	tabs.set_meta("tactics_board_added", true)
	tabs.set_meta("individual_training_added", true)

	UI2Runtime.call("_enhance_shell", tabs, session)
	UI2Runtime.call("_build_home", _page(tabs, "Dashboard"), tabs, session)
	UI2Runtime.call("_build_squad", _page(tabs, "Squad"), tabs, session)
	UI2Runtime.call("_build_tactics", _page(tabs, "Tactics"), tabs, session)

	UI2ExtendedRuntime.call("_build_training", _page(tabs, "Training"), tabs, session)
	UI2ExtendedRuntime.call("_build_scouting", _page(tabs, "Scouting"), tabs, session)
	UI2ExtendedRuntime.call("_build_finances", _page(tabs, "Finances"), tabs, session)
	UI2ExtendedRuntime.call("_build_transfers", _page(tabs, "Transfers"), tabs, session)
	UI2ExtendedRuntime.call("_build_medical", _page(tabs, "Medical"), tabs, session)
	UI2ExtendedRuntime.call("_build_competitions", _page(tabs, "Competitions"), tabs, session)
	UI2ExtendedRuntime.call("_build_schedule", _page(tabs, "Schedule"), tabs, session)

	_style_visible_shell(tabs, app)

func _style_visible_shell(tabs: TabContainer, app: Node) -> void:
	var shell: Node = tabs.get_parent()
	if shell == null or shell.has_meta("ui2_reference_shell"):
		return
	shell.set_meta("ui2_reference_shell", true)

	var career_root: Node = shell.get_parent()
	if career_root != null:
		for sibling: Node in career_root.get_children():
			if sibling != shell and sibling is CanvasItem:
				(sibling as CanvasItem).visible = false

	var mobile: bool = bool(tabs.get_meta("career_navigation_mobile", false))
	if mobile:
		_add_mobile_commands(career_root, shell, app)
	else:
		_style_desktop_sidebar(shell, app)

	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _style_desktop_sidebar(shell: Node, app: Node) -> void:
	var sidebar: Node = shell.get_node_or_null("CareerSidebar")
	if not sidebar is VBoxContainer:
		return
	var sidebar_box: VBoxContainer = sidebar as VBoxContainer
	sidebar_box.custom_minimum_size.x = 196
	sidebar_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for child_node: Node in sidebar_box.get_children():
		if child_node is Button:
			_style_navigation_button(child_node as Button)

	var spacer := Control.new()
	spacer.name = "UI2NavigationSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_box.add_child(spacer)

	var divider := HSeparator.new()
	divider.modulate = Color(1.0, 1.0, 1.0, 0.10)
	sidebar_box.add_child(divider)

	var utility_label := Label.new()
	utility_label.text = "CAREER"
	utility_label.add_theme_font_size_override("font_size", 10)
	utility_label.add_theme_color_override("font_color", UI.MUTED)
	sidebar_box.add_child(utility_label)

	_add_utility_button(sidebar_box, "SAVE", func() -> void: _save_current(app))
	_add_utility_button(sidebar_box, "SAVE AS", func() -> void: app.call("_show_save_as"))
	_add_utility_button(sidebar_box, "SETTINGS", func() -> void: app.call("_show_settings"))
	_add_utility_button(sidebar_box, "MAIN MENU", func() -> void: app.call("_show_main_menu"))

func _style_navigation_button(button: Button) -> void:
	if not bool(button.get_meta("ui2_iconified", false)):
		var target: String = String(button.get_meta("target_tab", ""))
		var icon: String = _nav_icon(target)
		if icon != "":
			button.text = "%s   %s" % [icon, button.text]
		button.set_meta("ui2_iconified", true)
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", UI.CYAN)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	normal.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.10, 0.12, 0.19, 0.86)
	hover.set_corner_radius_all(5)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(UI.CYAN.r, UI.CYAN.g, UI.CYAN.b, 0.14)
	pressed.border_color = UI.CYAN
	pressed.border_width_left = 3
	pressed.set_corner_radius_all(5)
	button.add_theme_stylebox_override("pressed", pressed)

func _nav_icon(target: String) -> String:
	match target:
		"Dashboard": return "⌂"
		"Inbox": return "✉"
		"Squad": return "●"
		"Dynamics": return "↔"
		"Tactics": return "◇"
		"Training": return "▲"
		"Medical": return "+"
		"Schedule": return "□"
		"Competitions": return "★"
		"Scouting": return "⌕"
		"Transfers": return "⇄"
		"Staff": return "◌"
		"Finances": return "$"
		"Club": return "◆"
		"World History": return "◎"
		"Match Analysis": return "∿"
		"Data Hub": return "▦"
		"Board": return "▣"
		_: return ""

func _add_utility_button(parent: VBoxContainer, title: String, callback: Callable) -> void:
	var button: Button = UI.action(title, Color(0.25, 0.32, 0.48, 1.0))
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(callback)
	parent.add_child(button)

func _add_mobile_commands(career_root: Node, shell: Node, app: Node) -> void:
	if career_root == null or not career_root is VBoxContainer:
		return
	var root_box: VBoxContainer = career_root as VBoxContainer
	if root_box.get_node_or_null("UI2MobileCommandBar") != null:
		return
	var bar := HBoxContainer.new()
	bar.name = "UI2MobileCommandBar"
	bar.add_theme_constant_override("separation", 6)
	root_box.add_child(bar)
	root_box.move_child(bar, maxi(0, shell.get_index()))
	var save: Button = UI.action("SAVE", UI.CYAN)
	save.pressed.connect(func() -> void: _save_current(app))
	bar.add_child(save)
	var settings: Button = UI.action("SETTINGS", UI.PURPLE)
	settings.pressed.connect(func() -> void: app.call("_show_settings"))
	bar.add_child(settings)
	var menu: Button = UI.action("MENU", Color(0.30, 0.34, 0.44, 1.0))
	menu.pressed.connect(func() -> void: app.call("_show_main_menu"))
	bar.add_child(menu)

func _save_current(app: Node) -> void:
	var slot: int = int(app.get("active_slot"))
	if slot > 0:
		app.call("_save_to_slot", slot)
	else:
		app.call("_show_save_as")

func _career_app(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"):
			return current
		current = current.get_parent()
	return null

func _page(tabs: TabContainer, name: String) -> Control:
	var index: int = _tab_index(tabs, name)
	if index < 0:
		return null
	return tabs.get_tab_control(index)

func _tab_index(tabs: TabContainer, name: String) -> int:
	for i: int in range(tabs.get_tab_count()):
		var page: Control = tabs.get_tab_control(i)
		if String(page.name) == name or tabs.get_tab_title(i) == name:
			return i
	return -1
