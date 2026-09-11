extends Node

const LeagueTable = preload("res://simulation/competitions/league_table.gd")

var _next_scan := 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 900
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer:
		_complete_dashboard(node)
	for child in node.get_children():
		_scan_node(child)

func _complete_dashboard(tabs: TabContainer) -> void:
	if tabs.has_meta("dashboard_complete"):
		return
	var dashboard: Control = null
	for child in tabs.get_children():
		if String(child.name) == "Dashboard":
			dashboard = child
			break
	if dashboard == null:
		return
	var session = _career_session(tabs)
	if session == null or session.world.is_empty():
		return
	var box := _first_vbox(dashboard)
	if box == null:
		return
	tabs.set_meta("dashboard_complete", true)
	var world: Dictionary = session.world
	var club_id := String(session.managed_club_id)
	var club := _club(world, club_id)

	_heading(box, tr("Manager overview"))
	var competition := _league_for_club(world, club_id)
	if not competition.is_empty():
		var table := _table(world, competition)
		for i in range(table.size()):
			if String(table[i].get("club_id", "")) == club_id:
				_line(box, tr("League position: %d of %d • %d points from %d matches") % [i + 1, table.size(), int(table[i].get("points", 0)), int(table[i].get("played", 0))])
				break

	var recent := _recent_results(world, club_id, 5)
	_line(box, tr("Recent results: %s") % (" • ".join(recent) if not recent.is_empty() else tr("No matches played yet")))
	var upcoming := _upcoming(world, club_id, 3)
	_line(box, tr("Upcoming fixtures: %s") % (" • ".join(upcoming) if not upcoming.is_empty() else tr("No upcoming fixtures")))

	var squad := _squad(world, club_id)
	var morale := 0.0
	var injured := 0
	for player in squad:
		morale += float(player.get("morale", 50))
		if int(player.get("injured_days", 0)) > 0:
			injured += 1
	var average_morale := morale / maxf(1.0, float(squad.size()))
	_line(box, tr("Squad morale: %.0f/100 • Injuries: %d") % [average_morale, injured])

	var board: Dictionary = club.get("board", {})
	var confidence := float(board.get("confidence", board.get("patience", 50)))
	_line(box, tr("Board confidence: %.0f/100 • Club reputation: %d") % [confidence, int(club.get("reputation", 50))])

	var transfer_activity := _transfer_activity(world, club_id)
	_line(box, tr("Transfer activity: %d active offers • %d completed ledger entries") % [transfer_activity.active, transfer_activity.completed])
	_line(box, tr("Financial snapshot: cash %s • transfer budget %s • wage budget %s") % [_money(int(club.get("cash", 0))), _money(int(club.get("transfer_budget", 0))), _money(int(club.get("wage_budget", 0)))])
	var unread := 0
	for message in world.get("inbox", []):
		if not bool(message.get("read", false)):
			unread += 1
	_line(box, tr("Inbox requiring review: %d") % unread)

func _table(world: Dictionary, competition: Dictionary) -> Array:
	var fixtures: Array = []
	for fixture in world.get("fixtures", []):
		if String(fixture.get("competition_id", "")) == String(competition.get("id", "")):
			fixtures.append(fixture)
	return LeagueTable.build(competition.get("club_ids", []), fixtures, int(competition.get("points_win", 3)), int(competition.get("points_draw", 1)))

func _recent_results(world: Dictionary, club_id: String, limit: int) -> Array[String]:
	var played: Array = []
	for fixture in world.get("fixtures", []):
		if not bool(fixture.get("played", false)):
			continue
		if String(fixture.get("home_club_id", "")) == club_id or String(fixture.get("away_club_id", "")) == club_id:
			played.append(fixture)
	played.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.get("date", "")) > String(b.get("date", "")))
	var rows: Array[String] = []
	for fixture in played.slice(0, mini(limit, played.size())):
		var home := String(fixture.get("home_club_id", "")) == club_id
		var gf := int(fixture.get("home_goals", 0)) if home else int(fixture.get("away_goals", 0))
		var ga := int(fixture.get("away_goals", 0)) if home else int(fixture.get("home_goals", 0))
		var result := "W" if gf > ga else ("D" if gf == ga else "L")
		rows.append("%s %d-%d" % [result, gf, ga])
	return rows

func _upcoming(world: Dictionary, club_id: String, limit: int) -> Array[String]:
	var future: Array = []
	for fixture in world.get("fixtures", []):
		if bool(fixture.get("played", false)):
			continue
		if String(fixture.get("home_club_id", "")) == club_id or String(fixture.get("away_club_id", "")) == club_id:
			future.append(fixture)
	future.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.get("date", "9999")) < String(b.get("date", "9999")))
	var rows: Array[String] = []
	for fixture in future.slice(0, mini(limit, future.size())):
		var opponent := String(fixture.get("away_club_id", "")) if String(fixture.get("home_club_id", "")) == club_id else String(fixture.get("home_club_id", ""))
		rows.append("%s vs %s" % [String(fixture.get("date", "TBD")), _club_name(world, opponent)])
	return rows

func _transfer_activity(world: Dictionary, club_id: String) -> Dictionary:
	var active := 0
	var completed := 0
	for offer in world.get("transfer_offers", []):
		if String(offer.get("buyer_id", "")) == club_id or String(offer.get("seller_id", "")) == club_id:
			if String(offer.get("status", "")) not in ["completed", "rejected", "withdrawn"]:
				active += 1
	for entry in world.get("ledger", []):
		if String(entry.get("club_id", "")) == club_id and String(entry.get("category", "")) in ["transfer_fee", "loan_fee"]:
			completed += 1
	return {"active": active, "completed": completed}

func _squad(world: Dictionary, club_id: String) -> Array:
	var rows: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
			rows.append(player)
	return rows

func _league_for_club(world: Dictionary, club_id: String) -> Dictionary:
	for competition in world.get("competitions", []):
		if String(competition.get("competition_type", "league")) == "league" and club_id in competition.get("club_ids", []):
			return competition
	return {}

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}

func _club_name(world: Dictionary, club_id: String) -> String:
	var club := _club(world, club_id)
	return String(club.get("name", club_id))

func _heading(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)

func _line(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _money(value: int) -> String:
	if value >= 1000000:
		return "£%.1fm" % (float(value) / 1000000.0)
	if value >= 1000:
		return "£%.0fk" % (float(value) / 1000.0)
	return "£%d" % value

func _first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer:
		return node
	for child in node.get_children():
		var found := _first_vbox(child)
		if found != null:
			return found
	return null

func _career_session(node: Node):
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			return current.get("session")
		current = current.get_parent()
	return null
