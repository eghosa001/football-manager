class_name DisciplineService
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	world["discipline"] = world.get("discipline", {})

func apply_match(world: Dictionary, competition_id: String, match_id: String, events: Array, rules: Dictionary = {}) -> Dictionary:
	ensure_world(world)
	var competition: Dictionary = world.discipline.get(competition_id, {"players":{},"matches":{}})
	var yellow_limit := maxi(1, int(rules.get("yellow_limit", 5)))
	var red_ban := maxi(1, int(rules.get("red_ban_matches", 1)))
	var two_yellow_ban := maxi(1, int(rules.get("two_yellow_ban_matches", 1)))
	for event in events:
		if String(event.get("type", "")) != "card": continue
		var id := String(event.get("player_id", ""))
		if id == "": continue
		var record: Dictionary = competition.players.get(id, {"yellows":0,"reds":0,"ban_remaining":0,"history":[]})
		var card := String(event.get("card", "yellow"))
		if card == "red":
			record.reds = int(record.reds) + 1
			record.ban_remaining = maxi(int(record.ban_remaining), red_ban)
		else:
			record.yellows = int(record.yellows) + 1
			if int(record.yellows) >= yellow_limit:
				record.yellows = 0
				record.ban_remaining = maxi(int(record.ban_remaining), two_yellow_ban)
		record.history.append({"match_id":match_id,"minute":int(event.get("minute",0)),"card":card})
		competition.players[id] = record
	competition.matches[match_id] = true
	world.discipline[competition_id] = competition
	return competition

func is_suspended(world: Dictionary, competition_id: String, player_id: String) -> bool:
	ensure_world(world)
	var record: Dictionary = world.discipline.get(competition_id, {}).get("players", {}).get(player_id, {})
	return int(record.get("ban_remaining", 0)) > 0

func serve_fixture(world: Dictionary, competition_id: String, registered_players: Array) -> Array:
	ensure_world(world)
	var served: Array = []
	var competition: Dictionary = world.discipline.get(competition_id, {})
	var records: Dictionary = competition.get("players", {})
	for id_value in registered_players:
		var id := String(id_value)
		if not records.has(id): continue
		var record: Dictionary = records[id]
		if int(record.get("ban_remaining", 0)) > 0:
			record.ban_remaining = int(record.ban_remaining) - 1
			record.history.append({"type":"ban_served"})
			records[id] = record
			served.append(id)
	competition["players"] = records
	world.discipline[competition_id] = competition
	return served

func carry_over(world: Dictionary, from_competition: String, to_competition: String, player_id: String, allow_red_only: bool = true) -> void:
	ensure_world(world)
	var source: Dictionary = world.discipline.get(from_competition, {}).get("players", {}).get(player_id, {})
	if source.is_empty(): return
	if allow_red_only and int(source.get("reds", 0)) <= 0: return
	var target_comp: Dictionary = world.discipline.get(to_competition, {"players":{},"matches":{}})
	var target: Dictionary = target_comp.players.get(player_id, {"yellows":0,"reds":0,"ban_remaining":0,"history":[]})
	target.ban_remaining = maxi(int(target.ban_remaining), int(source.get("ban_remaining", 0)))
	target_comp.players[player_id] = target
	world.discipline[to_competition] = target_comp
