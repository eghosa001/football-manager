extends SceneTree

const NavigationRuntimeClass = preload("res://game/polish/navigation_runtime.gd")

func _init() -> void:
	var runtime = NavigationRuntimeClass.new()
	var parent := VBoxContainer.new()
	var tabs := TabContainer.new()
	parent.add_child(tabs)
	for name in ["Dashboard", "Inbox", "Squad", "Tactics", "Training", "Medical", "Schedule", "Competitions", "Scouting", "Transfers", "Staff", "Finances", "Board", "Data Hub", "Search", "Match Analysis"]:
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
	assert(selector.item_count >= 12)
	assert(selector.custom_minimum_size.y >= 48.0)

	# A tab change caused elsewhere in the game must keep the selector in sync.
	var target := -1
	for i in range(tabs.get_tab_count()):
		if String(tabs.get_child(i).name) == "Match Analysis": target = i
	assert(target >= 0)
	tabs.current_tab = target
	runtime._sync_active(target, tabs)
	assert(String(selector.get_item_metadata(selector.selected)) == "Match Analysis")

	# These nodes are deliberately created outside the SceneTree. queue_free()
	# would never be processed before this SceneTree exits, so free the owned
	# hierarchy and standalone runtime immediately to keep the regression test
	# leak-free under strict CI error detection.
	parent.free()
	runtime.free()
	print("[TEST] RESPONSIVE NAVIGATION PASS")
	quit(0)
