extends "res://game/polish/navigation_runtime.gd"

const EXTRA_NAV := [
	{"label":"Youth Academy", "tab":"Youth Academy", "group":"ACADEMY"},
	{"label":"Audio", "tab":"Audio", "group":"TOOLS"},
]

func _refresh_navigation(tabs: TabContainer) -> void:
	super._refresh_navigation(tabs)
	if bool(tabs.get_meta("career_navigation_mobile", false)):
		_expose_mobile_extras(tabs)
	else:
		_expose_sidebar_extras(tabs)
	_sync_active(tabs.current_tab, tabs)

func _expose_mobile_extras(tabs: TabContainer) -> void:
	var shell := tabs.get_parent()
	if shell == null:
		return
	var selector := shell.get_node_or_null("CareerMobileNavigation") as OptionButton
	if selector == null:
		return
	for item in EXTRA_NAV:
		var tab_name := String(item.tab)
		if _tab_index(tabs, tab_name) < 0 or _selector_has(selector, tab_name):
			continue
		selector.add_item(tr(String(item.label)))
		selector.set_item_metadata(selector.item_count - 1, tab_name)

func _expose_sidebar_extras(tabs: TabContainer) -> void:
	var shell := tabs.get_parent()
	if shell == null:
		return
	var sidebar := shell.find_child("CareerSidebar", true, false) as VBoxContainer
	if sidebar == null:
		return
	for item in EXTRA_NAV:
		var tab_name := String(item.tab)
		if _tab_index(tabs, tab_name) < 0 or _sidebar_has(sidebar, tab_name):
			continue
		var separator := HSeparator.new()
		separator.name = "%sSeparator" % tab_name.replace(" ", "")
		sidebar.add_child(separator)
		_add_group_label(sidebar, String(item.group))
		sidebar.add_child(_nav_button(tr(String(item.label)), tabs, tab_name))

func _selector_has(selector: OptionButton, tab_name: String) -> bool:
	for i in range(selector.item_count):
		if String(selector.get_item_metadata(i)) == tab_name:
			return true
	return false

func _sidebar_has(sidebar: VBoxContainer, tab_name: String) -> bool:
	for child in sidebar.get_children():
		if child is Button and String(child.get_meta("target_tab", "")) == tab_name:
			return true
	return false
