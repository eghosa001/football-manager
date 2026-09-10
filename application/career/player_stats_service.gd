class_name PlayerStatsService
extends RefCounted

func record_match(world: Dictionary, fixture: Dictionary, result: Dictionary) -> void:
	if result.has("error"):
		return
	world["player_match_stats"] = world.get("player_match_stats", [])
	world["player_history"] = world.get("player_history", [])
	var lineups: Dictionary = result.get("lineups", {})
	for side in ["home", "away"]:
		for player_id in lineups.get(side, []):
			var player := _player(world.get("players", []), String(player_id))
			if player.is_empty(): continue
			player["season_appearances"] = int(player.get("season_appearances", 0)) + 1
			player["career_appearances"] = int(player.get("career_appearances", 0)) + 1
			var row := {"player_id":String(player_id),"fixture_id":String(fixture.get("id", "")),"competition_id":String(fixture.get("competition_id", "")),"season_year":int(world.get("season_year", 2026)),"side":side,"goals":0,"shots":0,"xg":0.0,"passes":0,"passes_completed":0,"dribbles":0,"dribbles_completed":0}
			world.player_match_stats.append(row)
	for event in result.get("events", []):
		var player_id := String(event.get("player_id", ""))
		if player_id == "": continue
		var row := _match_row(world.player_match_stats, String(fixture.get("id", "")), player_id)
		if row.is_empty(): continue
		match String(event.get("type", "")):
			"shot":
				row.shots = int(row.shots) + 1
				row.xg = float(row.xg) + float(event.get("xg", 0.0))
				if String(event.get("outcome", "")) == "goal": row.goals = int(row.goals) + 1
			"pass":
				row.passes = int(row.passes) + 1
				if bool(event.get("success", false)): row.passes_completed = int(row.passes_completed) + 1
			"dribble":
				row.dribbles = int(row.dribbles) + 1
				if bool(event.get("success", false)): row.dribbles_completed = int(row.dribbles_completed) + 1
	_update_season_history(world, fixture, result)

func season_totals(world: Dictionary, player_id: String, season_year: int = -1) -> Dictionary:
	var target_year := int(world.get("season_year", 2026)) if season_year < 0 else season_year
	var total := {"appearances":0,"goals":0,"shots":0,"xg":0.0,"passes":0,"passes_completed":0,"dribbles":0,"dribbles_completed":0}
	for row in world.get("player_match_stats", []):
		if String(row.get("player_id", "")) != player_id or int(row.get("season_year", 0)) != target_year: continue
		total.appearances += 1
		for key in ["goals","shots","passes","passes_completed","dribbles","dribbles_completed"]: total[key] = int(total[key]) + int(row.get(key, 0))
		total.xg = float(total.xg) + float(row.get("xg", 0.0))
	total.xg = snappedf(float(total.xg), 0.01)
	return total

func _update_season_history(world: Dictionary, fixture: Dictionary, result: Dictionary) -> void:
	var year := int(world.get("season_year", 2026))
	for side in ["home", "away"]:
		var club_id := String(fixture.get("home_club_id", "")) if side == "home" else String(fixture.get("away_club_id", ""))
		for player_id in result.get("lineups", {}).get(side, []):
			var row := _history_row(world.player_history, String(player_id), year, club_id, String(fixture.get("competition_id", "")))
			if row.is_empty():
				row = {"player_id":String(player_id),"season_year":year,"club_id":club_id,"competition_id":String(fixture.get("competition_id", "")),"appearances":0,"goals":0,"xg":0.0}
				world.player_history.append(row)
			row.appearances = int(row.appearances) + 1
			var match_row := _match_row(world.player_match_stats, String(fixture.get("id", "")), String(player_id))
			if not match_row.is_empty():
				row.goals = int(row.goals) + int(match_row.goals)
				row.xg = snappedf(float(row.xg) + float(match_row.xg), 0.01)

func _player(players: Array, id: String) -> Dictionary:
	for player in players:
		if String(player.get("id", "")) == id: return player
	return {}

func _match_row(rows: Array, fixture_id: String, player_id: String) -> Dictionary:
	for row in rows:
		if String(row.get("fixture_id", "")) == fixture_id and String(row.get("player_id", "")) == player_id: return row
	return {}

func _history_row(rows: Array, player_id: String, year: int, club_id: String, competition_id: String) -> Dictionary:
	for row in rows:
		if String(row.get("player_id", "")) == player_id and int(row.get("season_year", 0)) == year and String(row.get("club_id", "")) == club_id and String(row.get("competition_id", "")) == competition_id: return row
	return {}
