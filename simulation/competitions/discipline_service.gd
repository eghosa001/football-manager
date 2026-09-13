class_name DisciplineService
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	var discipline: Variant = world.get("discipline", {})
	if not discipline is Dictionary:
		discipline = {}
	world["discipline"] = discipline
	for competition_id in (discipline as Dictionary).keys():
		_normalize_competition(world, String(competition_id))

func apply_match(world: Dictionary, competition_id: String, match_id: String, events: Array, rules: Dictionary = {}) -> Dictionary:
	var competition: Dictionary = _normalize_competition(world, competition_id)
	var matches: Dictionary = competition.get("matches", {})
	if matches.has(match_id): return competition
	var players: Dictionary = competition.get("players", {})
	var red_ban := maxi(1,int(rules.get("red_ban_matches",1)))
	var second_yellow_ban := maxi(1,int(rules.get("two_yellow_ban_matches",1)))
	var thresholds: Array = rules.get("yellow_thresholds",[int(rules.get("yellow_limit",5))])
	var bans: Array = rules.get("yellow_bans",[1])
	for event in events:
		if String(event.get("type","")) != "card": continue
		var id := String(event.get("player_id",""))
		if id == "": continue
		var record: Dictionary = _normalize_record(players.get(id, {}))
		var card := String(event.get("card","yellow"))
		if card == "red":
			record["reds"] = int(record.get("reds",0))+1
			record["ban_remaining"] = int(record.get("ban_remaining",0))+red_ban
		elif card == "second_yellow":
			record["yellows"] = int(record.get("yellows",0))+1
			record["ban_remaining"] = int(record.get("ban_remaining",0))+second_yellow_ban
		else:
			record["yellows"] = int(record.get("yellows",0))+1
			_apply_yellow_threshold(record,thresholds,bans)
		var history: Array = record.get("history", [])
		history.append({"match_id":match_id,"minute":int(event.get("minute",0)),"card":card})
		record["history"] = history
		players[id] = record
	matches[match_id] = true
	competition["players"] = players
	competition["matches"] = matches
	world.discipline[competition_id] = competition
	return competition

func is_suspended(world: Dictionary, competition_id: String, player_id: String) -> bool:
	var competition: Dictionary = _normalize_competition(world, competition_id)
	var players: Dictionary = competition.get("players", {})
	var record: Dictionary = _normalize_record(players.get(player_id, {}))
	return int(record.get("ban_remaining",0)) > 0

func serve_fixture(world: Dictionary, competition_id: String, eligible_player_ids: Array, fixture_id: String = "") -> Array:
	var competition: Dictionary = _normalize_competition(world, competition_id)
	var served: Array = []
	var records: Dictionary = competition.get("players",{})
	for value in eligible_player_ids:
		var id := String(value)
		if not records.has(id): continue
		var record: Dictionary = _normalize_record(records[id])
		if int(record.get("ban_remaining",0)) <= 0: continue
		record["ban_remaining"] = int(record.get("ban_remaining",0))-1
		var history: Array = record.get("history", [])
		history.append({"type":"ban_served","fixture_id":fixture_id})
		record["history"] = history
		records[id] = record
		served.append(id)
	competition["players"] = records
	world.discipline[competition_id] = competition
	return served

func reset_season(world: Dictionary, season_year: int, preserve_bans: bool = true) -> void:
	ensure_world(world)
	for competition_id_value in world.discipline.keys():
		var competition_id := String(competition_id_value)
		var competition: Dictionary = _normalize_competition(world, competition_id)
		var players: Dictionary = competition.get("players", {})
		for player_id in players.keys():
			var record: Dictionary = _normalize_record(players[player_id])
			var ban := int(record.get("ban_remaining",0)) if preserve_bans else 0
			record["yellows"] = 0
			record["thresholds_served"] = []
			record["ban_remaining"] = ban
			players[player_id] = record
		competition["players"] = players
		competition["matches"] = {}
		competition["season_year"] = season_year
		world.discipline[competition_id] = competition

func clear_yellows_after_stage(world: Dictionary, competition_id: String) -> void:
	var competition: Dictionary = _normalize_competition(world, competition_id)
	var players: Dictionary = competition.get("players", {})
	for player_id in players.keys():
		var record: Dictionary = _normalize_record(players[player_id])
		record["yellows"] = 0
		record["thresholds_served"] = []
		players[player_id] = record
	competition["players"] = players
	world.discipline[competition_id] = competition

func carry_over(world: Dictionary, from_competition: String, to_competition: String, player_id: String, allow_red_only: bool = true) -> void:
	var source_comp: Dictionary = _normalize_competition(world, from_competition)
	var source_players: Dictionary = source_comp.get("players", {})
	if not source_players.has(player_id): return
	var source: Dictionary = _normalize_record(source_players[player_id])
	if allow_red_only and int(source.get("reds",0)) <= 0: return
	var target_comp: Dictionary = _normalize_competition(world, to_competition)
	var target_players: Dictionary = target_comp.get("players", {})
	var target: Dictionary = _normalize_record(target_players.get(player_id, {}))
	target["ban_remaining"] = maxi(int(target.get("ban_remaining",0)),int(source.get("ban_remaining",0)))
	target_players[player_id] = target
	target_comp["players"] = target_players
	world.discipline[to_competition] = target_comp

func _normalize_competition(world: Dictionary, competition_id: String) -> Dictionary:
	var discipline: Variant = world.get("discipline", {})
	if not discipline is Dictionary:
		discipline = {}
		world["discipline"] = discipline
	var raw: Variant = (discipline as Dictionary).get(competition_id, {})
	var competition: Dictionary = raw if raw is Dictionary else {}
	if not competition.get("players", {}) is Dictionary:
		competition["players"] = {}
	else:
		competition["players"] = competition.get("players", {})
	if not competition.get("matches", {}) is Dictionary:
		competition["matches"] = {}
	else:
		competition["matches"] = competition.get("matches", {})
	competition["season_year"] = int(competition.get("season_year", world.get("season_year",0)))
	var players: Dictionary = competition.get("players", {})
	for player_id in players.keys():
		players[player_id] = _normalize_record(players[player_id])
	competition["players"] = players
	(discipline as Dictionary)[competition_id] = competition
	world["discipline"] = discipline
	return competition

func _normalize_record(value: Variant) -> Dictionary:
	var record: Dictionary = value if value is Dictionary else {}
	record["yellows"] = maxi(0, int(record.get("yellows",0)))
	record["reds"] = maxi(0, int(record.get("reds",0)))
	record["ban_remaining"] = maxi(0, int(record.get("ban_remaining",0)))
	if not record.get("history", []) is Array: record["history"] = []
	if not record.get("thresholds_served", []) is Array: record["thresholds_served"] = []
	return record

func _apply_yellow_threshold(record: Dictionary, thresholds: Array, bans: Array) -> void:
	var served: Array = record.get("thresholds_served",[])
	for i in range(thresholds.size()):
		var threshold := int(thresholds[i])
		if int(record.get("yellows",0)) < threshold or threshold in served: continue
		var ban := int(bans[i]) if i < bans.size() else 1
		record["ban_remaining"] = int(record.get("ban_remaining",0))+maxi(1,ban)
		served.append(threshold)
	record["thresholds_served"] = served
