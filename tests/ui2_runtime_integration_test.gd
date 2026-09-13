extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://game/scenes/career_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.session.new_career("UI2 Test", "", 12345, 1)
	scene._show_career()
	for _i in range(8):
		await process_frame
		await create_timer(0.05).timeout

	var ui2_runtime := root.get_node_or_null("UI2Runtime")
	var ui2_extended := root.get_node_or_null("UI2ExtendedRuntime")
	assert(ui2_runtime != null)
	assert(ui2_extended != null)

	var tabs := _career_tabs(scene)
	assert(tabs != null)
	assert(tabs.tabs_visible == false)
	assert(bool(tabs.get_meta("career_navigation_shell", false)))
	assert(bool(tabs.get_meta("ui2_active", false)))
	assert(ui2_runtime.call("_career_app", tabs) == scene)

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

	var managed_fixtures: Array = []
	for fixture in scene.session.world.get("fixtures", []):
		if String(fixture.get("home_club_id", "")) == String(scene.session.managed_club_id) or String(fixture.get("away_club_id", "")) == String(scene.session.managed_club_id):
			managed_fixtures.append(fixture)
	var current_date := String(scene.session.world.get("current_date", scene.session.world.get("date", "")))
	var window: Array = ui2_extended.call("_schedule_window", managed_fixtures, current_date)
	assert(not window.is_empty())
	var next_date := _next_fixture_date(managed_fixtures, current_date)
	assert(next_date != "")
	var contains_next := false
	for fixture in window:
		if String(fixture.get("date", "")) == next_date:
			contains_next = true
			break
	assert(contains_next)

	var inbox := _page(tabs, "Inbox")
	assert(inbox != null)
	var unread_before := _unread_count(scene.session.world.get("inbox", []))
	if unread_before > 0:
		var mark_read := _find_button(inbox, "MARK READ")
		assert(mark_read != null)
		mark_read.pressed.emit()
		for _i in range(6):
			await process_frame
			await create_timer(0.03).timeout
		assert(_unread_count(scene.session.world.get("inbox", [])) == unread_before - 1)

	tabs = _career_tabs(scene)
	assert(tabs != null)
	dashboard = _page(tabs, "Dashboard")
	var continue_button := _find_button_prefix(dashboard, "CONTINUE")
	assert(continue_button != null)
	var day_before := int(scene.session.world.get("day_index", 0))
	continue_button.pressed.emit()
	for _i in range(120):
		await process_frame
		if int(scene.session.world.get("day_index", 0)) > day_before:
			break
		await create_timer(0.05).timeout
	assert(int(scene.session.world.get("day_index", 0)) == day_before + 1)

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

func _find_button(node: Node, text: String) -> Button:
	if node is Button and String((node as Button).text) == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null

func _find_button_prefix(node: Node, prefix: String) -> Button:
	if node is Button and String((node as Button).text).begins_with(prefix):
		return node as Button
	for child in node.get_children():
		var found := _find_button_prefix(child, prefix)
		if found != null:
			return found
	return null

func _unread_count(messages: Array) -> int:
	var count := 0
	for message in messages:
		if not bool(message.get("read", false)):
			count += 1
	return count

func _next_fixture_date(fixtures: Array, current_date: String) -> String:
	var next := ""
	for fixture in fixtures:
		var date := String(fixture.get("date", ""))
		if date < current_date:
			continue
		if next == "" or date < next:
			next = date
	return next
