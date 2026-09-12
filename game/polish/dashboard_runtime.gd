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
	_hide_legacy_summary(box)

	var world: Dictionary = session.world
	var club_id := String(session.managed_club_id)
	var club := _club(world, club_id)
	var overview := VBoxContainer.new()
	overview.name = "DynastyCommandOverview"
	overview.add_theme_constant_override("separation", 12)

	var eyebrow := Label.new()
	eyebrow.text = tr("MANAGER COMMAND")
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color(0.22, 0.84, 0.74, 1.0))
	overview.add_child(eyebrow)
	var heading := Label.new()
	heading.text = tr("Today at a glance")
	heading.add_theme_font_size_override("font_size", 22)
	overview.add_child(heading)

	var grid := GridContainer.new()
	grid.name = "ManagerOverviewGrid"
	grid.columns = 1 if OS.has_feature("mobile") else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.add_child(grid)

	var competition := _league_for_club(world, club_id)
	var position_value := tr("No table yet")
	var position_detail := tr("Competition data will appear after fixtures begin")
	if not competition.is_empty():
		var table := _table(world, competition)
		for i in range(table.size()):
			if String(table[i].get("club_id", "")) == club_id:
				position_value = tr("%d / %d") % [i + 1, table.size()]
				position_detail = tr("%d pts • %d played") % [int(table[i].get("points", 0)), int(table[i].get("played", 0))]
				break
	_add_card(grid, tr("LEAGUE POSITION"), position_value, position_detail, Color(0.43, 0.42, 1.0, 1.0))

	var upcoming := _upcoming(world, club_id, 1)
	var next_value := tr("No fixture")
	var next_detail := tr("Advance the calendar for the next match")
	if not upcoming.is_empty():
		next_value = String(upcoming[0].get("opponent", tr("Opponent")))
		next_detail = "%s • %s" % [String(upcoming[0].get("date", "TBD")), String(upcoming[0].get("venue", ""))]
	_add_card(grid, tr("NEXT MATCH"), next_value, next_detail, Color(0.22, 0.84, 0.74, 1.0))

	var squad := _squad(world, club_id)
	var morale := 0.0
	var injured := 0
	for player in squad:
		morale += float(player.get("morale", 50))
		if int(player.get("injured_days", 0)) > 0:
			injured += 1
	var average_morale := morale / maxf(1.0, float(squad.size()))
	_add_card(grid, tr("SQUAD PULSE"), tr("%.0f morale") % average_morale, tr("%d players • %d unavailable") % [squad.size(), injured], _health_color(average_morale, injured))

	var board: Dictionary = club.get("board", {})
	var confidence := float(board.get("confidence", board.get("patience", 50)))
	_add_card(grid, tr("BOARD"), tr("%.0f confidence") % confidence, tr("Club reputation %d") % int(club.get("reputation", 50)), _score_color(confidence))

	var transfer_activity := _transfer_activity(world, club_id)
	_add_card(grid, tr("CLUB FINANCE"), _money(int(club.get("cash", 0))), tr("%s transfer • %d active offers") % [_money(int(club.get("transfer_budget", 0))), int(transfer_activity.active)], Color(0.43, 0.42, 1.0, 1.0))

	var unread := 0
	for message in world.get("inbox", []):
		if not bool(message.get("read", false)):
			unread += 1
	var recent := _recent_results(world, club_id, 5)
	var form_text := " • ".join(recent) if not recent.is_empty() else tr("No results yet")
	_add_card(grid, tr("ATTENTION"), tr("%d unread") % unread, tr("Form: %s") % form_text, Color(0.95, 0.67, 0.28, 1.0) if unread > 0 else Color(0.22, 0.84, 0.74, 1.0))

	var insert_index := mini(2, box.get_child_count())
	box.add_child(overview)
	box.move_child(overview, insert_index)

func _hide_legacy_summary(box: VBoxContainer) -> void:
	for child in box.get_children():
		if not child is Label:
			continue
		var text := String((child as Label).text)
		for prefix in ["Date:", "Squad:", "Unread inbox:", "Form:", "Next fixture:", "No upcoming fixtures", "No managed match played yet"]:
			if text.begins_with(tr(prefix)) or text.begins_with(prefix):
				child.visible = false
				break

func _add_card(parent: GridContainer, title: String, value: String, detail: String, accent: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 118)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("dynasty_card", true)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", accent)
	box.add_child(title_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 22)
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(value_label)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.add_theme_font_size_override("font_size", 14)
	detail_label.add_theme_color_override("font_color", Color(0.68, 0.73, 0.82, 1.0))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail_label)
	parent.add_child(panel)

func _score_color(score: float) -> Color:
	if score >= 70.0:
		return Color(0.22, 0.84, 0.74, 1.0)
	if score >= 45.0:
		return Color(0.95, 0.67, 0.28, 1.0)
	return Color(0.96, 0.40, 0.48, 1.0)

func _health_color(morale: float, injuries: int) -> Color:
	if morale >= 68.0 and injuries <= 3:
		return Color(0.22, 0.84, 0.74, 1.0)
	if morale >= 48.0:
		return Color(0.95, 0.67, 0.28, 1.0)
	return Color(0.96, 0.40, 0.48, 1.0)

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

func _upcoming(world: Dictionary, club_id: String, limit: int) -> Array[Dictionary]:
	var future: Array = []
	for fixture in world.get("fixtures", []):
		if bool(fixture.get("played", false)):
			continue
		if String(fixture.get("home_club_id", "")) == club_id or String(fixture.get("away_club_id", "")) == club_id:
			future.append(fixture)
	future.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.get("date", "9999")) < String(b.get("date", "9999")))
	var rows: Array[Dictionary] = []
	for fixture in future.slice(0, mini(limit, future.size())):
		var home := String(fixture.get("home_club_id", "")) == club_id
		var opponent := String(fixture.get("away_club_id", "")) if home else String(fixture.get("home_club_id", ""))
		rows.append({"date": String(fixture.get("date", "TBD")), "opponent": _club_name(world, opponent), "venue": tr("HOME") if home else tr("AWAY")})
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
