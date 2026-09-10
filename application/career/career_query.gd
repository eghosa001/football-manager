class_name CareerQuery
extends RefCounted

const LeagueTableClass = preload("res://simulation/competitions/league_table.gd")
const ScoutingServiceClass = preload("res://simulation/scouting/scouting_service.gd")
const MedicalSystemClass = preload("res://simulation/players/medical_system.gd")

func dashboard(world: Dictionary, club_id: String) -> Dictionary:
	var club: Dictionary = _find(world.get("clubs", []), club_id)
	var unread := 0
	for message in world.get("inbox", []):
		if not bool(message.get("read", false)):
			unread += 1
	return {
		"club": club.duplicate(true),
		"date": String(world.get("date", "")),
		"season_year": int(world.get("season_year", 0)),
		"squad_size": squad(world, club_id).size(),
		"cash": int(club.get("cash", 0)),
		"transfer_budget": int(club.get("transfer_budget", 0)),
		"wage_budget": int(club.get("wage_budget", 0)),
		"unread_messages": unread,
		"next_fixture": _next_fixture(world, club_id),
		"last_managed_match": world.get("last_managed_match", {}).duplicate(true),
	}

func squad(world: Dictionary, club_id: String) -> Array:
	var rows: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)):
			continue
		rows.append({"id": player.id, "name": _player_name(player), "position": player.get("position", ""), "age": player.get("age", 0), "ability": player.get("current_ability", 0), "potential":player.get("potential", 0), "fitness": player.get("fitness", 100), "morale":player.get("morale", 50), "injured_days": player.get("injured_days", 0)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary):
		if String(a.position) == String(b.position): return String(a.name) < String(b.name)
		return String(a.position) < String(b.position)
	)
	return rows

func player_profile(world: Dictionary, player_id: String, observer_club_id: String = "") -> Dictionary:
	var player := _find(world.get("players", []), player_id)
	if player.is_empty():
		return {}
	var own_player := observer_club_id != "" and String(player.get("club_id", "")) == observer_club_id
	var report := {}
	if not own_player:
		# ScoutingService ensures collections exist, so run it on deep copies to keep
		# presentation queries strictly read-only.
		report = ScoutingServiceClass.new().player_report(world.duplicate(true), player.duplicate(true), 50, int(world.get("seed", 1)) + _stable_key(player_id))
	var contract := _contract_for_player(world.get("contracts", []), player_id)
	var history: Array = []
	for row in world.get("player_history", []):
		if String(row.get("player_id", "")) == player_id:
			history.append(row.duplicate(true))
	var medical_status: Dictionary = MedicalSystemClass.new().availability(player.duplicate(true))
	return {
		"id":player_id,
		"name":_player_name(player),
		"club_id":String(player.get("club_id", "")),
		"country_id":String(player.get("country_id", "")),
		"age":int(player.get("age", 0)),
		"position":String(player.get("position", "")),
		"preferred_foot":String(player.get("preferred_foot", "right")),
		"weak_foot":int(player.get("weak_foot", 50)),
		"height_cm":int(player.get("height_cm", 0)),
		"weight_kg":int(player.get("weight_kg", 0)),
		"ability":int(player.get("current_ability", 0)) if own_player else report.get("ability_estimate", {}),
		"potential":int(player.get("potential", 0)) if own_player else report.get("potential_estimate", {}),
		"attributes":player.get("attributes", {}).duplicate(true) if own_player else report.get("attributes", {}).duplicate(true),
		"traits":player.get("traits", []).duplicate(true),
		"morale":int(player.get("morale", 50)),
		"happiness":int(player.get("happiness", player.get("morale", 50))),
		"fitness":int(player.get("fitness", 100)),
		"medical":medical_status,
		"contract":contract.duplicate(true),
		"history":history,
		"scouting_knowledge":float(report.get("knowledge", 1.0 if own_player else 0.0)),
	}

func club_profile(world: Dictionary, club_id: String) -> Dictionary:
	var club := _find(world.get("clubs", []), club_id)
	if club.is_empty(): return {}
	var competition_names: Array = []
	for competition in world.get("competitions", []):
		if club_id in competition.get("club_ids", []): competition_names.append(String(competition.get("name", "")))
	return {"club":club.duplicate(true),"squad":squad(world, club_id),"staff":staff(world, club_id),"competitions":competition_names,"next_fixture":_next_fixture(world, club_id),"finance":finances(world, club_id),"tactic":tactics(world, club_id)}

func staff_profile(world: Dictionary, staff_id: String) -> Dictionary:
	var member := _find(world.get("staff", []), staff_id)
	if member.is_empty(): return {}
	var career: Array = []
	for row in world.get("manager_careers", []):
		if String(row.get("manager_id", "")) == staff_id: career.append(row.duplicate(true))
	return {"staff":member.duplicate(true),"career":career,"club":_find(world.get("clubs", []), String(member.get("club_id", ""))).duplicate(true)}

func medical(world: Dictionary, club_id: String) -> Array:
	var rows: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)): continue
		var status: Dictionary = MedicalSystemClass.new().availability(player.duplicate(true))
		if not bool(status.available): rows.append({"id":player.id,"name":_player_name(player),"status":status})
	return rows

func training(world: Dictionary, club_id: String) -> Dictionary:
	var club := _find(world.get("clubs", []), club_id)
	return {"schedule":club.get("training_schedule", ["recovery","technical","tactical","physical","set_pieces","match_prep","rest"]).duplicate(),"intensity":float(club.get("training_intensity", 0.65)),"facilities":int(club.get("training_facilities", club.get("facilities", {}).get("training", 50)))}

func scouting(world: Dictionary, club_id: String) -> Dictionary:
	var assignments: Array = []
	var scout_ids := {}
	for member in world.get("staff", []):
		if String(member.get("club_id", "")) == club_id and String(member.get("role", "")) == "scout": scout_ids[String(member.id)] = true
	for assignment in world.get("scout_assignments", []):
		if scout_ids.has(String(assignment.get("scout_id", ""))): assignments.append(assignment.duplicate(true))
	return {"assignments":assignments,"knowledge_count":world.get("scouting_knowledge", {}).size()}

func transfer_market(world: Dictionary, club_id: String) -> Dictionary:
	var offers: Array = []
	for offer in world.get("transfer_offers", []):
		if String(offer.get("buyer_id", "")) == club_id or String(offer.get("seller_id", "")) == club_id: offers.append(offer.duplicate(true))
	return {"window_open":_transfer_window_open(world),"offers":offers,"history":transfers(world, club_id)}

func schedule(world: Dictionary, club_id: String, limit: int = 20) -> Array:
	var rows: Array = []
	for fixture in world.get("fixtures", []):
		if String(fixture.get("home_club_id", "")) != club_id and String(fixture.get("away_club_id", "")) != club_id: continue
		rows.append(fixture.duplicate(true))
		if rows.size() >= limit: break
	return rows

func competition_table(world: Dictionary, competition_id: String) -> Array:
	var competition: Dictionary = _find(world.get("competitions", []), competition_id)
	if competition.is_empty(): return []
	var fixtures: Array = []
	for fixture in world.get("fixtures", []):
		if String(fixture.get("competition_id", "")) == competition_id: fixtures.append(fixture)
	return LeagueTableClass.build(competition.get("club_ids", []), fixtures, int(competition.get("points_win", 3)), int(competition.get("points_draw", 1)))

func staff(world: Dictionary, club_id: String) -> Array:
	var rows: Array = []
	for member in world.get("staff", []):
		if String(member.get("club_id", "")) == club_id: rows.append(member.duplicate(true))
	return rows

func finances(world: Dictionary, club_id: String) -> Dictionary:
	var club: Dictionary = _find(world.get("clubs", []), club_id)
	var ledger: Array = []
	for entry in world.get("ledger", []):
		if String(entry.get("club_id", "")) == club_id: ledger.append(entry.duplicate(true))
	return {"cash": club.get("cash", 0), "debt": club.get("debt", 0), "transfer_budget": club.get("transfer_budget", 0), "wage_budget": club.get("wage_budget", 0), "ledger": ledger}

func tactics(world: Dictionary, club_id: String) -> Dictionary:
	return _find(world.get("clubs", []), club_id).get("tactic", {}).duplicate(true)

func transfers(world: Dictionary, club_id: String) -> Array:
	var rows: Array = []
	for entry in world.get("ledger", []):
		if String(entry.get("club_id", "")) == club_id and String(entry.get("category", "")) in ["transfer_fee", "loan_fee"]: rows.append(entry.duplicate(true))
	return rows

func world_search(world: Dictionary, text: String, limit: int = 30) -> Array:
	var q := text.to_lower()
	var rows: Array = []
	for club in world.get("clubs", []):
		if q == "" or String(club.get("name", "")).to_lower().contains(q):
			rows.append({"type":"club","id":club.id,"name":club.name})
			if rows.size() >= limit: return rows
	for player in world.get("players", []):
		var player_name := _player_name(player)
		if q == "" or player_name.to_lower().contains(q):
			rows.append({"type":"player","id":player.id,"name":player_name})
			if rows.size() >= limit: return rows
	for member in world.get("staff", []):
		var staff_name := String(member.get("name", ""))
		if q == "" or staff_name.to_lower().contains(q):
			rows.append({"type":"staff","id":member.id,"name":staff_name})
			if rows.size() >= limit: return rows
	return rows

func match_analysis(result: Dictionary) -> Dictionary:
	if result.is_empty(): return {}
	var shots := {"home": [], "away": []}
	var set_pieces := {"home": 0, "away": 0}
	for event in result.get("events", []):
		var side: String = String(event.get("side", ""))
		if side not in ["home", "away"]: continue
		if String(event.get("type", "")) == "shot": shots[side].append(event.duplicate(true))
		if String(event.get("type", "")) in ["corner", "free_kick"]: set_pieces[side] += 1
	return {"score": [result.get("home_goals", 0), result.get("away_goals", 0)], "stats": result.get("stats", {}).duplicate(true), "shots": shots, "set_pieces": set_pieces, "frames": result.get("spatial", {}).get("frames", []).duplicate(true)}

func last_match_analysis(world: Dictionary) -> Dictionary:
	var row: Dictionary = world.get("last_managed_match", {})
	if row.is_empty(): return {}
	return {"fixture":row.get("fixture", {}).duplicate(true),"date":row.get("date", ""),"analysis":match_analysis(row.get("result", {}))}

func _next_fixture(world: Dictionary, club_id: String) -> Dictionary:
	var best := {}
	for fixture in world.get("fixtures", []):
		if bool(fixture.get("played", false)): continue
		if String(fixture.get("home_club_id", "")) != club_id and String(fixture.get("away_club_id", "")) != club_id: continue
		if best.is_empty() or String(fixture.get("date", "9999-99-99")) < String(best.get("date", "9999-99-99")): best = fixture
	return best.duplicate(true)

func _find(values: Array, id: String) -> Dictionary:
	for value in values:
		if String(value.get("id", "")) == id: return value
	return {}

func _contract_for_player(contracts: Array, player_id: String) -> Dictionary:
	for contract in contracts:
		if String(contract.get("player_id", "")) == player_id: return contract
	return {}

func _player_name(player: Dictionary) -> String:
	if player.has("name"): return String(player.name)
	return (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()

func _transfer_window_open(world: Dictionary) -> bool:
	var parts := String(world.get("date", "")).split("-")
	if parts.size() != 3: return false
	var mmdd := int(parts[1]) * 100 + int(parts[2])
	for window in world.get("transfer_windows", [{"start_month":6,"start_day":15,"end_month":9,"end_day":1},{"start_month":1,"start_day":1,"end_month":1,"end_day":31}]):
		var start := int(window.start_month) * 100 + int(window.start_day)
		var finish := int(window.end_month) * 100 + int(window.end_day)
		if mmdd >= start and mmdd <= finish: return true
	return false

func _stable_key(text: String) -> int:
	var value := 83
	for character in text.to_utf8_buffer(): value = posmod(value * 191 + int(character), 2_147_483_647)
	return value
