extends "res://game/polish/ui2_extended_runtime.gd"

const CareerCommand = preload("res://application/career/career_command_service.gd")

# Compatibility layer for the registry-based production career scene.
# Also fixes the schedule window so it is anchored around the current career date
# instead of always showing the final fixtures of the season.

func _career_session(node: Node):
	var current: Node = node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"):
			return current.get("session")
		current = current.get_parent()
	return null

func _career_app(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"):
			return current
		current = current.get_parent()
	return null

func _schedule_window(fixtures: Array, current_date: String, max_rows: int = 20, recent_context: int = 4) -> Array:
	var ordered: Array = fixtures.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("date", "")) < String(b.get("date", ""))
	)
	if ordered.is_empty():
		return []
	var next_index := ordered.size()
	for i in range(ordered.size()):
		var fixture_date := String((ordered[i] as Dictionary).get("date", ""))
		if current_date == "" or fixture_date >= current_date:
			next_index = i
			break
	var start := maxi(0, next_index - recent_context)
	if next_index >= ordered.size():
		start = maxi(0, ordered.size() - max_rows)
	var end := mini(ordered.size(), start + max_rows)
	return ordered.slice(start, end)

func _build_schedule(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"):
		return
	var root: VBoxContainer = _replace_page(page)
	if root == null:
		return
	_header(root, "SCHEDULE", "Upcoming matches • recent results", tabs, session)
	var panel: VBoxContainer = UI.panel(root, Vector2(0, 500), UI.CYAN)
	UI.section(panel, "FIXTURE LIST")
	var table: GridContainer = GridContainer.new()
	table.columns = 6
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(table)
	UI.table_header(table, ["DATE", "VENUE", "OPPONENT", "COMPETITION", "RESULT", "STATUS"])
	var fixtures: Array = []
	for fixture in session.world.get("fixtures", []):
		var home: bool = String(fixture.get("home_club_id", "")) == String(session.managed_club_id)
		var away: bool = String(fixture.get("away_club_id", "")) == String(session.managed_club_id)
		if home or away:
			fixtures.append(fixture)
	var current_date := String(session.world.get("current_date", session.world.get("date", "")))
	for fixture in _schedule_window(fixtures, current_date):
		var home: bool = String(fixture.get("home_club_id", "")) == String(session.managed_club_id)
		var opponent_id: String = String(fixture.get("away_club_id", "")) if home else String(fixture.get("home_club_id", ""))
		var played: bool = bool(fixture.get("played", false))
		var result_text: String = "%d-%d" % [int(fixture.get("home_goals", 0)), int(fixture.get("away_goals", 0))] if played else "—"
		UI.cell(table, String(fixture.get("date", "TBD")), 90)
		UI.cell(table, "H" if home else "A", 45, UI.CYAN)
		UI.cell(table, _club_name(session.world, opponent_id).left(20), 160)
		var competition_name := _competition_name(session.world, String(fixture.get("competition_id", "")))
		UI.cell(table, competition_name, 185, UI.PURPLE)
		UI.cell(table, result_text, 70, UI.GREEN if played else UI.MUTED)
		UI.cell(table, "FT" if played else "UPCOMING", 90, UI.GREEN if played else UI.CYAN)

func _build_scouting(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"):
		return
	var root: VBoxContainer = _replace_page(page)
	if root == null:
		return
	_header(root, "SCOUTING", "Recruitment focus • coverage • recommendations", tabs, session)
	var data: Dictionary = _query.scouting(session.world, session.managed_club_id)
	var club: Dictionary = _club(session.world, session.managed_club_id)
	var assignments: Array = data.get("assignments", [])
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var known: VBoxContainer = UI.panel(top, Vector2(250, 105), UI.CYAN)
	UI.metric(known, "Known players", str(data.get("knowledge_count", 0)), "scouting database", UI.CYAN)
	var active: VBoxContainer = UI.panel(top, Vector2(250, 105), UI.GREEN)
	UI.metric(active, "Assignments", str(assignments.size()), "active / completed", UI.GREEN)
	var budget: VBoxContainer = UI.panel(top, Vector2(250, 105), UI.PURPLE)
	UI.metric(budget, "Scouting budget", UI.money(int(club.get("scouting_budget", int(club.get("transfer_budget", 0)) / 30))), "recruitment resources", UI.PURPLE)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	var focus: VBoxContainer = UI.panel(body, Vector2(300, 390), UI.CYAN)
	UI.section(focus, "RECRUITMENT FOCUSES")
	if assignments.is_empty():
		UI.body(focus, "No active scouting assignments", true)
	for assignment in assignments.slice(0, mini(8, assignments.size())):
		var assignment_row := VBoxContainer.new()
		focus.add_child(assignment_row)
		UI.body(assignment_row, String(assignment.get("target_id", "Assignment")).left(26))
		UI.progress(assignment_row, clampf(float(assignment.get("progress", 0.0)) / 100.0, 0.0, 1.0), UI.GREEN, 170)

	var recommendations: VBoxContainer = UI.panel(body, Vector2(0, 390), UI.GREEN)
	recommendations.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.section(recommendations, "SCOUTING RECOMMENDATIONS", UI.GREEN)
	var table := GridContainer.new()
	table.columns = 7
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recommendations.add_child(table)
	UI.table_header(table, ["PLAYER", "POS", "AGE", "ABILITY", "POTENTIAL", "VALUE", "ACTION"])
	for player in _shortlist(session.world, session.managed_club_id, 10):
		var player_id := String(player.get("id", ""))
		UI.cell(table, _player_name(player).left(19), 155)
		UI.cell(table, String(player.get("position", "")), 55, UI.CYAN)
		UI.cell(table, str(player.get("age", 0)), 42)
		UI.cell(table, UI.stars(int(player.get("current_ability", 0))), 105, UI.AMBER)
		UI.cell(table, UI.stars(int(player.get("potential", 0))), 105, UI.AMBER)
		UI.cell(table, UI.money(_value(player)), 95, UI.GREEN)
		var scout_button := Button.new()
		scout_button.name = "ScoutPlayer_%s" % player_id
		var assigned := false
		for assignment in assignments:
			if String(assignment.get("target_id", "")) == player_id:
				assigned = true
				break
		scout_button.text = "ACTIVE" if assigned else "SCOUT"
		scout_button.disabled = assigned
		scout_button.custom_minimum_size.x = 78
		scout_button.pressed.connect(func():
			var result: Dictionary = CareerCommand.new().assign_scout(session.world, String(session.managed_club_id), player_id)
			if result.has("error"):
				scout_button.text = "FAILED"
				return
			var app := _career_app(tabs)
			if app != null:
				app.call("_show_career")
		)
		table.add_child(scout_button)
