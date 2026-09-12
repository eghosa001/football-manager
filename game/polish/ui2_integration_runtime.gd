extends Node

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

	# The screenshots showed the legacy horizontal TabContainer still exposed.
	# Force the production navigation shell even when NavigationRuntime's
	# script-path based discovery misses the CareerApp instance.
	if not bool(tabs.get_meta("career_navigation_shell", false)):
		NavigationRuntime.wire_tabs(tabs)
	tabs.tabs_visible = false
	tabs.set_meta("ui2_active", true)
	tabs.set_meta("dashboard_complete", true)
	tabs.set_meta("advanced_squad_tools", true)
	tabs.set_meta("tactics_board_added", true)
	tabs.set_meta("individual_training_added", true)

	# Call the proven UI2 builders directly with the resolved session. This
	# removes the remaining dependency on internal ancestor/script-path lookup.
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

	_style_visible_shell(tabs)

func _style_visible_shell(tabs: TabContainer) -> void:
	var shell: Node = tabs.get_parent()
	if shell == null or shell.has_meta("ui2_reference_shell"):
		return
	shell.set_meta("ui2_reference_shell", true)

	var sidebar: Node = shell.get_node_or_null("CareerSidebar")
	if sidebar is Control:
		var sidebar_control: Control = sidebar as Control
		sidebar_control.custom_minimum_size.x = 196
		sidebar_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if sidebar != null:
		for child_node: Node in sidebar.get_children():
			if child_node is Button:
				var button: Button = child_node as Button
				button.custom_minimum_size.y = 34
				button.add_theme_font_size_override("font_size", 12)
				button.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94, 1.0))
				button.add_theme_color_override("font_hover_color", Color.WHITE)
				button.add_theme_color_override("font_pressed_color", Color(0.10, 0.92, 0.95, 1.0))

	# Keep the old global career controls functional for now, but visually make
	# the actual career workspace dominant instead of the legacy tab strip.
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL

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
