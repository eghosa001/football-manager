extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://game/scenes/career_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.session.new_career("Staff UI Test", "", 24680, 1)
	scene._show_career()
	for _i in range(30):
		await process_frame
		await create_timer(0.05).timeout

	var tabs := _career_tabs(scene)
	assert(tabs != null)
	var staff_page := _page(tabs, "Staff")
	assert(staff_page != null)
	var hire := _find_button(staff_page, "HIRE")
	assert(hire != null)
	var club_id := String(scene.session.managed_club_id)
	var before := _staff_count(scene.session.world, club_id)
	hire.pressed.emit()
	for _i in range(60):
		await process_frame
		if _staff_count(scene.session.world, club_id) > before:
			break
		await create_timer(0.05).timeout
	assert(_staff_count(scene.session.world, club_id) == before + 1)

	scene.queue_free()
	await process_frame
	print("[TEST] STAFF UI ACTION PASS")
	quit(0)

func _career_tabs(node: Node) -> TabContainer:
	if node is TabContainer:
		var tabs := node as TabContainer
		if _index(tabs, "Dashboard") >= 0 and _index(tabs, "Staff") >= 0:
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

func _staff_count(world: Dictionary, club_id: String) -> int:
	var count := 0
	for member in world.get("staff", []):
		if String(member.get("club_id", "")) == club_id:
			count += 1
	return count
