extends Node

const CareerQuery = preload("res://application/career/career_query.gd")
const CareerCommand = preload("res://application/career/career_command_service.gd")
const DynamicsActions = preload("res://application/career/dynamics_actions.gd")
const PlayerProfileDialog = preload("res://game/presentation/player_profile_dialog.gd")

var _next_scan: int = 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 700
	_scan()

func _scan() -> void:
	var app: Node = _find_app(get_tree().root)
	if app == null:
		return
	var tabs: TabContainer = _find_career_tabs(app)
	if tabs == null:
		return
	_wire_dynamics(tabs, app)
	_wire_training(tabs, app)
	_wire_medical(tabs, app)
	_wire_schedule(tabs, app)
	_wire_competitions(tabs, app)
	_wire_scouting(tabs, app)
	_wire_search(tabs, app)
	_wire_world(tabs, app)
	_wire_finance(tabs, app)

func _wire_dynamics(tabs: TabContainer, app: Node) -> void:
	var page: Control = _page(tabs, "Dynamics")
	if page == null or page.has_meta("playtest_depth"):
		return
	page.set_meta("playtest_depth", true)
	for node in page.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button != null and button.text.strip_edges().to_lower() == "appoint captain":
			var row: Node = button.get_parent()
			if row is Control:
				(row as Control).hide()
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var session = app.get("session")
	var world: Dictionary = session.get("world")
	var club_id: String = String(session.get("managed_club_id"))
	var candidates: Array = DynamicsActions.new().captain_candidates(world, club_id)
	_heading(box, "Captaincy")
	var row := HBoxContainer.new()
	box.add_child(row)
	var selector := OptionButton.new()
	selector.custom_minimum_size.x = 420
	row.add_child(selector)
	for candidate in candidates.slice(0, mini(12, candidates.size())):
		selector.add_item("%s — Leadership %d • Influence %.0f" % [String(candidate.get("name", "Player")), int(candidate.get("leadership", 0)), float(candidate.get("influence", 0.0))])
		selector.set_item_metadata(selector.item_count - 1, String(candidate.get("id", "")))
	var apply := Button.new()
	apply.text = "Appoint captain"
	row.add_child(apply)
	var result := Label.new()
	box.add_child(result)
	apply.pressed.connect(_appoint_captain.bind(world, club_id, selector, result))

func _appoint_captain(world: Dictionary, club_id: String, selector: OptionButton, result: Label) -> void:
	if selector.item_count == 0:
		result.text = "No eligible captain candidate."
		return
	var player_id: String = String(selector.get_item_metadata(selector.selected))
	var error: Error = DynamicsActions.new().set_captain(world, club_id, player_id)
	result.text = "Captain updated." if error == OK else "Captain appointment failed."

func _wire_training(tabs: TabContainer, app: Node) -> void:
	var page: Control = _page(tabs, "Training")
	if page == null or page.has_meta("playtest_depth"):
		return
	page.set_meta("playtest_depth", true)
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var session = app.get("session")
	var world: Dictionary = session.get("world")
	var club_id: String = String(session.get("managed_club_id"))
	var data: Dictionary = CareerQuery.new().training(world, club_id)
	_heading(box, "Training effects")
	var intensity: float = float(data.get("intensity", 0.65))
	var facilities: int = int(data.get("facilities", 50))
	_label(box, "Training runs every week. Development is driven by potential gap, age, coaching, facilities and professionalism. Higher intensity raises development but also fatigue and injury risk.")
	_label(box, "Current load: %.0f%% • Facilities: %d/100 • Estimated workload risk: %s" % [intensity * 100.0, facilities, _risk_band(intensity)])
	var changes: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) != club_id:
			continue
		var history: Array = player.get("development_history", [])
		if history.is_empty():
			continue
		var last: Dictionary = history[history.size() - 1]
		changes.append({"name": _person_name(player), "delta": int(last.get("delta", 0))})
	changes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return abs(int(a.get("delta", 0))) > abs(int(b.get("delta", 0))))
	for item in changes.slice(0, mini(8, changes.size())):
		_label(box, "%s — latest development %+d CA" % [String(item.get("name", "Player")), int(item.get("delta", 0))])

func _wire_medical(tabs: TabContainer, app: Node) -> void:
	var page: Control = _page(tabs, "Medical")
	if page == null or page.has_meta("playtest_depth"):
		return
	page.set_meta("playtest_depth", true)
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var session = app.get("session")
	var world: Dictionary = session.get("world")
	var club_id: String = String(session.get("managed_club_id"))
	_heading(box, "Medical risk centre")
	var rows: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)):
			continue
		var fitness: int = int(player.get("fitness", 100))
		var fatigue: int = int(player.get("fatigue", maxi(0, 100 - fitness)))
		var hidden: Dictionary = player.get("hidden_attributes", {})
		var proneness: int = int(hidden.get("injury_proneness", player.get("injury_proneness", 25)))
		var days: int = int(player.get("injured_days", 0))
		var risk: int = clampi(int((100 - fitness) * 0.4 + fatigue * 0.35 + proneness * 0.35), 0, 100)
		rows.append({"player": player, "risk": risk, "days": days})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("days", 0)) != int(b.get("days", 0)):
			return int(a.get("days", 0)) > int(b.get("days", 0))
		return int(a.get("risk", 0)) > int(b.get("risk", 0))
	)
	for item in rows.slice(0, mini(18, rows.size())):
		var player: Dictionary = item.get("player", {})
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if int(item.get("days", 0)) > 0:
			button.text = "%s — INJURED • %d days remaining" % [_person_name(player), int(item.get("days", 0))]
		else:
			button.text = "%s — Risk %d%% • Fitness %d • Fatigue %d" % [_person_name(player), int(item.get("risk", 0)), int(player.get("fitness", 100)), int(player.get("fatigue", 0))]
		button.pressed.connect(_open_player.bind(app, String(player.get("id", ""))))
		box.add_child(button)

func _wire_schedule(tabs: TabContainer, app: Node) -> void:
	var page: Control = _page(tabs, "Schedule")
	if page == null or page.has_meta("playtest_depth"):
		return
	page.set_meta("playtest_depth", true)
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var session = app.get("session")
	var world: Dictionary = session.get("world")
	var club_id: String = String(session.get("managed_club_id"))
	_heading(box, "Fixture centre")
	for fixture in CareerQuery.new().schedule(world, club_id, 20):
		var home: String = _club_name(world, String(fixture.get("home_club_id", "")))
		var away: String = _club_name(world, String(fixture.get("away_club_id", "")))
		var score: String = "vs"
		if bool(fixture.get("played", false)):
			score = "%d–%d" % [int(fixture.get("home_goals", 0)), int(fixture.get("away_goals", 0))]
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s • %s %s %s • %s" % [String(fixture.get("date", "TBD")), home, score, away, String(fixture.get("competition_id", ""))]
		button.pressed.connect(_fixture_dialog.bind(app, fixture))
		box.add_child(button)

func _fixture_dialog(app: Node, fixture: Dictionary) -> void:
	var session = app.get("session")
	var world: Dictionary = session.get("world")
	var dialog := AcceptDialog.new()
	app.add_child(dialog)
	dialog.title = "%s vs %s" % [_club_name(world, String(fixture.get("home_club_id", ""))), _club_name(world, String(fixture.get("away_club_id", "")))]
	var lines: Array[String] = []
	lines.append("Date: %s" % String(fixture.get("date", "TBD")))
	lines.append("Competition: %s" % String(fixture.get("competition_id", "")))
	lines.append("Venue: %s" % String(fixture.get("venue", fixture.get("stadium", "TBD"))))
	if bool(fixture.get("played", false)):
		lines.append("Score: %d - %d" % [int(fixture.get("home_goals", 0)), int(fixture.get("away_goals", 0))])
	for key in ["attendance", "home_shots", "away_shots", "home_xg", "away_xg", "home_possession", "away_possession"]:
		if fixture.has(key):
			lines.append("%s: %s" % [String(key).replace("_", " ").capitalize(), str(fixture.get(key))])
	dialog.dialog_text = "\n".join(lines)
	dialog.popup_centered(Vector2i(700, 420))

func _wire_competitions(tabs: TabContainer, app: Node) -> void:
	var page: Control = _page(tabs, "Competitions")
	if page == null or page.has_meta("playtest_depth"):
		return
	page.set_meta("playtest_depth", true)
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var session = app.get("session")
	var world: Dictionary = session.get("world")
	var club_id: String = String(session.get("managed_club_id"))
	for competition in world.get("competitions", []):
		if club_id not in competition.get("club_ids", []):
			continue
		_heading(box, "%s — table" % String(competition.get("name", "Competition")))
		var table: Array = CareerQuery.new().competition_table(world, String(competition.get("id", "")))
		for row in table:
			var button := Button.new()
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.text = "%2d  %-24s  P %2d  W %2d  D %2d  L %2d  GF %2d  GA %2d  GD %+3d  Pts %3d" % [int(row.get("position", 0)), _club_name(world, String(row.get("club_id", ""))), int(row.get("played", 0)), int(row.get("won", 0)), int(row.get("drawn", 0)), int(row.get("lost", 0)), int(row.get("gf", 0)), int(row.get("ga", 0)), int(row.get("gd", 0)), int(row.get("points", 0))]
			button.pressed.connect(_club_dialog.bind(app, String(row.get("club_id", ""))))
			box.add_child(button)
		break

func _wire_scouting(tabs: TabContainer, app: Node) -> void:
	var page: Control = _page(tabs, "Scouting")
	if page == null or page.has_meta("playtest_depth"):
		return
	page.set_meta("playtest_depth", true)
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var session = app.get("session")
	var world: Dictionary = session.get("world")
	var club_id: String = String(session.get("managed_club_id"))
	_heading(box, "Scouting shortlist")
	for player in CareerCommand.new().shortlist(world, club_id, 12):
		var row := HBoxContainer.new()
		box.add_child(row)
		var profile := Button.new()
		profile.text = "%s • %s • Age %d" % [_person_name(player), String(player.get("position", "")), int(player.get("age", 0))]
		profile.pressed.connect(_open_player.bind(app, String(player.get("id", ""))))
		row.add_child(profile)
		var scout := Button.new()
		scout.text = "Scout"
		scout.pressed.connect(_scout_player.bind(world, club_id, String(player.get("id", "")), scout))
		row.add_child(scout)

func _scout_player(world: Dictionary, club_id: String, player_id: String, button: Button) -> void:
	var result: Dictionary = CareerCommand.new().assign_scout(world, club_id, player_id)
	button.text = "Scouting…" if not result.has("error") else "No scout available"
	button.disabled = not result.has("error")

func _wire_search(tabs: TabContainer, app: Node) -> void:
	var page: Control = _page(tabs, "Search")
	if page == null or page.has_meta("playtest_depth"):
		return
	page.set_meta("playtest_depth", true)
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var session = app.get("session")
	var world: Dictionary = session.get("world")
	_heading(box, "Openable global search")
	var input := LineEdit.new()
	input.placeholder_text = "Search player, club or staff — results open full details"
	box.add_child(input)
	var results := VBoxContainer.new()
	box.add_child(results)
	input.text_changed.connect(_render_search.bind(app, world, results))

func _render_search(text: String, app: Node, world: Dictionary, results: VBoxContainer) -> void:
	for child in results.get_children():
		child.queue_free()
	if text.strip_edges().length() < 2:
		return
	for item in CareerQuery.new().world_search(world, text, 20):
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s — %s" % [String(item.get("type", "")).to_upper(), String(item.get("name", ""))]
		var kind: String = String(item.get("type", ""))
		var id: String = String(item.get("id", ""))
		if kind == "player":
			button.pressed.connect(_open_player.bind(app, id))
		elif kind == "club":
			button.pressed.connect(_club_dialog.bind(app, id))
		else:
			button.pressed.connect(_staff_dialog.bind(app, id))
		results.add_child(button)

func _wire_world(tabs: TabContainer, app: Node) -> void:
	var page: Control = _page(tabs, "World")
	if page == null or page.has_meta("playtest_depth"):
		return
	page.set_meta("playtest_depth", true)
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var session = app.get("session")
	var world: Dictionary = session.get("world")
	_heading(box, "Awards history")
	var awards: Array = world.get("awards", [])
	if awards.is_empty():
		_label(box, "Season awards are recorded at season end: Player of the Year, Top Scorer, Playmaker, Young Player, Goalkeeper, Defender, Golden Glove, Manager and Team of the Season.")
	else:
		var ordered: Array = awards.duplicate(true)
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("season_year", 0)) > int(b.get("season_year", 0)))
		for award in ordered.slice(0, mini(40, ordered.size())):
			var winner: String = String(award.get("player_id", award.get("manager_id", "")))
			_label(box, "%d • %s • %s • %s" % [int(award.get("season_year", 0)), String(award.get("competition_id", "World")), String(award.get("type", "award")).replace("_", " ").capitalize(), _person_name_by_id(world, winner)])

func _wire_finance(tabs: TabContainer, app: Node) -> void:
	var page: Control = _page(tabs, "Finances")
	if page == null:
		page = _page(tabs, "Finance")
	if page == null or page.has_meta("playtest_depth"):
		return
	page.set_meta("playtest_depth", true)
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var session = app.get("session")
	var world: Dictionary = session.get("world")
	var club_id: String = String(session.get("managed_club_id"))
	var finance: Dictionary = CareerQuery.new().finances(world, club_id)
	_heading(box, "Financial detail")
	_label(box, "League finishes and competition success feed prize-money and broadcast revenue at season settlement. Sponsorship, gates, wages, operations, transfers and loans are posted to the ledger.")
	var income: int = 0
	var expenses: int = 0
	var prize: int = 0
	for entry in finance.get("ledger", []):
		var amount: int = int(entry.get("amount", 0))
		if amount >= 0: income += amount
		else: expenses += -amount
		if String(entry.get("category", "")) == "prize_money": prize += amount
	_label(box, "Cash %d • Debt %d • Ledger income %d • expenses %d • prize money %d" % [int(finance.get("cash", 0)), int(finance.get("debt", 0)), income, expenses, prize])
	var squad_value: int = 0
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id:
			squad_value += _market_value(player)
	_label(box, "Estimated squad market value: %d" % squad_value)

func _market_value(player: Dictionary) -> int:
	var ability: float = float(player.get("current_ability", 50))
	var potential: float = float(player.get("potential", ability))
	var age: int = int(player.get("age", 25))
	var reputation: float = float(player.get("reputation", ability))
	var morale: float = float(player.get("morale", 50))
	var age_factor: float = 1.35 if age <= 22 else (1.1 if age <= 27 else maxf(0.35, 1.1 - float(age - 27) * 0.08))
	var potential_bonus: float = maxf(0.0, potential - ability) * 32000.0
	var base: float = ability * ability * 950.0 + potential_bonus + reputation * 18000.0
	var form_factor: float = 0.9 + morale / 500.0
	return maxi(10000, int(base * age_factor * form_factor))

func _open_player(app: Node, player_id: String) -> void:
	var session = app.get("session")
	var dialog := PlayerProfileDialog.new()
	app.add_child(dialog)
	dialog.setup(session.get("world"), player_id, String(session.get("managed_club_id")))
	dialog.popup_centered(Vector2i(960, 680))

func _club_dialog(app: Node, club_id: String) -> void:
	var session = app.get("session")
	var world: Dictionary = session.get("world")
	var profile: Dictionary = CareerQuery.new().club_profile(world, club_id)
	if profile.is_empty():
		return
	var club: Dictionary = profile.get("club", {})
	var dialog := AcceptDialog.new()
	app.add_child(dialog)
	dialog.title = String(club.get("name", "Club"))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(820, 540)
	dialog.add_child(tabs)
	var overview := VBoxContainer.new(); overview.name = "Overview"; tabs.add_child(overview)
	_label(overview, "Country %s • Tier %d • Reputation %d • Cash %d" % [String(club.get("country_id", "")), int(club.get("tier", 1)), int(club.get("reputation", 0)), int(club.get("cash", 0))])
	_label(overview, "Competitions: %s" % ", ".join(profile.get("competitions", [])))
	var squad := VBoxContainer.new(); squad.name = "Players"; tabs.add_child(squad)
	for row in profile.get("squad", []).slice(0, mini(35, profile.get("squad", []).size())):
		var button := Button.new(); button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s • %s • Age %d • CA %d • PA %d" % [String(row.get("name", "Player")), String(row.get("position", "")), int(row.get("age", 0)), int(row.get("ability", 0)), int(row.get("potential", 0))]
		button.pressed.connect(_open_player.bind(app, String(row.get("id", ""))))
		squad.add_child(button)
	var staff := VBoxContainer.new(); staff.name = "Staff"; tabs.add_child(staff)
	for member in profile.get("staff", []):
		var button := Button.new(); button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s • %s • Ability %d" % [_person_name(member), String(member.get("role", "staff")).capitalize(), int(member.get("ability", 0))]
		button.pressed.connect(_staff_dialog.bind(app, String(member.get("id", ""))))
		staff.add_child(button)
	dialog.popup_centered(Vector2i(900, 650))

func _staff_dialog(app: Node, staff_id: String) -> void:
	var session = app.get("session")
	var profile: Dictionary = CareerQuery.new().staff_profile(session.get("world"), staff_id)
	if profile.is_empty(): return
	var member: Dictionary = profile.get("staff", {})
	var club: Dictionary = profile.get("club", {})
	var dialog := AcceptDialog.new(); app.add_child(dialog)
	dialog.title = _person_name(member)
	dialog.dialog_text = "Role: %s\nAbility: %d\nReputation: %d\nClub: %s\nWage: %s\nLicenses: %s" % [String(member.get("role", "staff")).capitalize(), int(member.get("ability", 0)), int(member.get("reputation", 0)), String(club.get("name", "Unattached")), str(member.get("weekly_wage", member.get("wage", "—"))), ", ".join(member.get("licenses", []))]
	dialog.popup_centered(Vector2i(620, 360))

func _risk_band(intensity: float) -> String:
	if intensity >= 0.82: return "HIGH — fatigue and injury probability elevated"
	if intensity >= 0.62: return "MODERATE — balanced development and recovery"
	return "LOW — recovery focused, slower development"

func _find_app(node: Node) -> Node:
	var script = node.get_script()
	if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"): return node
	for child in node.get_children():
		var found: Node = _find_app(child)
		if found != null: return found
	return null

func _find_career_tabs(app: Node) -> TabContainer:
	for node in app.find_children("*", "TabContainer", true, false):
		var tabs: TabContainer = node as TabContainer
		if tabs != null and _tab_index(tabs, "Dashboard") >= 0 and _tab_index(tabs, "Squad") >= 0: return tabs
	return null

func _page(tabs: TabContainer, title: String) -> Control:
	var index: int = _tab_index(tabs, title)
	return tabs.get_tab_control(index) if index >= 0 else null

func _tab_index(tabs: TabContainer, title: String) -> int:
	for i in range(tabs.get_tab_count()):
		if tabs.get_tab_title(i).strip_edges().to_lower() == title.to_lower() or String(tabs.get_tab_control(i).name).to_lower() == title.to_lower(): return i
	return -1

func _first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer: return node as VBoxContainer
	for child in node.get_children():
		var found: VBoxContainer = _first_vbox(child)
		if found != null: return found
	return null

func _heading(parent: Control, text: String) -> void:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", 18); parent.add_child(label)

func _label(parent: Control, text: String) -> void:
	var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label)

func _club_name(world: Dictionary, club_id: String) -> String:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return String(club.get("name", club_id))
	return club_id

func _person_name(person: Dictionary) -> String:
	var name: String = String(person.get("name", "")).strip_edges()
	return name if name != "" else (String(person.get("first_name", "")) + " " + String(person.get("last_name", ""))).strip_edges()

func _person_name_by_id(world: Dictionary, id: String) -> String:
	if id == "": return "—"
	for player in world.get("players", []):
		if String(player.get("id", "")) == id: return _person_name(player)
	for member in world.get("staff", []):
		if String(member.get("id", "")) == id: return _person_name(member)
	return id
