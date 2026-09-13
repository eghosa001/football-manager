extends Node

const CoreCareerFactory = preload("res://application/career/core_career_factory.gd")
const CareerCommand = preload("res://application/career/career_command_service.gd")
const TacticsManager = preload("res://simulation/tactics/tactics_manager.gd")

var _next_scan := 0
var _league_lists := {}
var _last_delegation_day := {}

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 800
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is Control:
		var app := _career_app(node)
		if app != null:
			_focus_main_menu(app)
			_focus_new_career(app)
			_focus_career_tabs(app)
			_apply_staff_delegation(app)
	for child in node.get_children():
		_scan_node(child)

func _focus_main_menu(app: Node) -> void:
	for button in _buttons(app):
		if button.text in ["Club database editor", "Database Editor", "EDITOR"]:
			button.visible = false

func _focus_new_career(app: Node) -> void:
	var preview = app.get("_wizard_preview")
	if typeof(preview) != TYPE_DICTIONARY or preview.is_empty():
		return
	var create_button := _button_by_text(app, "Create Career")
	if create_button == null:
		return
	for button in _buttons(app):
		if "Expanded world" in button.text:
			button.visible = false
	if create_button.has_meta("core_league_selector"):
		return
	create_button.set_meta("core_league_selector", true)
	var parent := create_button.get_parent().get_parent()
	if parent == null:
		return
	var heading := Label.new()
	heading.text = "Active leagues"
	heading.add_theme_font_size_override("font_size", 18)
	parent.add_child(heading)
	parent.move_child(heading, maxi(0, create_button.get_parent().get_index()))
	var help := Label.new()
	help.text = "Select only the countries you want simulated. Fewer active leagues means faster Continue and matchdays. Your chosen club's country is always loaded."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(help)
	parent.move_child(help, heading.get_index() + 1)
	var list := ItemList.new()
	list.name = "CoreLeagueSelector"
	list.select_mode = ItemList.SELECT_MULTI
	list.custom_minimum_size = Vector2(620, 150)
	list.max_columns = 3
	list.same_column_width = true
	var countries: Array = preview.get("countries", [])
	for country in countries:
		list.add_item(String(country.get("name", country.get("id", "League"))))
		list.set_item_metadata(list.item_count - 1, String(country.get("id", "")))
	for i in range(mini(3, list.item_count)):
		list.select(i, false)
	parent.add_child(list)
	parent.move_child(list, help.get_index() + 1)
	_league_lists[app.get_instance_id()] = list
	var selector = app.get("_country_selector")
	if selector is OptionButton:
		(selector as OptionButton).item_selected.connect(func(index: int):
			if index >= 0 and index < list.item_count:
				list.select(index, false)
		)
	for connection in create_button.pressed.get_connections():
		create_button.pressed.disconnect(connection.callable)
	create_button.pressed.connect(_create_core_career.bind(app, list))

func _create_core_career(app: Node, list: ItemList) -> void:
	var wizard_clubs = app.get("_wizard_clubs")
	var club_selector = app.get("_club_selector")
	if not (wizard_clubs is Array) or wizard_clubs.is_empty() or not (club_selector is OptionButton):
		app.call("_show_error", "Choose a club first.")
		return
	var selected_index := clampi((club_selector as OptionButton).selected, 0, wizard_clubs.size() - 1)
	var selected_club: Dictionary = wizard_clubs[selected_index]
	var club_id := String(selected_club.get("id", ""))
	var club_country := String(selected_club.get("country_id", ""))
	var active_ids: Array = []
	for index in list.get_selected_items():
		active_ids.append(String(list.get_item_metadata(index)))
	if club_country != "" and club_country not in active_ids:
		active_ids.append(club_country)
	if active_ids.is_empty() and club_country != "":
		active_ids.append(club_country)
	var name_input = app.get("_manager_name_input")
	var manager_name := "Manager"
	if name_input is LineEdit and (name_input as LineEdit).text.strip_edges() != "":
		manager_name = (name_input as LineEdit).text.strip_edges()
	var slots = app.get("slots")
	if slots != null:
		app.set("active_slot", int(slots.first_available_slot()))
	var session = app.get("session")
	var result: Dictionary = await app.call("_run_job", CoreCareerFactory.new().create.bind(session, manager_name, club_id, active_ids, 12345), "Creating selected football leagues")
	if result.is_empty() or result.has("error"):
		app.call("_show_main_menu")
		app.call("_show_error", String(result.get("message", "Career creation failed.")))
		return
	preload("res://application/career/inbox_service.gd").new().add_message(session.world, "board", "Welcome to the club", "Your career is ready. Focus on the squad, staff, tactics, scouting, transfers, youth and competitions.")
	app.call("_show_career")

func _focus_career_tabs(app: Node) -> void:
	var session = app.get("session")
	if session == null or session.world.is_empty():
		return
	for tabs in _tab_containers(app):
		if tabs.get_tab_count() < 4:
			continue
		var has_dashboard := false
		var has_squad := false
		for i in range(tabs.get_tab_count()):
			var title := tabs.get_tab_title(i)
			if title == "Dashboard" or title == "Home": has_dashboard = true
			if title == "Squad": has_squad = true
		if not has_dashboard or not has_squad:
			continue
		var keep := ["Dashboard","Home","Inbox","Squad","Tactics","Training","Medical","Staff","Scouting","Transfers","Schedule","Competitions","Youth Academy","Finances","Search","Match Analysis","Club"]
		for i in range(tabs.get_tab_count()):
			var title := tabs.get_tab_title(i)
			tabs.set_tab_hidden(i, title not in keep)
		_add_staff_responsibilities(tabs, session)

func _add_staff_responsibilities(tabs: TabContainer, session) -> void:
	var index := _tab_index(tabs, "Staff")
	if index < 0:
		return
	var page := tabs.get_tab_control(index)
	if page == null or page.has_meta("core_staff_responsibilities"):
		return
	page.set_meta("core_staff_responsibilities", true)
	var box := _first_vbox(page)
	if box == null:
		return
	var responsibilities: Dictionary = session.world.get("staff_responsibilities", {"training":"user","medical":"staff","tactics":"user","recruitment":"user"})
	session.world["staff_responsibilities"] = responsibilities
	var heading := Label.new()
	heading.text = "Responsibilities"
	heading.add_theme_font_size_override("font_size", 18)
	box.add_child(heading)
	var description := Label.new()
	description.text = "Delegate routine work to staff, or keep control yourself. Delegation is reversible at any time."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	for area in ["training","medical","tactics","recruitment"]:
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Label.new()
		label.text = String(area).capitalize()
		label.custom_minimum_size.x = 180
		row.add_child(label)
		var choice := OptionButton.new()
		choice.add_item("I control it")
		choice.add_item("Delegate to staff")
		choice.select(1 if String(responsibilities.get(area, "user")) == "staff" else 0)
		choice.item_selected.connect(func(option: int): responsibilities[area] = "staff" if option == 1 else "user")
		row.add_child(choice)

func _apply_staff_delegation(app: Node) -> void:
	var session = app.get("session")
	if session == null or session.world.is_empty():
		return
	var world: Dictionary = session.world
	var day := int(world.get("day_index", 0))
	var key := str(session.get_instance_id())
	if int(_last_delegation_day.get(key, -1)) == day:
		return
	_last_delegation_day[key] = day
	var responsibilities: Dictionary = world.get("staff_responsibilities", {})
	var club_id := String(session.managed_club_id)
	var club := _club(world, club_id)
	if club.is_empty():
		return
	if String(responsibilities.get("training", "user")) == "staff":
		var fatigue := 0.0
		var count := 0
		for player in world.get("players", []):
			if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
				fatigue += float(player.get("fatigue", 0))
				count += 1
		var average_fatigue := fatigue / maxf(1.0, count)
		club["training_schedule"] = ["recovery","technical","tactical","physical","set_pieces","match_prep","rest"]
		club["training_intensity"] = 0.48 if average_fatigue > 55.0 else 0.65
	if String(responsibilities.get("medical", "user")) == "staff":
		var high_risk := 0
		for player in world.get("players", []):
			if String(player.get("club_id", "")) != club_id: continue
			var risk := 100 - int(player.get("fitness", 100)) + int(player.get("fatigue", 0))
			if risk >= 70: high_risk += 1
		if high_risk >= 3:
			club["training_intensity"] = minf(float(club.get("training_intensity", 0.65)), 0.5)
	if String(responsibilities.get("tactics", "user")) == "staff":
		var attackers := 0
		var wide := 0
		for player in world.get("players", []):
			if String(player.get("club_id", "")) != club_id or int(player.get("injured_days", 0)) > 0: continue
			if String(player.get("position", "")) == "ST": attackers += 1
			if String(player.get("position", "")) in ["AML","AMR","ML","MR"]: wide += 1
		var formation := "4-3-3" if wide >= 2 else ("4-4-2" if attackers >= 2 else "4-2-3-1")
		var old: Dictionary = club.get("tactic", {})
		var mentality := String(old.get("mentality", "balanced"))
		club["tactic"] = TacticsManager.new().create_tactic(formation, mentality, "standard", "standard")
	if String(responsibilities.get("recruitment", "user")) == "staff" and day % 7 == 0:
		var command := CareerCommand.new()
		var targets: Array = command.shortlist(world, club_id, 3)
		for target in targets:
			command.assign_scout(world, club_id, String(target.get("id", "")))

func _buttons(root: Node) -> Array:
	var result: Array = []
	_collect_type(root, Button, result)
	return result

func _tab_containers(root: Node) -> Array:
	var result: Array = []
	_collect_type(root, TabContainer, result)
	return result

func _collect_type(node: Node, type, result: Array) -> void:
	if is_instance_of(node, type): result.append(node)
	for child in node.get_children(): _collect_type(child, type, result)

func _button_by_text(root: Node, text: String) -> Button:
	for button in _buttons(root):
		if button.text == text: return button
	return null

func _first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer: return node
	for child in node.get_children():
		var found := _first_vbox(child)
		if found != null: return found
	return null

func _tab_index(tabs: TabContainer, title: String) -> int:
	for i in range(tabs.get_tab_count()):
		if tabs.get_tab_title(i) == title or String(tabs.get_tab_control(i).name) == title: return i
	return -1

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return club
	return {}

func _career_app(node: Node) -> Node:
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"): return current
		current = current.get_parent()
	return null
