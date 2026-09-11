class_name PlayerStatsService
extends RefCounted

func record_match(world: Dictionary, fixture: Dictionary, result: Dictionary) -> void:
	if result.has("error"):
		return
	world["player_match_stats"] = world.get("player_match_stats", [])
	world["player_history"] = world.get("player_history", [])
	var participants: Dictionary = result.get("participants", result.get("lineups", {}))
	var starters: Dictionary = result.get("lineups", participants)
	var starter_ids := {"home":{},"away":{}}
	for side in ["home","away"]:
		for player_id in starters.get(side,[]):
			starter_ids[side][String(player_id)] = true
	var player_index: Dictionary = {}
	for player in world.get("players", []):
		player_index[String(player.get("id", ""))] = player
	var match_rows: Dictionary = {}
	for side in ["home", "away"]:
		for player_id in participants.get(side, []):
			var player: Dictionary = player_index.get(String(player_id), {})
			if player.is_empty():
				continue
			player["season_appearances"] = int(player.get("season_appearances", 0)) + 1
			player["career_appearances"] = int(player.get("career_appearances", 0)) + 1
			var row := {
				"player_id":String(player_id),"fixture_id":String(fixture.get("id", "")),"competition_id":String(fixture.get("competition_id", "")),
				"season_year":int(world.get("season_year", 2026)),"side":side,"started":starter_ids[side].has(String(player_id)),
				"goals":0,"assists":0,"shots":0,"xg":0.0,"passes":0,"passes_completed":0,"dribbles":0,"dribbles_completed":0,
				"interceptions":0,"rating":6.5
			}
			world.player_match_stats.append(row)
			match_rows[String(player_id)] = row
	var last_passer := {"home":"","away":""}
	for event in result.get("events", []):
		var side := String(event.get("side", ""))
		var player_id := String(event.get("player_id", ""))
		var row: Dictionary = match_rows.get(player_id, {})
		var event_type := String(event.get("type", ""))
		if event_type == "pass":
			if not row.is_empty():
				row.passes = int(row.passes) + 1
				if bool(event.get("success", false)):
					row.passes_completed = int(row.passes_completed) + 1
					if side in ["home","away"]:
						last_passer[side] = player_id
				elif side in ["home","away"]:
					last_passer[side] = ""
			continue
		if row.is_empty():
			continue
		match event_type:
			"shot":
				row.shots = int(row.shots) + 1
				row.xg = float(row.xg) + float(event.get("xg", 0.0))
				if String(event.get("outcome", "")) == "goal":
					row.goals = int(row.goals) + 1
					_assign_assist(match_rows,last_passer,side,player_id)
			"goal":
				row.shots = int(row.shots) + 1
				row.goals = int(row.goals) + 1
				row.xg = float(row.xg) + float(event.get("xg",0.0))
				_assign_assist(match_rows,last_passer,side,player_id)
			"dribble":
				row.dribbles = int(row.dribbles) + 1
				if bool(event.get("success", false)):
					row.dribbles_completed = int(row.dribbles_completed) + 1
			"interception":
				row.interceptions = int(row.interceptions) + 1
	for player_id in match_rows.keys():
		var row: Dictionary = match_rows[player_id]
		row.rating = _rating(row)
	_update_season_history(world, fixture, result, match_rows, starter_ids)

func season_totals(world: Dictionary, player_id: String, season_year: int = -1) -> Dictionary:
	var target_year := int(world.get("season_year", 2026)) if season_year < 0 else season_year
	var total := {"appearances":0,"starts":0,"goals":0,"assists":0,"shots":0,"xg":0.0,"passes":0,"passes_completed":0,"dribbles":0,"dribbles_completed":0,"rating":0.0}
	var rating_sum := 0.0
	for row in world.get("player_match_stats", []):
		if String(row.get("player_id", "")) != player_id or int(row.get("season_year", 0)) != target_year:
			continue
		total.appearances += 1
		if bool(row.get("started",false)):
			total.starts += 1
		for key in ["goals","assists","shots","passes","passes_completed","dribbles","dribbles_completed"]:
			total[key] = int(total[key]) + int(row.get(key, 0))
		total.xg = float(total.xg) + float(row.get("xg", 0.0))
		rating_sum += float(row.get("rating",6.5))
	total.xg = snappedf(float(total.xg), 0.01)
	total.rating = snappedf(rating_sum / maxf(1.0,float(total.appearances)),0.01)
	return total

func _update_season_history(world: Dictionary, fixture: Dictionary, result: Dictionary, match_rows: Dictionary, starter_ids: Dictionary) -> void:
	var year := int(world.get("season_year", 2026))
	for side in ["home", "away"]:
		var club_id := String(fixture.get("home_club_id", "")) if side == "home" else String(fixture.get("away_club_id", ""))
		for player_id in result.get("participants", result.get("lineups", {})).get(side, []):
			var row := _history_row(world.player_history, String(player_id), year, club_id, String(fixture.get("competition_id", "")))
			if row.is_empty():
				row = {"player_id":String(player_id),"season_year":year,"club_id":club_id,"competition_id":String(fixture.get("competition_id", "")),"appearances":0,"starts":0,"goals":0,"assists":0,"xg":0.0,"rating_sum":0.0,"rating":0.0}
				world.player_history.append(row)
			row.appearances = int(row.appearances) + 1
			if starter_ids[side].has(String(player_id)):
				row.starts = int(row.get("starts",0)) + 1
			var match_row: Dictionary = match_rows.get(String(player_id), {})
			if not match_row.is_empty():
				row.goals = int(row.goals) + int(match_row.goals)
				row.assists = int(row.get("assists",0)) + int(match_row.get("assists",0))
				row.xg = snappedf(float(row.xg) + float(match_row.xg), 0.01)
				row.rating_sum = float(row.get("rating_sum",0.0)) + float(match_row.get("rating",6.5))
				row.rating = snappedf(float(row.rating_sum)/maxf(1.0,float(row.appearances)),0.01)

func _assign_assist(match_rows: Dictionary, last_passer: Dictionary, side: String, scorer_id: String) -> void:
	if side not in ["home","away"]:
		return
	var assister_id := String(last_passer.get(side,""))
	if assister_id == "" or assister_id == scorer_id:
		return
	var assister: Dictionary = match_rows.get(assister_id,{})
	if not assister.is_empty():
		assister.assists = int(assister.get("assists",0)) + 1
	last_passer[side] = ""

func _rating(row: Dictionary) -> float:
	var score := 6.3
	score += float(row.get("goals",0))*0.85
	score += float(row.get("assists",0))*0.50
	score += float(row.get("interceptions",0))*0.035
	score += float(row.get("dribbles_completed",0))*0.025
	var passes := int(row.get("passes",0))
	if passes >= 5:
		score += (float(row.get("passes_completed",0))/float(passes)-0.70)*0.8
	var shots := int(row.get("shots",0))
	if shots > 0 and int(row.get("goals",0)) == 0:
		score -= minf(0.35,float(shots)*0.04)
	return snappedf(clampf(score,4.0,10.0),0.1)

func _history_row(rows: Array, player_id: String, year: int, club_id: String, competition_id: String) -> Dictionary:
	for row in rows:
		if String(row.get("player_id", "")) == player_id and int(row.get("season_year", 0)) == year and String(row.get("club_id", "")) == club_id and String(row.get("competition_id", "")) == competition_id:
			return row
	return {}
