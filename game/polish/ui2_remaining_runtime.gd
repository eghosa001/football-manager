extends Node

const UI = preload("res://game/presentation/fd_ui2.gd")
const MatchViewer = preload("res://game/match_viewer.gd")

var _next_scan: int = 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 450
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer:
		var tabs := node as TabContainer
		if _tab_index(tabs, "Dashboard") >= 0 and _tab_index(tabs, "Squad") >= 0:
			var app := _career_app(tabs)
			if app != null:
				var session_value: Variant = app.get("session")
				if session_value is Object:
					var session: Object = session_value as Object
					var world_value: Variant = session.get("world")
					if typeof(world_value) == TYPE_DICTIONARY and not (world_value as Dictionary).is_empty():
						_build_remaining(tabs, session, app)
	for child: Node in node.get_children():
		_scan_node(child)

func _build_remaining(tabs: TabContainer, session: Object, app: Node) -> void:
	_build_inbox(_page(tabs, "Inbox"), tabs, session, app)
	_build_staff(_page(tabs, "Staff"), tabs, session)
	_build_youth(_page(tabs, "Youth Academy"), tabs, session)
	_build_search(_page(tabs, "Search"), tabs, session)
	_build_match_analysis(_page(tabs, "Match Analysis"), tabs, session)

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
		if selected_index < 0 or selected_index >= messages.size():
			return
		messages[selected_index]["read"] = true
		app.call("_show_career")
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
		select_message.call(0)

func _build_staff(page: Control, tabs: TabContainer, session: Object) -> void:
	if page == null or page.has_meta("ui2_remaining"):
		return
	var root := _replace(page, "Staff")
	var world: Dictionary = session.get("world")
	var club_id := String(session.get("managed_club_id"))
	var staff: Array = []
	for member in world.get("staff", world.get("staff_members", [])):
		if String(member.get("club_id", "")) == club_id:
			staff.append(member)
	_header(root, "STAFF", "%d staff members • coaching, scouting and medical team" % staff.size(), tabs, _career_app(tabs))
	var summary := HBoxContainer.new(); summary.add_theme_constant_override("separation", 10); root.add_child(summary)
	var avg := 0.0
	for member in staff: avg += float(member.get("ability", 0))
	_metric_card(summary, "STAFF", str(staff.size()), UI.CYAN)
	_metric_card(summary, "AVG ABILITY", "%.0f" % (avg / maxf(1.0, staff.size())), UI.GREEN)
	_metric_card(summary, "SCOUTS", str(_count_role(staff, "scout")), UI.PURPLE)
	_metric_card(summary, "MEDICAL", str(_count_medical(staff)), UI.RED)
	var panel := UI.panel(root, Vector2(0, 440), UI.CYAN)
	UI.section(panel, "FIRST-TEAM STAFF")
	var grid := GridContainer.new(); grid.columns = 5; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.add_child(grid)
	UI.table_header(grid, ["NAME", "ROLE", "ABILITY", "LICENSES", "STATUS"])
	for member in staff:
		UI.cell(grid, _person_name(member), 210)
		UI.cell(grid, String(member.get("role", "staff")).replace("_", " ").capitalize(), 130, UI.CYAN)
		UI.cell(grid, str(member.get("ability", 0)), 80, UI.score_color(float(member.get("ability", 0))))
		UI.cell(grid, ", ".join(member.get("licenses", [])) if not member.get("licenses", []).is_empty() else "—", 170, UI.MUTED)
		UI.cell(grid, "EMPLOYED", 90, UI.GREEN)

func _build_youth(page: Control, tabs: TabContainer, session: Object) -> void:
	if page == null or page.has_meta("ui2_remaining"):
		return
	var root := _replace(page, "YouthAcademy")
	var world: Dictionary = session.get("world")
	var club_id := String(session.get("managed_club_id"))
	var prospects: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id and int(player.get("age", 99)) <= 21 and not bool(player.get("retired", false)):
			prospects.append(player)
	prospects.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("potential", 0)) > int(b.get("potential", 0)))
	_header(root, "YOUTH ACADEMY", "Development centre • pathway to the first team", tabs, _career_app(tabs))
	var summary := HBoxContainer.new(); summary.add_theme_constant_override("separation", 10); root.add_child(summary)
	_metric_card(summary, "PROSPECTS", str(prospects.size()), UI.CYAN)
	_metric_card(summary, "TOP POTENTIAL", str(int(prospects[0].get("potential", 0))) if not prospects.is_empty() else "—", UI.AMBER)
	_metric_card(summary, "U18", str(_count_under(prospects, 18)), UI.GREEN)
	var panel := UI.panel(root, Vector2(0, 450), UI.GREEN)
	UI.section(panel, "DEVELOPMENT SQUAD", UI.GREEN)
	if prospects.is_empty():
		UI.body(panel, "No academy players are currently registered. The next youth intake will populate this area.", true)
		return
	var grid := GridContainer.new(); grid.columns = 8; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.add_child(grid)
	UI.table_header(grid, ["NAME", "POS", "AGE", "CA", "PA", "FIT", "MORALE", "PATHWAY"])
	for player in prospects.slice(0, mini(24, prospects.size())):
		UI.cell(grid, _person_name(player), 180)
		UI.cell(grid, String(player.get("position", "—")), 50, UI.CYAN)
		UI.cell(grid, str(player.get("age", 0)), 40)
		UI.cell(grid, str(player.get("current_ability", 0)), 45, UI.score_color(float(player.get("current_ability", 0))))
		UI.cell(grid, str(player.get("potential", 0)), 45, UI.AMBER)
		UI.cell(grid, str(player.get("fitness", 0)), 45, UI.score_color(float(player.get("fitness", 0))))
		UI.cell(grid, str(player.get("morale", 0)), 55, UI.score_color(float(player.get("morale", 0))))
		UI.cell(grid, "FIRST TEAM" if int(player.get("current_ability", 0)) >= 65 else "DEVELOP", 90, UI.GREEN if int(player.get("current_ability", 0)) >= 65 else UI.MUTED)

func _build_search(page: Control, tabs: TabContainer, session: Object) -> void:
	if page == null or page.has_meta("ui2_remaining"):
		return
	var root := _replace(page, "Search")
	var world: Dictionary = session.get("world")
	_header(root, "GLOBAL SEARCH", "Find players, clubs and staff across the football world", tabs, _career_app(tabs))
	var controls := HBoxContainer.new(); controls.add_theme_constant_override("separation", 8); root.add_child(controls)
	var input := LineEdit.new(); input.placeholder_text = "Search name, club or position"; input.custom_minimum_size = Vector2(420, 42); controls.add_child(input)
	var kind := OptionButton.new(); kind.add_item("ALL"); kind.add_item("PLAYERS"); kind.add_item("CLUBS"); kind.add_item("STAFF"); controls.add_child(kind)
	var panel := UI.panel(root, Vector2(0, 470), UI.CYAN)
	UI.section(panel, "RESULTS")
	var results := VBoxContainer.new(); results.add_theme_constant_override("separation", 4); panel.add_child(results)
	var render := func() -> void:
		for child in results.get_children(): child.queue_free()
		var needle := input.text.strip_edges().to_lower()
		if needle.length() < 2:
			UI.body(results, "Type at least two characters to search.", true)
			return
		var shown := 0
		if kind.selected in [0, 1]:
			for player in world.get("players", []):
				if shown >= 30: break
				var name := _person_name(player)
				if needle in name.to_lower():
					_add_search_result(results, "PLAYER", name, "%s • Age %d • CA %d" % [String(player.get("position", "—")), int(player.get("age", 0)), int(player.get("current_ability", 0))], UI.CYAN)
					shown += 1
		if kind.selected in [0, 2]:
			for club in world.get("clubs", []):
				if shown >= 30: break
				var name := String(club.get("name", "Club"))
				if needle in name.to_lower():
					_add_search_result(results, "CLUB", name, String(club.get("country_id", club.get("nation_id", ""))).to_upper(), UI.PURPLE)
					shown += 1
		if kind.selected in [0, 3]:
			for member in world.get("staff", world.get("staff_members", [])):
				if shown >= 30: break
				var name := _person_name(member)
				if needle in name.to_lower():
					_add_search_result(results, "STAFF", name, String(member.get("role", "staff")).capitalize(), UI.GREEN)
					shown += 1
		if shown == 0: UI.body(results, "No matching football entities found.", true)
	input.text_changed.connect(func(_text: String) -> void: render.call())
	kind.item_selected.connect(func(_index: int) -> void: render.call())
	render.call()

func _build_match_analysis(page: Control, tabs: TabContainer, session: Object) -> void:
	if page == null or page.has_meta("ui2_remaining"):
		return
	var root := _replace(page, "MatchAnalysis")
	var world: Dictionary = session.get("world")
	_header(root, "MATCH ANALYSIS", "Review the last managed match and identify tactical patterns", tabs, _career_app(tabs))
	if not world.has("last_managed_match") or typeof(world.get("last_managed_match")) != TYPE_DICTIONARY:
		var empty := UI.panel(root, Vector2(0, 430), UI.PURPLE)
		UI.section(empty, "ANALYSIS CENTRE", UI.PURPLE)
		UI.metric(empty, "Status", "No match yet", "Your first managed fixture will populate analysis and playback here.", UI.MUTED)
		return
	var match: Dictionary = world.get("last_managed_match", {})
	var result: Dictionary = match.get("result", match)
	var score_home := int(result.get("home_goals", result.get("score", [0,0])[0] if result.get("score", []) is Array and result.get("score", []).size() > 1 else 0))
	var score_away := int(result.get("away_goals", result.get("score", [0,0])[1] if result.get("score", []) is Array and result.get("score", []).size() > 1 else 0))
	var metrics := HBoxContainer.new(); metrics.add_theme_constant_override("separation", 10); root.add_child(metrics)
	_metric_card(metrics, "SCORE", "%d – %d" % [score_home, score_away], UI.CYAN)
	_metric_card(metrics, "EVENTS", str(result.get("events", []).size()), UI.PURPLE)
	_metric_card(metrics, "DATE", String(match.get("date", result.get("date", "—"))), UI.GREEN)
	var viewer_panel := UI.panel(root, Vector2(0, 440), UI.GREEN)
	UI.section(viewer_panel, "MATCH REPLAY", UI.GREEN)
	var viewer = MatchViewer.new()
	viewer.custom_minimum_size = Vector2(860, 360)
	viewer.set_match(result)
	viewer_panel.add_child(viewer)
	var controls := HBoxContainer.new(); controls.add_theme_constant_override("separation", 6); viewer_panel.add_child(controls)
	var prev := UI.action("◀", UI.CYAN); prev.pressed.connect(viewer.previous_frame); controls.add_child(prev)
	var play := UI.action("PLAY / PAUSE", UI.GREEN); play.pressed.connect(viewer.toggle_playback); controls.add_child(play)
	var next := UI.action("▶", UI.CYAN); next.pressed.connect(viewer.next_frame); controls.add_child(next)
	for speed in [1.0, 2.0, 4.0]:
		var speed_button := UI.action("%dx" % int(speed), UI.PURPLE); speed_button.pressed.connect(viewer.set_speed.bind(speed)); controls.add_child(speed_button)

func _replace(page: Control, screen_name: String) -> VBoxContainer:
	page.set_meta("ui2_remaining", true)
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 14); margin.add_theme_constant_override("margin_right", 14); margin.add_theme_constant_override("margin_top", 10); margin.add_theme_constant_override("margin_bottom", 16); margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL; margin.size_flags_vertical = Control.SIZE_EXPAND_FILL; page.add_child(margin)
	var root := VBoxContainer.new(); root.name = "%sUI2" % screen_name; root.add_theme_constant_override("separation", 10); root.size_flags_horizontal = Control.SIZE_EXPAND_FILL; root.size_flags_vertical = Control.SIZE_EXPAND_FILL; margin.add_child(root)
	return root

func _header(parent: VBoxContainer, title: String, subtitle: String, tabs: TabContainer, app: Node) -> void:
	var bar := HBoxContainer.new(); bar.custom_minimum_size.y = 62; bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; bar.add_theme_constant_override("separation", 10); parent.add_child(bar)
	var heading := UI.title(bar, title, subtitle); heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var continue_button := UI.action("CONTINUE  ›", UI.CYAN); continue_button.custom_minimum_size = Vector2(155, 42); continue_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER; continue_button.pressed.connect(func() -> void: app.call("_advance_day")); bar.add_child(continue_button)
	UI.divider(parent)

func _metric_card(parent: Control, title: String, value: String, color: Color) -> void:
	var card := UI.panel(parent, Vector2(190, 95), color)
	UI.metric(card, title, value, "", color)

func _add_search_result(parent: Control, kind: String, name: String, detail: String, color: Color) -> void:
	var row := HBoxContainer.new(); row.custom_minimum_size.y = 42; parent.add_child(row)
	row.add_child(UI.chip(kind, color))
	var name_label := UI.body(row, name); name_label.custom_minimum_size.x = 260
	var detail_label := UI.body(row, detail, true); detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _count_role(staff: Array, role: String) -> int:
	var count := 0
	for member in staff:
		if String(member.get("role", "")).to_lower().contains(role): count += 1
	return count

func _count_medical(staff: Array) -> int:
	var count := 0
	for member in staff:
		var role := String(member.get("role", "")).to_lower()
		if "physio" in role or "medical" in role or "doctor" in role: count += 1
	return count

func _count_under(players: Array, age: int) -> int:
	var count := 0
	for player in players:
		if int(player.get("age", 99)) < age: count += 1
	return count

func _person_name(data: Dictionary) -> String:
	var name := String(data.get("name", "")).strip_edges()
	if name != "": return name
	return (String(data.get("first_name", "")) + " " + String(data.get("last_name", ""))).strip_edges()

func _career_app(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"): return current
		current = current.get_parent()
	return null

func _page(tabs: TabContainer, name: String) -> Control:
	var index := _tab_index(tabs, name)
	return tabs.get_tab_control(index) if index >= 0 else null

func _tab_index(tabs: TabContainer, name: String) -> int:
	for i in range(tabs.get_tab_count()):
		var page := tabs.get_tab_control(i)
		if String(page.name) == name or tabs.get_tab_title(i) == name: return i
	return -1
