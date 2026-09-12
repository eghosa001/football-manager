extends Node

const UI = preload("res://game/presentation/fd_ui2.gd")
const CareerQuery = preload("res://application/career/career_query.gd")

var _next_scan: int = 0
var _query = CareerQuery.new()

class MiniChart:
	extends Control
	var values: Array[float] = []
	var positive: Color = Color(0.18, 0.83, 0.73, 1.0)
	func setup(data: Array, color: Color) -> void:
		values.clear()
		for value in data:
			values.append(float(value))
		positive = color
		custom_minimum_size = Vector2(220, 96)
		queue_redraw()
	func _draw() -> void:
		if values.size() < 2:
			return
		var lo: float = float(values.min())
		var hi: float = float(values.max())
		var span: float = maxf(1.0, hi - lo)
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(values.size()):
			var x: float = 8.0 + (size.x - 16.0) * float(i) / float(values.size() - 1)
			var normalized: float = (float(values[i]) - lo) / span
			var y: float = size.y - 10.0 - (size.y - 20.0) * normalized
			pts.append(Vector2(x, y))
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], positive, 3.0, true)
		for point in pts:
			draw_circle(point, 3.0, positive)

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 900
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer:
		_upgrade(node as TabContainer)
	for child in node.get_children():
		_scan_node(child)

func _upgrade(tabs: TabContainer) -> void:
	if not bool(tabs.get_meta("ui2_active", false)):
		return
	var session = _career_session(tabs)
	if session == null or session.world.is_empty():
		return
	tabs.set_meta("individual_training_added", true)
	_build_training(_page(tabs, "Training"), tabs, session)
	_build_scouting(_page(tabs, "Scouting"), tabs, session)
	_build_finances(_page(tabs, "Finances"), tabs, session)
	_build_transfers(_page(tabs, "Transfers"), tabs, session)
	_build_medical(_page(tabs, "Medical"), tabs, session)
	_build_competitions(_page(tabs, "Competitions"), tabs, session)
	_build_schedule(_page(tabs, "Schedule"), tabs, session)

func _build_training(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"):
		return
	var root: VBoxContainer = _replace_page(page)
	if root == null:
		return
	_header(root, "TRAINING", "Weekly programme • workload • development", tabs, session)
	var data: Dictionary = _query.training(session.world, session.managed_club_id)
	var squad: Array = _squad(session.world, session.managed_club_id)
	var status: HBoxContainer = HBoxContainer.new()
	status.add_theme_constant_override("separation", 12)
	root.add_child(status)
	var summary: VBoxContainer = UI.panel(status, Vector2(300, 110), UI.CYAN)
	UI.metric(summary, "Intensity", "%.0f%%" % (float(data.get("intensity", 0.65)) * 100.0), "Facilities %d" % int(data.get("facilities", 0)), UI.CYAN)
	var avg_fit: float = 0.0
	var avg_morale: float = 0.0
	var high_risk: int = 0
	for player in squad:
		avg_fit += float(player.get("fitness", 0))
		avg_morale += float(player.get("morale", 0))
		if int(player.get("fatigue", 0)) > 60 or int(player.get("fitness", 100)) < 70:
			high_risk += 1
	var pulse: VBoxContainer = UI.panel(status, Vector2(300, 110), UI.GREEN)
	UI.metric(pulse, "Squad readiness", "%.0f%% fit" % (avg_fit / maxf(1.0, float(squad.size()))), "%.0f morale" % (avg_morale / maxf(1.0, float(squad.size()))), UI.GREEN)
	var risk: VBoxContainer = UI.panel(status, Vector2(300, 110), UI.RED)
	UI.metric(risk, "Workload risk", str(high_risk), "players need attention", UI.RED if high_risk > 2 else UI.AMBER)

	var week: VBoxContainer = UI.panel(root, Vector2(0, 265), UI.CYAN)
	UI.section(week, "THIS WEEK")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	week.add_child(grid)
	var day_names: Array[String] = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
	var schedule: Array = data.get("schedule", [])
	for i in range(7):
		var day: VBoxContainer = VBoxContainer.new()
		day.custom_minimum_size = Vector2(116, 170)
		day.add_theme_constant_override("separation", 7)
		grid.add_child(day)
		var day_label: Label = UI.body(day, day_names[i])
		day_label.add_theme_color_override("font_color", UI.CYAN)
		var session_name: String = String(schedule[i]) if i < schedule.size() else "rest"
		var chip_color: Color = UI.GREEN if session_name in ["recovery", "rest"] else (UI.AMBER if session_name in ["physical", "fitness"] else UI.PURPLE)
		day.add_child(UI.chip(session_name.replace("_", " ").capitalize(), chip_color))
		var load: float = 0.25 if session_name == "rest" else (0.45 if session_name == "recovery" else 0.75)
		UI.progress(day, load, chip_color, 100)
		UI.body(day, "Load %.0f%%" % (load * 100.0), true)

	var lower: HBoxContainer = HBoxContainer.new()
	lower.add_theme_constant_override("separation", 12)
	root.add_child(lower)
	var performers: VBoxContainer = UI.panel(lower, Vector2(430, 250), UI.GREEN)
	UI.section(performers, "TRAINING PERFORMANCE", UI.GREEN)
	var sorted: Array = squad.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("morale", 0)) + int(a.get("fitness", 0)) > int(b.get("morale", 0)) + int(b.get("fitness", 0))
	)
	for player in sorted.slice(0, mini(6, sorted.size())):
		var row: HBoxContainer = HBoxContainer.new()
		performers.add_child(row)
		var name_label: Label = UI.body(row, _player_name(player))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(UI.chip("FIT %d" % int(player.get("fitness", 0)), UI.GREEN if int(player.get("fitness", 0)) >= 80 else UI.AMBER))
		row.add_child(UI.chip("MOR %d" % int(player.get("morale", 0)), UI.CYAN))
	var individual: VBoxContainer = UI.panel(lower, Vector2(430, 250), UI.PURPLE)
	UI.section(individual, "INDIVIDUAL DEVELOPMENT", UI.PURPLE)
	for player in squad.slice(0, mini(6, squad.size())):
		var row: HBoxContainer = HBoxContainer.new()
		individual.add_child(row)
		var name_label: Label = UI.body(row, _player_name(player))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(UI.chip(String(player.get("training_focus", "balanced")).capitalize(), UI.PURPLE))

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
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var known: VBoxContainer = UI.panel(top, Vector2(250, 105), UI.CYAN)
	UI.metric(known, "Known players", str(data.get("knowledge_count", 0)), "scouting database", UI.CYAN)
	var active: VBoxContainer = UI.panel(top, Vector2(250, 105), UI.GREEN)
	UI.metric(active, "Assignments", str(assignments.size()), "active / completed", UI.GREEN)
	var budget: VBoxContainer = UI.panel(top, Vector2(250, 105), UI.PURPLE)
	UI.metric(budget, "Scouting budget", UI.money(int(club.get("scouting_budget", int(club.get("transfer_budget", 0)) / 30))), "recruitment resources", UI.PURPLE)
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	var focus: VBoxContainer = UI.panel(body, Vector2(300, 390), UI.CYAN)
	UI.section(focus, "RECRUITMENT FOCUSES")
	if assignments.is_empty():
		UI.body(focus, "No active scouting assignments", true)
	for assignment in assignments.slice(0, mini(8, assignments.size())):
		var row: VBoxContainer = VBoxContainer.new()
		focus.add_child(row)
		UI.body(row, String(assignment.get("target_id", "Assignment")).left(26))
		UI.progress(row, clampf(float(assignment.get("progress", 0.0)) / 100.0, 0.0, 1.0), UI.GREEN, 170)
	var recommendations: VBoxContainer = UI.panel(body, Vector2(0, 390), UI.GREEN)
	recommendations.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.section(recommendations, "SCOUTING RECOMMENDATIONS", UI.GREEN)
	var table: GridContainer = GridContainer.new()
	table.columns = 6
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recommendations.add_child(table)
	UI.table_header(table, ["PLAYER", "POS", "AGE", "ABILITY", "POTENTIAL", "VALUE"])
	for player in _shortlist(session.world, session.managed_club_id, 10):
		UI.cell(table, _player_name(player).left(19), 155)
		UI.cell(table, String(player.get("position", "")), 55, UI.CYAN)
		UI.cell(table, str(player.get("age", 0)), 42)
		UI.cell(table, UI.stars(int(player.get("current_ability", 0))), 105, UI.AMBER)
		UI.cell(table, UI.stars(int(player.get("potential", 0))), 105, UI.AMBER)
		UI.cell(table, UI.money(_value(player)), 95, UI.GREEN)

func _build_finances(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"):
		return
	var root: VBoxContainer = _replace_page(page)
	if root == null:
		return
	_header(root, "FINANCES", "Balance • income • expenditure • budgets", tabs, session)
	var club: Dictionary = _club(session.world, session.managed_club_id)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	_add_money_metric(top, "BALANCE", int(club.get("cash", 0)), UI.CYAN)
	_add_money_metric(top, "TRANSFER BUDGET", int(club.get("transfer_budget", 0)), UI.GREEN)
	_add_money_metric(top, "WAGE BUDGET", int(club.get("wage_budget", 0)), UI.PURPLE)

	var ledger: Array = session.world.get("ledger", [])
	var cash_values: Array = []
	var income_values: Array = []
	var cost_values: Array = []
	var balance: float = float(club.get("cash", 0))
	var count: int = 0
	for entry in ledger:
		if String(entry.get("club_id", "")) != String(session.managed_club_id):
			continue
		var amount: float = float(entry.get("amount", entry.get("value", 0)))
		balance += amount
		cash_values.append(balance)
		if amount >= 0.0:
			income_values.append(amount)
		else:
			cost_values.append(absf(amount))
		count += 1
		if count >= 18:
			break
	if cash_values.size() < 2:
		cash_values = [float(club.get("cash", 0)) * 0.82, float(club.get("cash", 0)) * 0.9, float(club.get("cash", 0))]

	var charts: HBoxContainer = HBoxContainer.new()
	charts.add_theme_constant_override("separation", 12)
	root.add_child(charts)
	var balance_panel: VBoxContainer = UI.panel(charts, Vector2(430, 230), UI.CYAN)
	UI.section(balance_panel, "BALANCE HISTORY")
	var balance_chart: MiniChart = MiniChart.new()
	balance_chart.setup(cash_values, UI.CYAN)
	balance_panel.add_child(balance_chart)
	var flow_panel: VBoxContainer = UI.panel(charts, Vector2(430, 230), UI.GREEN)
	UI.section(flow_panel, "CASH FLOW", UI.GREEN)
	var combined: Array = []
	var max_count: int = maxi(income_values.size(), cost_values.size())
	for i in range(max_count):
		var income: float = float(income_values[i]) if i < income_values.size() else 0.0
		var cost: float = float(cost_values[i]) if i < cost_values.size() else 0.0
		combined.append(income - cost)
	if combined.size() < 2:
		combined = [0.0, 1.0, 0.5]
	var flow_chart: MiniChart = MiniChart.new()
	flow_chart.setup(combined, UI.GREEN)
	flow_panel.add_child(flow_chart)

	var lower: HBoxContainer = HBoxContainer.new()
	lower.add_theme_constant_override("separation", 12)
	root.add_child(lower)
	var income_panel: VBoxContainer = UI.panel(lower, Vector2(420, 210), UI.GREEN)
	UI.section(income_panel, "INCOME", UI.GREEN)
	UI.metric(income_panel, "Recorded income", UI.money(int(_sum(income_values))), "ledger total", UI.GREEN)
	var expense_panel: VBoxContainer = UI.panel(lower, Vector2(420, 210), UI.RED)
	UI.section(expense_panel, "EXPENDITURE", UI.RED)
	UI.metric(expense_panel, "Recorded expenditure", UI.money(int(_sum(cost_values))), "ledger total", UI.RED)

func _build_transfers(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"):
		return
	var root: VBoxContainer = _replace_page(page)
	if root == null:
		return
	_header(root, "TRANSFERS", "Market activity • bids • budgets", tabs, session)
	var data: Dictionary = _query.transfer_market(session.world, session.managed_club_id)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var window_open: bool = bool(data.get("window_open", false))
	var window_panel: VBoxContainer = UI.panel(top, Vector2(250, 110), UI.GREEN if window_open else UI.RED)
	UI.metric(window_panel, "TRANSFER WINDOW", "OPEN" if window_open else "CLOSED", "market status", UI.GREEN if window_open else UI.RED)
	_add_money_metric(top, "TRANSFER BUDGET", int(data.get("transfer_budget", 0)), UI.CYAN)
	_add_money_metric(top, "WAGE BUDGET", int(data.get("wage_budget", 0)), UI.PURPLE)
	var offers: Array = data.get("offers", [])
	var panel: VBoxContainer = UI.panel(root, Vector2(0, 390), UI.CYAN)
	UI.section(panel, "ACTIVE NEGOTIATIONS")
	var table: GridContainer = GridContainer.new()
	table.columns = 6
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(table)
	UI.table_header(table, ["PLAYER", "FEE", "STATUS", "COUNTER", "CLAUSES", "ACTION"])
	if offers.is_empty():
		UI.body(panel, "No active offers. Use Scouting to identify and approach targets.", true)
	for offer in offers.slice(0, mini(12, offers.size())):
		var player: Dictionary = _player(session.world, String(offer.get("player_id", "")))
		UI.cell(table, _player_name(player).left(20), 160)
		UI.cell(table, UI.money(int(offer.get("fee", 0))), 90, UI.GREEN)
		UI.cell(table, String(offer.get("status", "submitted")).capitalize(), 90, UI.CYAN)
		var counter_text: String = UI.money(int(offer.get("counter_fee", 0))) if offer.has("counter_fee") else "—"
		UI.cell(table, counter_text, 90, UI.AMBER)
		UI.cell(table, str(offer.get("clauses", {})).left(22), 150, UI.MUTED)
		UI.cell(table, "Review", 70, UI.PURPLE)

func _build_medical(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"):
		return
	var root: VBoxContainer = _replace_page(page)
	if root == null:
		return
	_header(root, "MEDICAL CENTRE", "Injuries • fatigue • player risk", tabs, session)
	var squad: Array = _squad(session.world, session.managed_club_id)
	var injured: int = 0
	var high: int = 0
	for player in squad:
		if int(player.get("injured_days", 0)) > 0:
			injured += 1
		if int(player.get("fitness", 100)) < 75 or int(player.get("fatigue", 0)) > 60:
			high += 1
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var injuries_panel: VBoxContainer = UI.panel(top, Vector2(260, 105), UI.RED)
	UI.metric(injuries_panel, "INJURIES", str(injured), "currently unavailable", UI.RED)
	var risk_panel: VBoxContainer = UI.panel(top, Vector2(260, 105), UI.AMBER)
	UI.metric(risk_panel, "PLAYERS AT RISK", str(high), "fatigue / low fitness", UI.AMBER)
	var panel: VBoxContainer = UI.panel(root, Vector2(0, 430), UI.RED)
	UI.section(panel, "SQUAD RISK REGISTER", UI.RED)
	var table: GridContainer = GridContainer.new()
	table.columns = 6
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(table)
	UI.table_header(table, ["PLAYER", "POS", "FITNESS", "FATIGUE", "INJURY", "RISK"])
	var rows: Array = squad.duplicate()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _risk(a) > _risk(b)
	)
	for player in rows.slice(0, mini(14, rows.size())):
		var risk_value: int = _risk(player)
		UI.cell(table, _player_name(player).left(20), 160)
		UI.cell(table, String(player.get("position", "")), 55, UI.CYAN)
		UI.cell(table, "%d%%" % int(player.get("fitness", 0)), 70, UI.GREEN if int(player.get("fitness", 0)) >= 80 else UI.AMBER)
		UI.cell(table, str(player.get("fatigue", 0)), 65, UI.AMBER)
		var injury_text: String = "%d d" % int(player.get("injured_days", 0)) if int(player.get("injured_days", 0)) > 0 else "—"
		UI.cell(table, injury_text, 70, UI.RED)
		var risk_text: String = "HIGH" if risk_value > 70 else ("MED" if risk_value > 45 else "LOW")
		var risk_color: Color = UI.RED if risk_value > 70 else (UI.AMBER if risk_value > 45 else UI.GREEN)
		UI.cell(table, risk_text, 65, risk_color)

func _build_competitions(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"):
		return
	var root: VBoxContainer = _replace_page(page)
	if root == null:
		return
	_header(root, "COMPETITIONS", "League position • fixtures • objectives", tabs, session)
	var competitions: Array = []
	for competition in session.world.get("competitions", []):
		if session.managed_club_id in competition.get("club_ids", []):
			competitions.append(competition)
	var cards: GridContainer = GridContainer.new()
	cards.columns = 1 if OS.has_feature("mobile") else 2
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(cards)
	for competition in competitions:
		var card: VBoxContainer = UI.panel(cards, Vector2(380, 190), UI.CYAN)
		UI.section(card, String(competition.get("name", "Competition")))
		UI.body(card, String(competition.get("competition_type", "league")).capitalize(), true)
		var played: int = 0
		var wins: int = 0
		for fixture in session.world.get("fixtures", []):
			if String(fixture.get("competition_id", "")) != String(competition.get("id", "")):
				continue
			if not bool(fixture.get("played", false)):
				continue
			var home: bool = String(fixture.get("home_club_id", "")) == String(session.managed_club_id)
			var away: bool = String(fixture.get("away_club_id", "")) == String(session.managed_club_id)
			if not home and not away:
				continue
			played += 1
			var goals_for: int = int(fixture.get("home_goals", 0)) if home else int(fixture.get("away_goals", 0))
			var goals_against: int = int(fixture.get("away_goals", 0)) if home else int(fixture.get("home_goals", 0))
			if goals_for > goals_against:
				wins += 1
		UI.metric(card, "Record", "%d played" % played, "%d wins" % wins, UI.GREEN)

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
	fixtures.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("date", "")) < String(b.get("date", ""))
	)
	var start: int = maxi(0, fixtures.size() - 8)
	var end: int = mini(fixtures.size(), start + 20)
	for fixture in fixtures.slice(start, end):
		var home: bool = String(fixture.get("home_club_id", "")) == String(session.managed_club_id)
		var opponent_id: String = String(fixture.get("away_club_id", "")) if home else String(fixture.get("home_club_id", ""))
		var played: bool = bool(fixture.get("played", false))
		var result_text: String = "%d-%d" % [int(fixture.get("home_goals", 0)), int(fixture.get("away_goals", 0))] if played else "—"
		UI.cell(table, String(fixture.get("date", "TBD")), 90)
		UI.cell(table, "H" if home else "A", 45, UI.CYAN)
		UI.cell(table, _club_name(session.world, opponent_id).left(20), 160)
		UI.cell(table, _competition_name(session.world, String(fixture.get("competition_id", ""))).left(18), 150, UI.PURPLE)
		UI.cell(table, result_text, 70, UI.GREEN if played else UI.MUTED)
		UI.cell(table, "FT" if played else "UPCOMING", 90, UI.GREEN if played else UI.CYAN)

func _add_money_metric(parent: Control, title: String, value: int, color: Color) -> void:
	var panel: VBoxContainer = UI.panel(parent, Vector2(280, 110), color)
	UI.metric(panel, title, UI.money(value), "current allocation", color)

func _header(root: VBoxContainer, title: String, subtitle: String, _tabs: TabContainer, session) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(names)
	var heading: Label = Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", UI.TEXT)
	names.add_child(heading)
	UI.body(names, subtitle, true)
	row.add_child(UI.chip(String(session.world.get("current_date", session.world.get("date", ""))), UI.CYAN))

func _replace_page(page: Control) -> VBoxContainer:
	if page.has_meta("ui2_extended"):
		return null
	page.set_meta("ui2_extended", true)
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	scroll.add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.custom_minimum_size = Vector2(860, 0)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	return root

func _page(tabs: TabContainer, name: String) -> Control:
	for i in range(tabs.get_tab_count()):
		var page: Control = tabs.get_tab_control(i)
		if String(page.name) == name or tabs.get_tab_title(i) == name:
			return page
	return null

func _career_session(node: Node):
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			return current.get("session")
		current = current.get_parent()
	return null

func _club(world: Dictionary, id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == id:
			return club
	return {}

func _club_name(world: Dictionary, id: String) -> String:
	var club: Dictionary = _club(world, id)
	return String(club.get("name", id))

func _competition_name(world: Dictionary, id: String) -> String:
	for competition in world.get("competitions", []):
		if String(competition.get("id", "")) == id:
			return String(competition.get("name", id))
	return id

func _squad(world: Dictionary, club_id: String) -> Array:
	var rows: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
			rows.append(player)
	return rows

func _player(world: Dictionary, id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == id:
			return player
	return {}

func _player_name(player: Dictionary) -> String:
	var name: String = String(player.get("name", "")).strip_edges()
	if name != "":
		return name
	return (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()

func _shortlist(world: Dictionary, club_id: String, limit: int) -> Array:
	var rows: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id or bool(player.get("retired", false)):
			continue
		rows.append(player)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("potential", 0)) + int(a.get("current_ability", 0)) > int(b.get("potential", 0)) + int(b.get("current_ability", 0))
	)
	return rows.slice(0, mini(limit, rows.size()))

func _value(player: Dictionary) -> int:
	var ability: int = int(player.get("current_ability", 50))
	var potential: int = int(player.get("potential", ability))
	var age: int = int(player.get("age", 25))
	var factor: float = 1.25 if age <= 23 else (1.0 if age <= 28 else maxf(0.35, 1.0 - float(age - 28) * 0.09))
	return int((ability * ability * 900 + maxi(0, potential - ability) * ability * 450) * factor)

func _risk(player: Dictionary) -> int:
	return (100 - int(player.get("fitness", 100))) + int(player.get("fatigue", 0)) + (40 if int(player.get("injured_days", 0)) > 0 else 0)

func _sum(values: Array) -> float:
	var total: float = 0.0
	for value in values:
		total += float(value)
	return total
