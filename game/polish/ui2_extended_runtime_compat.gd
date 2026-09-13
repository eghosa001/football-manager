extends "res://game/polish/ui2_extended_runtime.gd"

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
