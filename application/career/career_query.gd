class_name CareerQuery
extends RefCounted

const LeagueTableClass = preload("res://simulation/competitions/league_table.gd")

func dashboard(world: Dictionary, club_id: String) -> Dictionary:
	var club: Dictionary = _find(world.clubs, club_id)
	return {
		"club": club.duplicate(true),
		"date": String(world.get("date", "")),
		"season_year": int(world.get("season_year", 0)),
		"squad_size": squad(world, club_id).size(),
		"cash": int(club.get("cash", 0)),
		"transfer_budget": int(club.get("transfer_budget", 0)),
		"next_fixture": _next_fixture(world, club_id),
	}

func squad(world: Dictionary, club_id: String) -> Array:
	var rows: Array = []
	for player in world.players:
		if String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)):
			continue
		rows.append({"id": player.id, "name": "%s %s" % [player.first_name, player.last_name], "position": player.position, "age": player.age, "ability": player.current_ability, "fitness": player.get("fitness", 100), "injured_days": player.get("injured_days", 0)})
	return rows

func medical(world: Dictionary, club_id: String) -> Array:
	var rows: Array = []
	for player in squad(world, club_id):
		if int(player.injured_days) > 0:
			rows.append(player)
	return rows

func schedule(world: Dictionary, club_id: String, limit: int = 20) -> Array:
	var rows: Array = []
	for fixture in world.fixtures:
		if String(fixture.home_club_id) != club_id and String(fixture.away_club_id) != club_id:
			continue
		rows.append(fixture.duplicate(true))
		if rows.size() >= limit:
			break
	return rows

func competition_table(world: Dictionary, competition_id: String) -> Array:
	var competition: Dictionary = _find(world.competitions, competition_id)
	var fixtures: Array = []
	for fixture in world.fixtures:
		if String(fixture.competition_id) == competition_id:
			fixtures.append(fixture)
	return LeagueTableClass.build(competition.club_ids, fixtures, int(competition.points_win), int(competition.points_draw))

func staff(world: Dictionary, club_id: String) -> Array:
	var rows: Array = []
	for member in world.staff:
		if String(member.club_id) == club_id:
			rows.append(member.duplicate(true))
	return rows

func finances(world: Dictionary, club_id: String) -> Dictionary:
	var club: Dictionary = _find(world.clubs, club_id)
	var ledger: Array = []
	for entry in world.get("ledger", []):
		if String(entry.club_id) == club_id:
			ledger.append(entry.duplicate(true))
	return {"cash": club.get("cash", 0), "debt": club.get("debt", 0), "transfer_budget": club.get("transfer_budget", 0), "wage_budget": club.get("wage_budget", 0), "ledger": ledger}

func tactics(world: Dictionary, club_id: String) -> Dictionary:
	return _find(world.clubs, club_id).get("tactic", {}).duplicate(true)

func transfers(world: Dictionary, club_id: String) -> Array:
	var rows: Array = []
	for entry in world.get("ledger", []):
		if String(entry.club_id) == club_id and String(entry.category) in ["transfer_fee", "loan_fee"]:
			rows.append(entry.duplicate(true))
	return rows

func world_search(world: Dictionary, text: String, limit: int = 30) -> Array:
	var query := text.to_lower()
	var rows: Array = []
	for club in world.clubs:
		if query == "" or String(club.name).to_lower().contains(query):
			rows.append({"type": "club", "id": club.id, "name": club.name})
			if rows.size() >= limit: return rows
	for player in world.players:
		var name := "%s %s" % [player.first_name, player.last_name]
		if query == "" or name.to_lower().contains(query):
			rows.append({"type": "player", "id": player.id, "name": name})
			if rows.size() >= limit: return rows
	return rows

func match_analysis(result: Dictionary) -> Dictionary:
	var shots := {"home": [], "away": []}
	var set_pieces := {"home": 0, "away": 0}
	for event in result.get("events", []):
		var side: String = String(event.get("side", ""))
		if side not in ["home", "away"]: continue
		if String(event.get("type", "")) == "shot": shots[side].append(event.duplicate(true))
		if String(event.get("type", "")) in ["corner", "free_kick"]: set_pieces[side] += 1
	return {"score": [result.home_goals, result.away_goals], "stats": result.stats.duplicate(true), "shots": shots, "set_pieces": set_pieces, "frames": result.get("spatial", {}).get("frames", []).duplicate(true)}

func _next_fixture(world: Dictionary, club_id: String) -> Dictionary:
	for fixture in world.fixtures:
		if not fixture.played and (String(fixture.home_club_id) == club_id or String(fixture.away_club_id) == club_id): return fixture.duplicate(true)
	return {}

func _find(values: Array, id: String) -> Dictionary:
	for value in values:
		if String(value.id) == id: return value
	return {}
