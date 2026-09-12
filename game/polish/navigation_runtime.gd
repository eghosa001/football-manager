extends Node

const NAV_ITEMS := [
	{"label":"Home","tab":"Dashboard","group":"MANAGER"},
	{"label":"Inbox","tab":"Inbox","group":"MANAGER"},
	{"label":"Squad","tab":"Squad","group":"TEAM"},
	{"label":"Dynamics","tab":"Dynamics","group":"TEAM"},
	{"label":"Tactics","tab":"Tactics","group":"TEAM"},
	{"label":"Training","tab":"Training","group":"TEAM"},
	{"label":"Medical","tab":"Medical","group":"TEAM"},
	{"label":"Schedule","tab":"Schedule","group":"COMPETITION"},
	{"label":"Competitions","tab":"Competitions","group":"COMPETITION"},
	{"label":"Scouting","tab":"Scouting","group":"RECRUITMENT"},
	{"label":"Transfers","tab":"Transfers","group":"RECRUITMENT"},
	{"label":"Staff","tab":"Staff","group":"CLUB"},
	{"label":"Finances","tab":"Finances","group":"CLUB"},
	{"label":"Club","tab":"Club","group":"CLUB"},
	{"label":"World","tab":"World History","group":"WORLD"},
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
		(shell as VBoxContainer).add_theme_constant_override("separation", 10)
		var selector := OptionButton.new()
		selector.name = "CareerMobileNavigation"
		selector.custom_minimum_size.y = 50
		selector.focus_mode = Control.FOCUS_ALL
		shell.add_child(selector)
		selector.item_selected.connect(_mobile_selected.bind(tabs, selector))
	else:
		shell = HBoxContainer.new()
		shell.name = "CareerNavigationShell"
		(shell as HBoxContainer).add_theme_constant_override("separation", 18)
		var sidebar := VBoxContainer.new()
		sidebar.name = "CareerSidebar"
		sidebar.custom_minimum_size.x = 208
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
	var signature := _navigation_signature(tabs)
	if String(selector.get_meta("nav_signature", "")) != signature:
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
		selector.set_meta("nav_signature", signature)
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
	var signature := _navigation_signature(tabs)
	if String(sidebar.get_meta("nav_signature", "")) == signature:
		return
	for child in sidebar.get_children():
		sidebar.remove_child(child)
		child.queue_free()

	var identity := VBoxContainer.new()
	identity.name = "DynastyIdentity"
	identity.add_theme_constant_override("separation", 0)
	var brand := Label.new()
	brand.text = tr("FOOTBALL DYNASTY")
	brand.add_theme_font_size_override("font_size", 18)
	brand.add_theme_color_override("font_color", Color(0.88, 0.90, 1.0, 1.0))
	identity.add_child(brand)
	var strap := Label.new()
	strap.text = tr("CAREER COMMAND")
	strap.add_theme_font_size_override("font_size", 11)
	strap.add_theme_color_override("font_color", Color(0.43, 0.84, 0.76, 1.0))
	identity.add_child(strap)
	sidebar.add_child(identity)
	var top_separator := HSeparator.new()
	sidebar.add_child(top_separator)

	var last_group := ""
	for item in NAV_ITEMS:
		var tab_name := String(item.tab)
		if _tab_index(tabs, tab_name) < 0:
			continue
		var group := String(item.get("group", ""))
		if group != last_group:
			_add_group_label(sidebar, group)
			last_group = group
		var button := _nav_button(tr(String(item.label)), tabs, tab_name)
		sidebar.add_child(button)

	if _has_any_secondary(tabs):
		var separator := HSeparator.new()
		separator.name = "ToolsSeparator"
		sidebar.add_child(separator)
		_add_group_label(sidebar, "TOOLS")
		for secondary in SECONDARY_ITEMS:
			if _tab_index(tabs, secondary) < 0:
				continue
			sidebar.add_child(_nav_button(tr(secondary), tabs, secondary))
	sidebar.set_meta("nav_signature", signature)

func _nav_button(label: String, tabs: TabContainer, tab_name: String) -> Button:
	var button := Button.new()
	button.text = label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 40
	button.toggle_mode = true
	button.tooltip_text = tr("Open %s") % label
	button.set_meta("target_tab", tab_name)
	button.pressed.connect(_open_tab.bind(tabs, tab_name))
	return button

func _add_group_label(sidebar: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = tr(title)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.56, 0.62, 0.74, 1.0))
	label.custom_minimum_size.y = 22
	sidebar.add_child(label)

func _navigation_signature(tabs: TabContainer) -> String:
	var names: Array[String] = []
	for i in range(tabs.get_tab_count()):
		names.append(String(tabs.get_child(i).name))
	return "|".join(names)

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
