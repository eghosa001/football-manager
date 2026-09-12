class_name DisciplineService
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	world["discipline"] = world.get("discipline", {})

func apply_match(world: Dictionary, competition_id: String, match_id: String, events: Array, rules: Dictionary = {}) -> Dictionary:
	ensure_world(world)
	var competition: Dictionary = world.discipline.get(competition_id,{"players":{},"matches":{},"season_year":int(world.get("season_year",0))})
	if competition.matches.has(match_id): return competition
	var red_ban := maxi(1,int(rules.get("red_ban_matches",1)))
	var second_yellow_ban := maxi(1,int(rules.get("two_yellow_ban_matches",1)))
	var thresholds: Array = rules.get("yellow_thresholds",[int(rules.get("yellow_limit",5))])
	var bans: Array = rules.get("yellow_bans",[1])
	for event in events:
		if String(event.get("type","")) != "card": continue
		var id := String(event.get("player_id",""))
		if id == "": continue
		var record: Dictionary = competition.players.get(id,{"yellows":0,"reds":0,"ban_remaining":0,"history":[],"thresholds_served":[]})
		var card := String(event.get("card","yellow"))
		if card == "red":
			record.reds = int(record.reds)+1
			record.ban_remaining = int(record.ban_remaining)+red_ban
		elif card == "second_yellow":
			record.yellows = int(record.yellows)+1
			record.ban_remaining = int(record.ban_remaining)+second_yellow_ban
		else:
			record.yellows = int(record.yellows)+1
			_apply_yellow_threshold(record,thresholds,bans)
		record.history.append({"match_id":match_id,"minute":int(event.get("minute",0)),"card":card})
		competition.players[id] = record
	competition.matches[match_id] = true
	world.discipline[competition_id] = competition
	return competition

func is_suspended(world: Dictionary, competition_id: String, player_id: String) -> bool:
	ensure_world(world)
	var record: Dictionary = world.discipline.get(competition_id,{}).get("players",{}).get(player_id,{})
	return int(record.get("ban_remaining",0)) > 0

func serve_fixture(world: Dictionary, competition_id: String, eligible_player_ids: Array, fixture_id: String = "") -> Array:
	ensure_world(world)
	var served: Array = []
	var competition: Dictionary = world.discipline.get(competition_id,{})
	var records: Dictionary = competition.get("players",{})
	for value in eligible_player_ids:
		var id := String(value)
		if not records.has(id): continue
		var record: Dictionary = records[id]
		if int(record.get("ban_remaining",0)) <= 0: continue
		record.ban_remaining = int(record.ban_remaining)-1
		record.history.append({"type":"ban_served","fixture_id":fixture_id})
		records[id] = record
		served.append(id)
	competition["players"] = records
	world.discipline[competition_id] = competition
	return served

func reset_season(world: Dictionary, season_year: int, preserve_bans: bool = true) -> void:
	ensure_world(world)
	for competition_id in world.discipline.keys():
		var competition: Dictionary = world.discipline[competition_id]
		for player_id in competition.get("players",{}).keys():
			var record: Dictionary = competition.players[player_id]
			var ban := int(record.get("ban_remaining",0)) if preserve_bans else 0
			record["yellows"] = 0
			record["thresholds_served"] = []
			record["ban_remaining"] = ban
			competition.players[player_id] = record
		competition["matches"] = {}
		competition["season_year"] = season_year
		world.discipline[competition_id] = competition

func clear_yellows_after_stage(world: Dictionary, competition_id: String) -> void:
	ensure_world(world)
	var competition: Dictionary = world.discipline.get(competition_id,{})
	for player_id in competition.get("players",{}).keys():
		var record: Dictionary = competition.players[player_id]
		record["yellows"] = 0
		record["thresholds_served"] = []
		competition.players[player_id] = record
	world.discipline[competition_id] = competition

func carry_over(world: Dictionary, from_competition: String, to_competition: String, player_id: String, allow_red_only: bool = true) -> void:
	ensure_world(world)
	var source: Dictionary = world.discipline.get(from_competition,{}).get("players",{}).get(player_id,{})
	if source.is_empty(): return
	if allow_red_only and int(source.get("reds",0)) <= 0: return
	var target_comp: Dictionary = world.discipline.get(to_competition,{"players":{},"matches":{}})
	var target: Dictionary = target_comp.players.get(player_id,{"yellows":0,"reds":0,"ban_remaining":0,"history":[],"thresholds_served":[]})
	target.ban_remaining = maxi(int(target.ban_remaining),int(source.get("ban_remaining",0)))
	target_comp.players[player_id] = target
	world.discipline[to_competition] = target_comp

func _apply_yellow_threshold(record: Dictionary, thresholds: Array, bans: Array) -> void:
	var served: Array = record.get("thresholds_served",[])
	for i in range(thresholds.size()):
		var threshold := int(thresholds[i])
		if int(record.get("yellows",0)) < threshold or threshold in served: continue
		var ban := int(bans[i]) if i < bans.size() else 1
		record.ban_remaining = int(record.ban_remaining)+maxi(1,ban)
		served.append(threshold)
	record["thresholds_served"] = served
