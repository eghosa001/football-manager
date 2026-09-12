class_name PlayerProfileDialog
extends AcceptDialog

const UI = preload("res://game/presentation/fd_ui2.gd")
const PlayerStats = preload("res://application/career/player_stats_service.gd")
const Medical = preload("res://simulation/players/medical_system.gd")

var world: Dictionary = {}
var player_id: String = ""
var managed_club_id: String = ""

func setup(career_world: Dictionary, id: String, club_id: String) -> void:
	world = career_world
	player_id = id
	managed_club_id = club_id
	var player: Dictionary = _player()
	title = _name(player)
	min_size = Vector2i(980, 700)
	var tabs: TabContainer = TabContainer.new()
	tabs.custom_minimum_size = Vector2(940, 610)
	add_child(tabs)
	_add_overview(tabs, player)
	_add_attributes(tabs, player)
	_add_performance(tabs, player)
	_add_development(tabs, player)
	_add_contract(tabs)
	_add_medical(tabs, player)
	_add_history(tabs, player)
	_add_relationships(tabs)
	_add_reports(tabs, player)

func _add_overview(tabs: TabContainer, player: Dictionary) -> void:
	var box: VBoxContainer = _tab(tabs, "Overview")
	var hero: HBoxContainer = HBoxContainer.new()
	hero.add_theme_constant_override("separation", 14)
	box.add_child(hero)

	var identity: VBoxContainer = UI.panel(hero, Vector2(350, 220), UI.CYAN)
	var name_label: Label = Label.new()
	name_label.text = _name(player)
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", UI.TEXT)
	identity.add_child(name_label)
	identity.add_child(UI.chip(String(player.get("position", "—")), UI.CYAN))
	UI.body(identity, "Age %d • %s • %s foot" % [int(player.get("age", 0)), String(player.get("country_id", player.get("nationality_id", "—"))).to_upper(), String(player.get("preferred_foot", "—")).capitalize()], true)
	UI.metric(identity, "Market value", UI.money(_estimated_value(player)), "Weekly wage %s" % UI.money(_weekly_wage()), UI.GREEN)

	var ratings: VBoxContainer = UI.panel(hero, Vector2(260, 220), UI.PURPLE)
	UI.section(ratings, "PLAYER LEVEL", UI.PURPLE)
	UI.metric(ratings, "Current ability", UI.stars(int(player.get("current_ability", 0))), str(player.get("current_ability", 0)), UI.AMBER)
	UI.metric(ratings, "Potential", UI.stars(int(player.get("potential", 0))), str(player.get("potential", 0)), UI.AMBER)
	UI.metric(ratings, "Reputation", str(player.get("reputation", 0)), "standing in the game", UI.PURPLE)

	var readiness: VBoxContainer = UI.panel(hero, Vector2(260, 220), UI.GREEN)
	UI.section(readiness, "READINESS", UI.GREEN)
	_ready_metric(readiness, "Condition", int(player.get("fitness", 0)))
	_ready_metric(readiness, "Sharpness", int(player.get("match_sharpness", 0)))
	_ready_metric(readiness, "Morale", int(player.get("morale", 0)))

	var traits_box: VBoxContainer = UI.panel(box, Vector2(0, 120), UI.CYAN)
	UI.section(traits_box, "PLAYER TRAITS")
	var traits: Array = player.get("traits", [])
	if traits.is_empty():
		UI.body(traits_box, "No notable player traits recorded.", true)
	else:
		var flow: HFlowContainer = HFlowContainer.new()
		traits_box.add_child(flow)
		for trait in traits:
			flow.add_child(UI.chip(String(trait).replace("_", " ").capitalize(), UI.CYAN))

func _ready_metric(parent: Control, label_text: String, value: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 85
	label.add_theme_color_override("font_color", UI.MUTED)
	row.add_child(label)
	UI.progress(row, float(value), UI.score_color(float(value)), 120)
	var number: Label = Label.new()
	number.text = str(value)
	number.add_theme_color_override("font_color", UI.score_color(float(value)))
	row.add_child(number)

func _add_attributes(tabs: TabContainer, player: Dictionary) -> void:
	var box: VBoxContainer = _tab(tabs, "Attributes")
	var attrs: Dictionary = player.get("attributes", {})
	var keys: Array = attrs.keys()
	keys.sort()
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	box.add_child(columns)
	var labels: Array[String] = ["TECHNICAL", "MENTAL", "PHYSICAL"]
	var colors: Array[Color] = [UI.CYAN, UI.GREEN, UI.PURPLE]
	var chunk: int = maxi(1, int(ceil(float(keys.size()) / 3.0)))
	for column_index in range(3):
		var pane: VBoxContainer = UI.panel(columns, Vector2(275, 500), colors[column_index])
		UI.section(pane, labels[column_index], colors[column_index])
		var start: int = chunk * column_index
		var finish: int = mini(keys.size(), chunk * (column_index + 1))
		for i in range(start, finish):
			var key: String = String(keys[i])
			var row: HBoxContainer = HBoxContainer.new()
			pane.add_child(row)
			var attr_label: Label = UI.body(row, key.replace("_", " ").capitalize())
			attr_label.custom_minimum_size.x = 145
			var value: int = int(attrs.get(key, 0))
			UI.progress(row, float(value) * 5.0, UI.score_color(float(value) * 5.0), 80)
			var value_label: Label = UI.body(row, str(value))
			value_label.add_theme_color_override("font_color", UI.score_color(float(value) * 5.0))

func _add_performance(tabs: TabContainer, _player_data: Dictionary) -> void:
	var box: VBoxContainer = _tab(tabs, "Performance")
	var totals: Dictionary = PlayerStats.new().season_totals(world, player_id)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	_add_stat_card(top, "APPEARANCES", str(int(totals.get("appearances", 0))), UI.CYAN)
	_add_stat_card(top, "GOALS", str(int(totals.get("goals", 0))), UI.GREEN)
	_add_stat_card(top, "SHOTS", str(int(totals.get("shots", 0))), UI.PURPLE)
	_add_stat_card(top, "xG", "%.2f" % float(totals.get("xg", 0.0)), UI.AMBER)

	var efficiency: VBoxContainer = UI.panel(box, Vector2(0, 100), UI.CYAN)
	UI.section(efficiency, "EFFICIENCY")
	UI.body(efficiency, "Passing %d/%d • Dribbles %d/%d" % [int(totals.get("passes_completed", 0)), int(totals.get("passes", 0)), int(totals.get("dribbles_completed", 0)), int(totals.get("dribbles", 0))])

	var panel: VBoxContainer = UI.panel(box, Vector2(0, 300), UI.PURPLE)
	UI.section(panel, "RECENT MATCHES", UI.PURPLE)
	var table: GridContainer = GridContainer.new()
	table.columns = 5
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(table)
	UI.table_header(table, ["MATCH", "GOALS", "SHOTS", "xG", "PASSES"])
	var rows: Array = []
	for stat in world.get("player_match_stats", []):
		if String(stat.get("player_id", "")) == player_id:
			rows.append(stat)
	for stat in rows.slice(maxi(0, rows.size() - 10)):
		UI.cell(table, String(stat.get("fixture_id", "Match")).left(22), 170)
		UI.cell(table, str(stat.get("goals", 0)), 55, UI.GREEN)
		UI.cell(table, str(stat.get("shots", 0)), 55)
		UI.cell(table, "%.2f" % float(stat.get("xg", 0.0)), 60, UI.AMBER)
		UI.cell(table, "%d/%d" % [int(stat.get("passes_completed", 0)), int(stat.get("passes", 0))], 85, UI.CYAN)

func _add_stat_card(parent: Control, label_text: String, value: String, color: Color) -> void:
	var panel: VBoxContainer = UI.panel(parent, Vector2(190, 105), color)
	UI.metric(panel, label_text, value, "this season", color)

func _add_development(tabs: TabContainer, player: Dictionary) -> void:
	var box: VBoxContainer = _tab(tabs, "Development")
	var plan: VBoxContainer = UI.panel(box, Vector2(0, 125), UI.PURPLE)
	UI.section(plan, "CURRENT DEVELOPMENT PLAN", UI.PURPLE)
	UI.metric(plan, "Training focus", String(player.get("training_focus", "balanced")).capitalize(), "individual programme", UI.PURPLE)
	var history: Array = player.get("development_history", [])
	var panel: VBoxContainer = UI.panel(box, Vector2(0, 330), UI.CYAN)
	UI.section(panel, "DEVELOPMENT HISTORY")
	if history.is_empty():
		UI.body(panel, "No annual development record yet.", true)
	for record in history.slice(maxi(0, history.size() - 12)):
		var line: HBoxContainer = HBoxContainer.new()
		panel.add_child(line)
		var season: Label = UI.body(line, String(record.get("season_year", "")))
		season.custom_minimum_size.x = 100
		var delta: int = int(record.get("delta", 0))
		line.add_child(UI.chip("CA %d → %d" % [int(record.get("before", 0)), int(record.get("after", 0))], UI.GREEN if delta >= 0 else UI.RED))
		line.add_child(UI.chip("%+d" % delta, UI.GREEN if delta >= 0 else UI.RED))
		UI.body(line, "%d apps" % int(record.get("appearances", 0)), true)

func _add_contract(tabs: TabContainer) -> void:
	var box: VBoxContainer = _tab(tabs, "Contract")
	var contract: Dictionary = _contract()
	if contract.is_empty():
		UI.body(box, "No active contract.", true)
		return
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	var club_panel: VBoxContainer = UI.panel(top, Vector2(280, 150), UI.CYAN)
	UI.metric(club_panel, "Club", _club_name(String(contract.get("club_id", ""))), "Current employer", UI.CYAN)
	var wage_panel: VBoxContainer = UI.panel(top, Vector2(280, 150), UI.GREEN)
	UI.metric(wage_panel, "Weekly wage", UI.money(int(contract.get("weekly_wage", 0))), "contract value", UI.GREEN)
	var expiry_panel: VBoxContainer = UI.panel(top, Vector2(280, 150), UI.PURPLE)
	UI.metric(expiry_panel, "Contract end", str(contract.get("end_year", "—")), "started %s" % str(contract.get("start_year", "—")), UI.PURPLE)
	var terms: VBoxContainer = UI.panel(box, Vector2(0, 260), UI.AMBER)
	UI.section(terms, "BONUSES & CLAUSES", UI.AMBER)
	for key in ["signing_bonus", "release_clause", "appearance_fee", "goal_bonus"]:
		if contract.has(key):
			UI.metric(terms, String(key).replace("_", " ").capitalize(), UI.money(int(contract.get(key, 0))), "", UI.AMBER)

func _add_medical(tabs: TabContainer, player: Dictionary) -> void:
	var box: VBoxContainer = _tab(tabs, "Medical")
	var report: Dictionary = Medical.new().report(player)
	var cards: GridContainer = GridContainer.new()
	cards.columns = 3
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(cards)
	for raw_key in report.keys():
		var key: String = String(raw_key)
		var panel: VBoxContainer = UI.panel(cards, Vector2(250, 110), UI.RED)
		UI.metric(panel, key.replace("_", " ").capitalize(), str(report.get(raw_key)), "medical report", UI.RED)
	var history: Array = player.get("injury_history", [])
	var history_panel: VBoxContainer = UI.panel(box, Vector2(0, 250), UI.RED)
	UI.section(history_panel, "INJURY HISTORY", UI.RED)
	if history.is_empty():
		UI.body(history_panel, "No recorded injuries.", true)
	for injury in history:
		UI.body(history_panel, "%s • %d days • %s" % [String(injury.get("season_year", injury.get("date", ""))), int(injury.get("days", 0)), String(injury.get("source", "injury")).capitalize()])

func _add_history(tabs: TabContainer, player: Dictionary) -> void:
	var box: VBoxContainer = _tab(tabs, "History")
	var metric_panel: VBoxContainer = UI.panel(box, Vector2(0, 100), UI.CYAN)
	UI.metric(metric_panel, "Career appearances", str(player.get("career_appearances", 0)), "senior career", UI.CYAN)
	var panel: VBoxContainer = UI.panel(box, Vector2(0, 360), UI.PURPLE)
	UI.section(panel, "CAREER RECORD", UI.PURPLE)
	for record in world.get("player_history", []):
		if String(record.get("player_id", "")) != player_id:
			continue
		UI.body(panel, "%s • %s • %s • %d apps • %d goals • %.2f xG" % [String(record.get("season_year", "")), _club_name(String(record.get("club_id", ""))), _competition_name(String(record.get("competition_id", ""))), int(record.get("appearances", 0)), int(record.get("goals", 0)), float(record.get("xg", 0.0))])

func _add_relationships(tabs: TabContainer) -> void:
	var box: VBoxContainer = _tab(tabs, "Relationships")
	var panel: VBoxContainer = UI.panel(box, Vector2(0, 420), UI.CYAN)
	UI.section(panel, "RELATIONSHIPS")
	var count: int = 0
	for relationship in world.get("relationships", []):
		var source: String = String(relationship.get("source_person_id", relationship.get("source_id", "")))
		var target: String = String(relationship.get("target_person_id", relationship.get("target_id", "")))
		if source != player_id and target != player_id:
			continue
		var other: String = target if source == player_id else source
		var row: HBoxContainer = HBoxContainer.new()
		panel.add_child(row)
		var name_label: Label = UI.body(row, _person_name(other))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(UI.chip(String(relationship.get("relationship_type", relationship.get("type", "relationship"))).replace("_", " ").capitalize(), UI.PURPLE))
		row.add_child(UI.chip(str(relationship.get("strength", 0)), UI.CYAN))
		count += 1
	if count == 0:
		UI.body(panel, "No notable relationships recorded.", true)

func _add_reports(tabs: TabContainer, player: Dictionary) -> void:
	var box: VBoxContainer = _tab(tabs, "Reports")
	var panel: VBoxContainer = UI.panel(box, Vector2(0, 430), UI.GREEN)
	UI.section(panel, "SCOUT REPORT", UI.GREEN)
	var knowledge: Dictionary = world.get("scouting_knowledge", {}).get(managed_club_id, {})
	var report = knowledge.get(player_id, {})
	if typeof(report) == TYPE_DICTIONARY and not (report as Dictionary).is_empty():
		var report_dict: Dictionary = report
		for raw_key in report_dict.keys():
			var key: String = String(raw_key)
			UI.metric(panel, key.replace("_", " ").capitalize(), str(report_dict.get(raw_key)), "", UI.GREEN)
	else:
		UI.body(panel, "No current scouting report from your club.", true)
	var hidden: Dictionary = player.get("hidden_attributes", {})
	var descriptions: Array[String] = []
	if int(hidden.get("professionalism", 50)) >= 75:
		descriptions.append("Highly professional")
	if int(hidden.get("consistency", 50)) >= 75:
		descriptions.append("Consistent performer")
	if int(hidden.get("important_matches", 50)) >= 75:
		descriptions.append("Enjoys important matches")
	if int(hidden.get("injury_proneness", 50)) >= 70:
		descriptions.append("May be susceptible to injuries")
	if int(hidden.get("adaptability", 50)) <= 30:
		descriptions.append("May need time to adapt")
	for text in descriptions:
		panel.add_child(UI.chip(text, UI.AMBER))

func _tab(tabs: TabContainer, name: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(880, 520)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, name)
	return box

func _player() -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id:
			return player
	return {}

func _contract() -> Dictionary:
	for contract in world.get("contracts", []):
		if String(contract.get("player_id", "")) == player_id and not bool(contract.get("expired", false)):
			return contract
	return {}

func _weekly_wage() -> int:
	return int(_contract().get("weekly_wage", 0))

func _club_name(id: String) -> String:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == id:
			return String(club.get("name", id))
	return id

func _competition_name(id: String) -> String:
	for competition in world.get("competitions", []):
		if String(competition.get("id", "")) == id:
			return String(competition.get("name", id))
	return id

func _person_name(id: String) -> String:
	for player in world.get("players", []):
		if String(player.get("id", "")) == id:
			return _name(player)
	for staff_member in world.get("staff", []):
		if String(staff_member.get("id", "")) == id:
			return String(staff_member.get("name", id))
	return id

func _name(player: Dictionary) -> String:
	var name: String = String(player.get("name", "")).strip_edges()
	if name != "":
		return name
	return (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()

func _estimated_value(player: Dictionary) -> int:
	var ability: int = int(player.get("current_ability", 50))
	var potential: int = int(player.get("potential", ability))
	var age: int = int(player.get("age", 25))
	var age_factor: float = 1.25 if age <= 23 else (1.0 if age <= 28 else maxf(0.35, 1.0 - float(age - 28) * 0.09))
	return int((ability * ability * 900 + maxi(0, potential - ability) * ability * 450) * age_factor)
