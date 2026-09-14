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
	var search_runtime := root.get_node_or_null("SearchRuntime")
	var completion_runtime := root.get_node_or_null("CompletionRuntime")
	var management_runtime := root.get_node_or_null("ManagementRuntime")
	assert(ui2_runtime != null)
	assert(ui2_extended != null)
	assert(search_runtime != null)
	assert(completion_runtime != null)
	assert(management_runtime != null)

	var tabs := _career_tabs(scene)
	assert(tabs != null)
	assert(tabs.tabs_visible == false)
	assert(bool(tabs.get_meta("career_navigation_shell", false)))
	assert(bool(tabs.get_meta("ui2_active", false)))
	assert(ui2_runtime.call("_career_app", tabs) == scene)
	assert(search_runtime.call("_career_session", tabs) == scene.session)
	assert(completion_runtime.call("_career_session", tabs) == scene.session)
	assert(management_runtime.call("_career_session", tabs) == scene.session)

	# The production shell is a 17-screen management application. Guard the actual
	# rendered tabs here (not just the registry descriptors) so a valid-looking
	# registry cannot mask a missing builder, orphaned screen, or empty production tab.
	var expected_tabs := [
		"Dashboard", "Inbox", "Squad", "Tactics", "Training", "Medical",
		"Dynamics", "Staff", "Scouting", "Transfers", "Youth Academy", "Schedule",
		"Competitions", "Finances", "Club", "Search", "Match Analysis"
	]
	assert(tabs.get_tab_count() == expected_tabs.size())
	for expected_name in expected_tabs:
		var rendered_page := _page(tabs, String(expected_name))
		assert(rendered_page != null)
		assert(rendered_page.get_child_count() > 0)

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
		var sidebar_scroll := shell.get_node_or_null("CareerSidebarScroll") as ScrollContainer
		assert(sidebar_scroll != null)
		assert(sidebar_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS)
		assert(sidebar_scroll.follow_focus)

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

	# Training must expose a real mutable team-intensity action, not only a metric.
	var intensity_slider: HSlider = null
	var intensity_apply: Button = null
	for _i in range(30):
		training = _page(_career_tabs(scene), "Training")
		if training != null:
			intensity_slider = training.find_child("TeamTrainingIntensity", true, false) as HSlider
			intensity_apply = training.find_child("ApplyTeamTrainingIntensity", true, false) as Button
		if intensity_slider != null and intensity_apply != null:
			break
		await process_frame
		await create_timer(0.05).timeout
	assert(intensity_slider != null and intensity_apply != null)
	intensity_slider.value = 0.75
	intensity_apply.pressed.emit()
	var managed_club := _club(scene.session.world, String(scene.session.managed_club_id))
	assert(not managed_club.is_empty())
	assert(is_equal_approx(float(managed_club.get("training_intensity", 0.0)), 0.75))

	# Scouting recommendations must create an actual assignment when a scout exists.
	if _has_scout(scene.session.world, String(scene.session.managed_club_id)):
		var assignments_before: int = scene.session.world.get("scout_assignments", []).size()
		var scout_button := _find_button(scouting, "SCOUT")
		assert(scout_button != null)
		scout_button.pressed.emit()
		for _i in range(40):
			await process_frame
			if scene.session.world.get("scout_assignments", []).size() > assignments_before:
				break
			await create_timer(0.05).timeout
		assert(scene.session.world.get("scout_assignments", []).size() == assignments_before + 1)

	tabs = _career_tabs(scene)
	assert(tabs != null)
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

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}

func _has_scout(world: Dictionary, club_id: String) -> bool:
	for member in world.get("staff", []):
		if String(member.get("club_id", "")) == club_id and String(member.get("role", "")) == "scout":
			return true
	return false
