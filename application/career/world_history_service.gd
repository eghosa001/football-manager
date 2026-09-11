class_name WorldHistoryService
extends RefCounted

func build(world: Dictionary, history: Array = []) -> Dictionary:
	var players: Array = world.get("players", [])
	var clubs: Array = world.get("clubs", [])
	var competitions: Array = world.get("competitions", [])
	var player_names := _index_names(players)
	var club_names := _index_names(clubs)
	var competition_names := _index_names(competitions)
	return {
		"all_time_players": _all_time_players(world, players),
		"transfer_records": _transfer_records(world, player_names, club_names),
		"club_honours": _club_honours(world, history, club_names, competition_names),
		"competition_history": _competition_history(world, history, club_names, competition_names),
		"manager_history": _manager_history(world, club_names),
		"legends": _legends(world, player_names, club_names),
		"timeline": _timeline(world, history),
	}

func _all_time_players(world: Dictionary, players: Array) -> Array:
	var goals := {}
	for row in world.get("player_history", []):
		var id := String(row.get("player_id", ""))
		if id == "": continue
		goals[id] = int(goals.get(id, 0)) + int(row.get("goals", 0))
	var rows: Array = []
	for player in players:
		var id := String(player.get("id", ""))
		rows.append({
			"player_id": id,
			"name": _person_name(player),
			"appearances": int(player.get("career_appearances", 0)),
			"goals": int(goals.get(id, player.get("career_goals", 0))),
			"retired": bool(player.get("retired", false)),
		})
	rows.sort_custom(func(a, b):
		if int(a.goals) == int(b.goals): return int(a.appearances) > int(b.appearances)
		return int(a.goals) > int(b.goals)
	)
	return rows.slice(0, mini(25, rows.size()))

func _transfer_records(world: Dictionary, player_names: Dictionary, club_names: Dictionary) -> Array:
	var rows: Array = []
	for transfer in world.get("transfers", []):
		var fee := int(transfer.get("fee", transfer.get("amount", transfer.get("transfer_fee", 0))))
		if fee <= 0: continue
		rows.append({
			"player": player_names.get(String(transfer.get("player_id", "")), "Unknown player"),
			"from": club_names.get(String(transfer.get("from_club_id", transfer.get("selling_club_id", ""))), "Free agent"),
			"to": club_names.get(String(transfer.get("to_club_id", transfer.get("buying_club_id", ""))), "Unknown club"),
			"fee": fee,
			"date": String(transfer.get("date", transfer.get("completed_date", ""))),
		})
	rows.sort_custom(func(a, b): return int(a.fee) > int(b.fee))
	return rows.slice(0, mini(20, rows.size()))

func _club_honours(world: Dictionary, history: Array, club_names: Dictionary, competition_names: Dictionary) -> Array:
	var totals := {}
	for row in world.get("club_honours", []):
		var club_id := String(row.get("club_id", ""))
		if club_id == "": continue
		var key := "%s|%s" % [club_id, String(row.get("competition_id", row.get("competition", "")))]
		if not totals.has(key): totals[key] = {"club_id":club_id,"competition_id":String(row.get("competition_id", row.get("competition", ""))),"titles":0}
		totals[key].titles = int(totals[key].titles) + int(row.get("titles", 1))
	for row in _championship_rows(world, history):
		var club_id := String(row.get("champion_id", row.get("winner_club_id", row.get("club_id", ""))))
		if club_id == "": continue
		var competition_id := String(row.get("competition_id", ""))
		var key := "%s|%s" % [club_id, competition_id]
		if not totals.has(key): totals[key] = {"club_id":club_id,"competition_id":competition_id,"titles":0}
		totals[key].titles = int(totals[key].titles) + 1
	var rows: Array = []
	for value in totals.values():
		rows.append({"club":club_names.get(String(value.club_id), String(value.club_id)),"competition":competition_names.get(String(value.competition_id), String(value.competition_id)),"titles":int(value.titles)})
	rows.sort_custom(func(a, b): return int(a.titles) > int(b.titles))
	return rows.slice(0, mini(30, rows.size()))

func _competition_history(world: Dictionary, history: Array, club_names: Dictionary, competition_names: Dictionary) -> Array:
	var rows: Array = []
	for row in _championship_rows(world, history):
		var competition_id := String(row.get("competition_id", ""))
		var champion_id := String(row.get("champion_id", row.get("winner_club_id", row.get("club_id", ""))))
		if competition_id == "" or champion_id == "": continue
		rows.append({
			"season": int(row.get("season_year", row.get("year", 0))),
			"competition": competition_names.get(competition_id, competition_id),
			"champion": club_names.get(champion_id, champion_id),
		})
	rows.sort_custom(func(a, b): return int(a.season) > int(b.season))
	return rows.slice(0, mini(50, rows.size()))

func _manager_history(world: Dictionary, club_names: Dictionary) -> Array:
	var rows: Array = []
	for row in world.get("manager_history", []):
		rows.append({
			"manager": String(row.get("manager_name", row.get("name", row.get("manager_id", "Manager")))),
			"club": club_names.get(String(row.get("club_id", "")), String(row.get("club_id", ""))),
			"from": String(row.get("start_date", row.get("from", ""))),
			"to": String(row.get("end_date", row.get("to", "present"))),
			"reason": String(row.get("reason", row.get("outcome", ""))),
		})
	return rows.slice(maxi(0, rows.size() - 30), rows.size())

func _legends(world: Dictionary, player_names: Dictionary, club_names: Dictionary) -> Array:
	var rows: Array = []
	for legend in world.get("legends", []):
		var player_id := String(legend.get("player_id", legend.get("person_id", "")))
		rows.append({
			"name": player_names.get(player_id, String(legend.get("name", player_id))),
			"club": club_names.get(String(legend.get("club_id", "")), String(legend.get("club_id", ""))),
			"score": float(legend.get("score", legend.get("legend_score", 0.0))),
			"summary": String(legend.get("summary", legend.get("reason", "Club legend"))),
		})
	rows.sort_custom(func(a, b): return float(a.score) > float(b.score))
	return rows.slice(0, mini(25, rows.size()))

func _timeline(world: Dictionary, history: Array) -> Array:
	var rows: Array = []
	for source in [world.get("news", []), world.get("news_events", []), world.get("causal_records", []), history]:
		for item in source:
			if typeof(item) != TYPE_DICTIONARY: continue
			var text := String(item.get("headline", item.get("title", item.get("summary", item.get("type", "")))))
			if text == "": continue
			rows.append({"date":String(item.get("date", item.get("season_year", item.get("year", "")))),"text":text})
	return rows.slice(maxi(0, rows.size() - 100), rows.size())

func _championship_rows(world: Dictionary, history: Array) -> Array:
	var rows: Array = []
	for key in ["competition_history", "season_history", "historical_records"]:
		for row in world.get(key, []):
			if typeof(row) == TYPE_DICTIONARY: rows.append(row)
	for row in history:
		if typeof(row) == TYPE_DICTIONARY and (row.has("champion_id") or row.has("winner_club_id")):
			rows.append(row)
	return rows

func _index_names(values: Array) -> Dictionary:
	var out := {}
	for value in values:
		if typeof(value) != TYPE_DICTIONARY: continue
		var id := String(value.get("id", ""))
		if id == "": continue
		out[id] = _person_name(value)
	return out

func _person_name(value: Dictionary) -> String:
	var name := String(value.get("name", "")).strip_edges()
	if name != "": return name
	name = (String(value.get("first_name", "")) + " " + String(value.get("last_name", ""))).strip_edges()
	return name if name != "" else String(value.get("id", "Unknown"))
