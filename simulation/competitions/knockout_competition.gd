class_name KnockoutCompetition
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func create_bracket(club_ids: Array, seed: int) -> Dictionary:
	var entrants: Array = club_ids.duplicate()
	entrants.sort()
	_shuffle(entrants, seed)
	var size := 1
	while size < entrants.size():
		size *= 2
	while entrants.size() < size:
		entrants.append("")
	return {"round": 1, "entrants": entrants, "matches": _pair(entrants), "complete": false, "winner": ""}

func advance_round(bracket: Dictionary, results: Array) -> Dictionary:
	var winners: Array = []
	for i in range(bracket.matches.size()):
		var match: Dictionary = bracket.matches[i]
		var home := String(match.home)
		var away := String(match.away)
		if home == "": winners.append(away); continue
		if away == "": winners.append(home); continue
		if i >= results.size():
			return {}
		var result: Dictionary = results[i]
		var winner := home if int(result.home_goals) > int(result.away_goals) else away
		if int(result.home_goals) == int(result.away_goals):
			winner = String(result.get("shootout_winner", ""))
			if winner not in [home, away]:
				return {}
		winners.append(winner)
	if winners.size() == 1:
		bracket.complete = true
		bracket.winner = winners[0]
		bracket.entrants = winners
		bracket.matches = []
		return bracket
	bracket.round = int(bracket.round) + 1
	bracket.entrants = winners
	bracket.matches = _pair(winners)
	return bracket

func _pair(entrants: Array) -> Array:
	var matches: Array = []
	for i in range(0, entrants.size(), 2):
		matches.append({"home": String(entrants[i]), "away": String(entrants[i + 1])})
	return matches

func _shuffle(values: Array, seed: int) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j: int = SeededRngClass.value_for(seed, 91000 + i) % (i + 1)
		var tmp = values[i]
		values[i] = values[j]
		values[j] = tmp
