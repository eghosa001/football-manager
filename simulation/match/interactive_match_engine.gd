extends "res://simulation/match/full_match_engine_core.gd"

var _user_substitutions: Array = []

func simulate_match(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int, context: Dictionary = {}) -> Dictionary:
	_user_substitutions = context.get("user_substitutions", []).duplicate(true)
	return super.simulate_match(home_club, away_club, players, seed, context)

func _planned_substitutions(players: Array, home_id: String, away_id: String, home: Array, away: Array) -> Array:
	var planned: Array = super._planned_substitutions(players, home_id, away_id, home, away)
	if _user_substitutions.is_empty():
		return planned
	var home_ids := _id_set(home)
	var away_ids := _id_set(away)
	var home_bench := _id_set(_bench(players, home_id, home))
	var away_bench := _id_set(_bench(players, away_id, away))
	var custom_by_side := {"home": [], "away": []}
	for row in _user_substitutions:
		if not row is Dictionary:
			continue
		var side := String(row.get("side", "home"))
		if side not in ["home", "away"]:
			continue
		var player_out := String(row.get("player_out", ""))
		var player_in := String(row.get("player_in", ""))
		var starters: Dictionary = home_ids if side == "home" else away_ids
		var bench: Dictionary = home_bench if side == "home" else away_bench
		if player_out == "" or player_in == "" or not starters.has(player_out) or not bench.has(player_in):
			continue
		if custom_by_side[side].size() >= 5:
			continue
		custom_by_side[side].append({
			"minute": clampi(int(row.get("minute", 60)), 1, 89),
			"type": "substitution",
			"side": side,
			"player_out": player_out,
			"player_in": player_in,
			"success": true,
			"user_directed": true,
		})
	for side in ["home", "away"]:
		if custom_by_side[side].is_empty():
			continue
		for index in range(planned.size() - 1, -1, -1):
			if String(planned[index].get("side", "")) == side:
				planned.remove_at(index)
		planned.append_array(custom_by_side[side])
	planned.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("minute", 0)) < int(b.get("minute", 0)))
	return planned

func _id_set(players: Array) -> Dictionary:
	var result := {}
	for player in players:
		result[String(player.get("id", ""))] = true
	return result
