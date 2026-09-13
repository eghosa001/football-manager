extends SceneTree

const NavigationRuntimeClass = preload("res://game/polish/navigation_runtime_compat.gd")

func _init() -> void:
	var runtime = NavigationRuntimeClass.new()
	var parent := VBoxContainer.new()
	var tabs := TabContainer.new()
	parent.add_child(tabs)
	for name in ["Dashboard", "Inbox", "Squad", "Tactics", "Training", "Medical", "Schedule", "Competitions", "Scouting", "Transfers", "Staff", "Youth Academy", "Finances", "Board", "Data Hub", "Search", "Match Analysis", "Audio"]:
		var page := Control.new()
		page.name = name
		tabs.add_child(page)

	runtime.wire_tabs(tabs, true)
	assert(not tabs.tabs_visible)
	assert(bool(tabs.get_meta("career_navigation_mobile", false)))
	var mobile_shell := tabs.get_parent()
	assert(mobile_shell is VBoxContainer)
	var selector := mobile_shell.get_node_or_null("CareerMobileNavigation") as OptionButton
	assert(selector != null)
	assert(selector.item_count >= 14)
	assert(selector.custom_minimum_size.y >= 48.0)
	assert(_selector_has(selector, "Youth Academy"))
	assert(_selector_has(selector, "Audio"))

	# A tab change caused elsewhere in the game must keep the selector in sync.
	var target := -1
	for i in range(tabs.get_tab_count()):
		if String(tabs.get_child(i).name) == "Match Analysis": target = i
	assert(target >= 0)
	tabs.current_tab = target
	runtime._sync_active(target, tabs)
	assert(String(selector.get_item_metadata(selector.selected)) == "Match Analysis")

	# Desktop navigation must expose the same hidden first-class tabs and keep a
	# visible scrollbar for 720p layouts.
	parent.free()
	parent = VBoxContainer.new()
	tabs = TabContainer.new()
	parent.add_child(tabs)
	for name in ["Dashboard", "Inbox", "Squad", "Tactics", "Training", "Medical", "Schedule", "Competitions", "Scouting", "Transfers", "Staff", "Youth Academy", "Finances", "Search", "Match Analysis", "Audio"]:
		var page := Control.new()
		page.name = name
		tabs.add_child(page)
	runtime.wire_tabs(tabs, false)
	var desktop_shell := tabs.get_parent()
	var scroll := desktop_shell.get_node_or_null("CareerSidebarScroll") as ScrollContainer
	assert(scroll != null)
	assert(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS)
	var sidebar := desktop_shell.find_child("CareerSidebar", true, false) as VBoxContainer
	assert(sidebar != null)
	assert(_sidebar_has(sidebar, "Youth Academy"))
	assert(_sidebar_has(sidebar, "Audio"))

	# These nodes are deliberately created outside the SceneTree. queue_free()
	# would never be processed before this SceneTree exits, so free the owned
	# hierarchy and standalone runtime immediately to keep the regression test
	# leak-free under strict CI error detection.
	parent.free()
	runtime.free()
	print("[TEST] RESPONSIVE NAVIGATION PASS")
	quit(0)

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
