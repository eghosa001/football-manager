extends Node

const NAV_ITEMS := [
	{"label":"Home","tab":"Dashboard"},
	{"label":"Inbox","tab":"Inbox"},
	{"label":"Squad","tab":"Squad"},
	{"label":"Dynamics","tab":"Dynamics"},
	{"label":"Tactics","tab":"Tactics"},
	{"label":"Training","tab":"Training"},
	{"label":"Medical","tab":"Medical"},
	{"label":"Schedule","tab":"Schedule"},
	{"label":"Competitions","tab":"Competitions"},
	{"label":"Scouting","tab":"Scouting"},
	{"label":"Transfers","tab":"Transfers"},
	{"label":"Staff","tab":"Staff"},
	{"label":"Finances","tab":"Finances"},
	{"label":"Club","tab":"Club"},
	{"label":"World","tab":"World History"},
]
const SECONDARY_ITEMS := ["Search", "Match Analysis", "Save Policy", "Board", "Data Hub"]

var _next_scan := 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 700
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer:
		_wire(node)
	for child in node.get_children():
		_scan_node(child)

func _wire(tabs: TabContainer) -> void:
	if tabs.has_meta("career_navigation_shell"):
		_refresh_navigation(tabs)
		return
	if not _looks_like_career_tabs(tabs):
		return
	wire_tabs(tabs)

# Public for deterministic UI regression tests. Production callers omit the
# override and use the platform feature reported by Godot.
func wire_tabs(tabs: TabContainer, mobile_override: Variant = null) -> void:
	if tabs == null or tabs.has_meta("career_navigation_shell"):
		return
	var parent := tabs.get_parent()
	if parent == null or not parent is Container:
		return
	var mobile := OS.has_feature("mobile") if mobile_override == null else bool(mobile_override)
	var index := tabs.get_index()
	var shell: Container
	if mobile:
		shell = VBoxContainer.new()
		shell.name = "CareerNavigationShell"
		var selector := OptionButton.new()
		selector.name = "CareerMobileNavigation"
		selector.custom_minimum_size.y = 48
		selector.focus_mode = Control.FOCUS_ALL
		shell.add_child(selector)
		selector.item_selected.connect(_mobile_selected.bind(tabs, selector))
	else:
		shell = HBoxContainer.new()
		shell.name = "CareerNavigationShell"
		(shell as HBoxContainer).add_theme_constant_override("separation", 12)
		var sidebar := VBoxContainer.new()
		sidebar.name = "CareerSidebar"
		sidebar.custom_minimum_size.x = 168
		sidebar.add_theme_constant_override("separation", 4)
		shell.add_child(sidebar)

	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.remove_child(tabs)
	parent.add_child(shell)
	parent.move_child(shell, mini(index, parent.get_child_count() - 1))
	tabs.tabs_visible = false
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(tabs)
	tabs.set_meta("career_navigation_shell", true)
	tabs.set_meta("career_navigation_mobile", mobile)
	tabs.tab_changed.connect(_sync_active.bind(tabs))
	_refresh_navigation(tabs)

func _refresh_navigation(tabs: TabContainer) -> void:
	if bool(tabs.get_meta("career_navigation_mobile", false)):
		_refresh_mobile_selector(tabs)
	else:
		_refresh_sidebar(tabs)
	_sync_active(tabs.current_tab, tabs)

func _refresh_mobile_selector(tabs: TabContainer) -> void:
	var shell := tabs.get_parent()
	if shell == null:
		return
	var selector := shell.get_node_or_null("CareerMobileNavigation") as OptionButton
	if selector == null:
		return
	var current_name := ""
	if tabs.current_tab >= 0 and tabs.current_tab < tabs.get_tab_count():
		current_name = String(tabs.get_child(tabs.current_tab).name)
	selector.clear()
	for item in NAV_ITEMS:
		var tab_name := String(item.tab)
		var tab_index := _tab_index(tabs, tab_name)
		if tab_index < 0:
			continue
		selector.add_item(tr(String(item.label)))
		selector.set_item_metadata(selector.item_count - 1, tab_name)
	for secondary in SECONDARY_ITEMS:
		var tab_index := _tab_index(tabs, secondary)
		if tab_index < 0:
			continue
		selector.add_item(tr(secondary))
		selector.set_item_metadata(selector.item_count - 1, secondary)
	for i in range(selector.item_count):
		if String(selector.get_item_metadata(i)) == current_name:
			selector.select(i)
			break

func _mobile_selected(item_index: int, tabs: TabContainer, selector: OptionButton) -> void:
	if item_index < 0 or item_index >= selector.item_count:
		return
	_open_tab(tabs, String(selector.get_item_metadata(item_index)))

func _refresh_sidebar(tabs: TabContainer) -> void:
	var shell := tabs.get_parent()
	if shell == null:
		return
	var sidebar := shell.get_node_or_null("CareerSidebar") as VBoxContainer
	if sidebar == null:
		return
	var existing := {}
	for child in sidebar.get_children():
		if child is Button:
			existing[String(child.get_meta("target_tab", ""))] = child
	for item in NAV_ITEMS:
		var tab_name := String(item.tab)
		if _tab_index(tabs, tab_name) < 0 or existing.has(tab_name):
			continue
		var button := Button.new()
		button.text = tr(String(item.label))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size.y = 38
		button.tooltip_text = tr("Open %s") % tr(String(item.label))
		button.set_meta("target_tab", tab_name)
		button.pressed.connect(_open_tab.bind(tabs, tab_name))
		sidebar.add_child(button)
	if _has_any_secondary(tabs) and sidebar.get_node_or_null("ToolsSeparator") == null:
		var separator := HSeparator.new()
		separator.name = "ToolsSeparator"
		sidebar.add_child(separator)
		for secondary in SECONDARY_ITEMS:
			if _tab_index(tabs, secondary) < 0:
				continue
			var button := Button.new()
			button.text = tr(secondary)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.focus_mode = Control.FOCUS_ALL
			button.custom_minimum_size.y = 38
			button.set_meta("target_tab", secondary)
			button.pressed.connect(_open_tab.bind(tabs, secondary))
			sidebar.add_child(button)

func _open_tab(tabs: TabContainer, name: String) -> void:
	var index := _tab_index(tabs, name)
	if index >= 0:
		tabs.current_tab = index
		_sync_active(index, tabs)

func _sync_active(index: int, tabs: TabContainer) -> void:
	var shell := tabs.get_parent()
	if shell == null:
		return
	var current_name := ""
	if index >= 0 and index < tabs.get_tab_count():
		current_name = String(tabs.get_child(index).name)
	if bool(tabs.get_meta("career_navigation_mobile", false)):
		var selector := shell.get_node_or_null("CareerMobileNavigation") as OptionButton
		if selector == null:
			return
		for i in range(selector.item_count):
			if String(selector.get_item_metadata(i)) == current_name:
				selector.select(i)
				return
		return
	var sidebar := shell.get_node_or_null("CareerSidebar")
	if sidebar == null:
		return
	for child in sidebar.get_children():
		if child is Button:
			child.button_pressed = String(child.get_meta("target_tab", "")) == current_name

func _looks_like_career_tabs(tabs: TabContainer) -> bool:
	return _tab_index(tabs, "Dashboard") >= 0 and _tab_index(tabs, "Squad") >= 0 and _career_session(tabs) != null

func _tab_index(tabs: TabContainer, name: String) -> int:
	for i in range(tabs.get_tab_count()):
		if String(tabs.get_child(i).name) == name or tabs.get_tab_title(i) == name:
			return i
	return -1

func _has_any_secondary(tabs: TabContainer) -> bool:
	for name in SECONDARY_ITEMS:
		if _tab_index(tabs, name) >= 0:
			return true
	return false

func _career_session(node: Node):
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			return current.get("session")
		current = current.get_parent()
	return null
