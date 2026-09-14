extends "res://game/polish/ui2_remaining_runtime.gd"

const StaffMarket = preload("res://simulation/staff/staff_market.gd")

func _build_inbox(page: Control, tabs: TabContainer, session: Object, app: Node) -> void:
	if page == null or page.has_meta("ui2_remaining"):
		return
	var root := _replace(page, "Inbox")
	var world: Dictionary = session.get("world")
	var messages: Array = world.get("inbox", [])
	var unread := 0
	for message in messages:
		if not bool(message.get("read", false)):
			unread += 1
	_header(root, "INBOX", "%d messages • %d unread" % [messages.size(), unread], tabs, app)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.custom_minimum_size.y = 500
	root.add_child(body)
	var list := UI.panel(body, Vector2(330, 500), UI.CYAN)
	(list.get_parent() as Control).size_flags_stretch_ratio = 0.78
	UI.section(list, "MESSAGES")
	var detail := UI.panel(body, Vector2(0, 500), UI.PURPLE)
	(detail.get_parent() as Control).size_flags_stretch_ratio = 1.72
	var detail_title := UI.title(detail, "SELECT A MESSAGE", "Choose an item from your inbox")
	var detail_meta := UI.body(detail, "", true)
	var detail_body := UI.body(detail, "No message selected.")
	detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mark_button := UI.action("MARK READ", UI.GREEN)
	mark_button.visible = false
	detail.add_child(mark_button)
	var selected_index := -1
	var select_message := func(index: int) -> void:
		if index < 0 or index >= messages.size():
			return
		selected_index = index
		var message: Dictionary = messages[index]
		var subject := String(message.get("subject", message.get("title", "Club message")))
		var sender := String(message.get("sender", message.get("category", "Club")))
		var date := String(message.get("date", ""))
		var text := String(message.get("body", message.get("text", message.get("message", ""))))
		var heading := detail_title.get_child(0) as Label
		heading.text = subject.to_upper()
		detail_meta.text = "%s%s" % [sender, " • " + date if date != "" else ""]
		detail_body.text = text if text != "" else "No additional message text."
		mark_button.visible = not bool(message.get("read", false))
	mark_button.pressed.connect(func() -> void:
		var target_index := selected_index
		if target_index < 0 or target_index >= messages.size() or bool(messages[target_index].get("read", false)):
			target_index = -1
			for i in range(messages.size()):
				if not bool(messages[i].get("read", false)):
					target_index = i
					break
		if target_index < 0:
			return
		var message: Dictionary = messages[target_index]
		message["read"] = true
		messages[target_index] = message
		world["inbox"] = messages
		app.call_deferred("_show_career")
	)
	if messages.is_empty():
		UI.body(list, "Your inbox is clear.", true)
	else:
		for i in range(messages.size()):
			var message: Dictionary = messages[i]
			var subject := String(message.get("subject", message.get("title", "Club message")))
			var date := String(message.get("date", ""))
			var button := Button.new()
			button.text = "%s%s\n%s" % ["●  " if not bool(message.get("read", false)) else "", subject, date]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size.y = 54
			button.pressed.connect(select_message.bind(i))
			list.add_child(button)
		var initial_index := 0
		for i in range(messages.size()):
			if not bool(messages[i].get("read", false)):
				initial_index = i
				break
		select_message.call(initial_index)

func _build_staff(page: Control, tabs: TabContainer, session: Object) -> void:
	super._build_staff(page, tabs, session)
	if page == null:
		return
	var root := page.find_child("StaffUI2", true, false) as VBoxContainer
	if root == null or root.has_meta("staff_market_added"):
		return
	root.set_meta("staff_market_added", true)
	var world: Dictionary = session.get("world")
	var club_id := String(session.get("managed_club_id"))
	var market := StaffMarket.new()
	market.ensure_world(world)
	var panel := UI.panel(root, Vector2(0, 300), UI.PURPLE)
	UI.section(panel, "STAFF RECRUITMENT", UI.PURPLE)
	UI.body(panel, "Shortlisted candidates from the staff market. Hiring uses the same simulation rules as AI clubs.", true)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(grid)
	UI.table_header(grid, ["NAME", "ROLE", "ABILITY", "CURRENT CLUB", "ACTION"])
	var added := 0
	for role in ["coach", "scout", "physio"]:
		var candidates: Array = market.staff_candidates(world, club_id, role, 2)
		for candidate in candidates:
			var staff_id := String(candidate.get("staff_id", ""))
			var member := _staff_member(world, staff_id)
			if member.is_empty():
				continue
			UI.cell(grid, _person_name(member), 190)
			UI.cell(grid, role.capitalize(), 100, UI.CYAN)
			UI.cell(grid, str(member.get("ability", 0)), 70, UI.score_color(float(member.get("ability", 0))))
			var current_club := _club_name(world, String(member.get("club_id", "")))
			UI.cell(grid, current_club if current_club != "" else "Free agent", 160, UI.MUTED)
			var hire := Button.new()
			hire.name = "HireStaff_%s" % staff_id
			hire.text = "HIRE"
			hire.custom_minimum_size.x = 76
			hire.pressed.connect(func() -> void:
				var err := market.hire_staff(world, club_id, staff_id, int(world.get("season_year", 2026)))
				if err != OK:
					hire.text = "FAILED"
					return
				var app := _career_app(tabs)
				if app != null:
					app.call("_show_career")
			)
			grid.add_child(hire)
			added += 1
	if added == 0:
		UI.body(panel, "No suitable staff candidates are available right now.", true)

func _staff_member(world: Dictionary, staff_id: String) -> Dictionary:
	for member in world.get("staff", []):
		if String(member.get("id", "")) == staff_id:
			return member
	return {}

func _club_name(world: Dictionary, club_id: String) -> String:
	if club_id == "":
		return ""
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return String(club.get("name", club_id))
	return club_id
