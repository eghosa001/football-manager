extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://game/scenes/career_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.session.new_career("UI2 Test", "", 12345, 1)
	scene._show_career()
	# Allow the autoload integration bridge to discover the newly rebuilt tree.
	for _i in range(8):
		await process_frame
		await create_timer(0.05).timeout

	var tabs := _career_tabs(scene)
	assert(tabs != null)
	assert(tabs.tabs_visible == false)
	assert(bool(tabs.get_meta("career_navigation_shell", false)))
	assert(bool(tabs.get_meta("ui2_active", false)))

	var dashboard := _page(tabs, "Dashboard")
	var squad := _page(tabs, "Squad")
	var tactics := _page(tabs, "Tactics")
	var training := _page(tabs, "Training")
	var scouting := _page(tabs, "Scouting")
	assert(dashboard != null and bool(dashboard.get_meta("ui2_screen", false)))
	assert(squad != null and bool(squad.get_meta("ui2_screen", false)))
	assert(tactics != null and bool(tactics.get_meta("ui2_screen", false)))
	assert(training != null and bool(training.get_meta("ui2_extended", false)))
	assert(scouting != null and bool(scouting.get_meta("ui2_extended", false)))

	var shell := tabs.get_parent()
	assert(shell != null and String(shell.name) == "CareerNavigationShell")
	if not bool(tabs.get_meta("career_navigation_mobile", false)):
		assert(shell.find_child("CareerSidebar", true, false) != null)
		assert(shell.get_node_or_null("CareerSidebarScroll") != null)

	scene.queue_free()
	await process_frame
	print("[TEST] UI2 RUNTIME INTEGRATION PASS")
	quit(0)

func _career_tabs(node: Node) -> TabContainer:
	if node is TabContainer:
		var tabs := node as TabContainer
		if _index(tabs, "Dashboard") >= 0 and _index(tabs, "Squad") >= 0 and _index(tabs, "Tactics") >= 0:
			return tabs
	for child in node.get_children():
		var found := _career_tabs(child)
		if found != null:
			return found
	return null

func _page(tabs: TabContainer, name: String) -> Control:
	var index := _index(tabs, name)
	return tabs.get_tab_control(index) if index >= 0 else null

func _index(tabs: TabContainer, name: String) -> int:
	for i in range(tabs.get_tab_count()):
		var page := tabs.get_tab_control(i)
		if String(page.name) == name or tabs.get_tab_title(i) == name:
			return i
	return -1
