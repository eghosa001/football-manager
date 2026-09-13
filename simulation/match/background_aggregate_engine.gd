class_name BackgroundAggregateEngine
extends RefCounted

const SeededRng = preload("res://core/rng/seeded_rng.gd")

func simulate_match(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int, context: Dictionary = {}) -> Dictionary:
	var home_squad := _squad_for(players, String(home_club.get("id", "")))
	var away_squad := _squad_for(players, String(away_club.get("id", "")))
	var home_lineup := _best_lineup(home_squad)
	var away_lineup := _best_lineup(away_squad)
	var home_strength := _side_strength(home_club, home_squad, home_lineup, true, context)
	var away_strength := _side_strength(away_club, away_squad, away_lineup, false, context)
	var home_expectation := clampf(1.20 + (home_strength - away_strength) / 26.0 + 0.22, 0.25, 3.10)
	var away_expectation := clampf(1.05 + (away_strength - home_strength) / 27.0, 0.20, 2.90)
	var home_goals := _sample_goals(seed, 101, home_expectation)
	var away_goals := _sample_goals(seed, 211, away_expectation)
	var home_shots := maxi(home_goals, int(round(home_expectation * 6.2 + SeededRng.unit_for(seed, 301) * 5.0)))
	var away_shots := maxi(away_goals, int(round(away_expectation * 6.0 + SeededRng.unit_for(seed, 302) * 5.0)))
	var home_possession := clampf(50.0 + (home_strength - away_strength) * 0.85 + (SeededRng.unit_for(seed, 401) - 0.5) * 7.0, 34.0, 66.0)
	var cards_base := clampf(1.6 + absf(home_strength - away_strength) * 0.02, 0.6, 3.4)
	var home_cards := _sample_goals(seed, 501, cards_base * 0.5)
	var away_cards := _sample_goals(seed, 511, cards_base * 0.55)
	var stats := {
		"home": {"goals": home_goals, "shots": home_shots, "shots_on_target": maxi(home_goals, int(round(home_shots * 0.34))), "xg": snappedf(home_expectation, 0.01), "passes": int(round(home_shots * 22.0)), "passes_completed": int(round(home_shots * 18.0)), "dribbles": int(round(home_shots * 0.9)), "dribbles_completed": int(round(home_shots * 0.45)), "interceptions": int(round(6 + away_shots * 0.4)), "corners": maxi(0, int(round(home_shots * 0.28 + SeededRng.unit_for(seed, 601) * 3.0))), "free_kicks": maxi(0, int(round(8 + SeededRng.unit_for(seed, 611) * 6.0))), "cards": home_cards, "red_cards": 1 if home_cards >= 4 and SeededRng.unit_for(seed, 621) < 0.18 else 0, "saves": maxi(0, int(round(away_shots * 0.34)) - away_goals), "possession": snappedf(home_possession, 0.1)},
		"away": {"goals": away_goals, "shots": away_shots, "shots_on_target": maxi(away_goals, int(round(away_shots * 0.34))), "xg": snappedf(away_expectation, 0.01), "passes": int(round(away_shots * 22.0)), "passes_completed": int(round(away_shots * 18.0)), "dribbles": int(round(away_shots * 0.9)), "dribbles_completed": int(round(away_shots * 0.45)), "interceptions": int(round(6 + home_shots * 0.4)), "corners": maxi(0, int(round(away_shots * 0.28 + SeededRng.unit_for(seed, 602) * 3.0))), "free_kicks": maxi(0, int(round(8 + SeededRng.unit_for(seed, 612) * 6.0))), "cards": away_cards, "red_cards": 1 if away_cards >= 4 and SeededRng.unit_for(seed, 622) < 0.18 else 0, "saves": maxi(0, int(round(home_shots * 0.34)) - home_goals), "possession": snappedf(100.0 - home_possession, 0.1)}
	}
	var home_ids := _ids(home_lineup)
	var away_ids := _ids(away_lineup)
	var events: Array = []
	_append_goal_events(events, "home", home_lineup, home_goals, home_expectation, seed, 700)
	_append_goal_events(events, "away", away_lineup, away_goals, away_expectation, seed, 800)
	events.sort_custom(func(a: Dictionary, b: Dictionary):
		var am := int(a.get("minute", 0)); var bm := int(b.get("minute", 0))
		if am == bm: return String(a.get("side", "")) < String(b.get("side", ""))
		return am < bm
	)
	var active_model := "background_statistical" if not players.is_empty() else "inactive_aggregate"
	return {
		"home_goals": home_goals,
		"away_goals": away_goals,
		"events": events,
		"stats": stats,
		"lineups": {"home": home_ids, "away": away_ids},
		"final_lineups": {"home": home_ids.duplicate(), "away": away_ids.duplicate()},
		"participants": {"home": home_ids, "away": away_ids},
		"ratings": {},
		"model": active_model,
		"seed": seed,
		"strength": {"home": home_strength, "away": away_strength}
	}

func _squad_for(players: Array, club_id: String) -> Array:
	var squad: Array = []
	for player in players:
		if String(player.get("club_id", "")) != club_id: continue
		if bool(player.get("retired", false)) or int(player.get("injured_days", 0)) > 0: continue
		squad.append(player)
	return squad

func _best_lineup(squad: Array) -> Array:
	var ranked: Array = squad.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary):
		var aa := int(a.get("current_ability", 50)); var bb := int(b.get("current_ability", 50))
		if aa == bb: return String(a.get("id", "")) < String(b.get("id", ""))
		return aa > bb
	)
	return ranked.slice(0, mini(11, ranked.size()))

func _side_strength(club: Dictionary, squad: Array, best: Array, is_home: bool, context: Dictionary) -> float:
	if best.is_empty():
		return float(club.get("reputation", 50)) / 12.0
	var total := 0.0
	for player in best:
		total += float(player.get("current_ability", 50)) * (0.65 + 0.35 * float(player.get("fitness", 100)) / 100.0) * (0.94 + 0.12 * float(player.get("morale", 50)) / 100.0)
	var avg := total / float(best.size())
	var tactic: Dictionary = club.get("tactic", {})
	avg += (float(tactic.get("familiarity", 50.0)) - 50.0) * 0.02
	avg += (float(club.get("manager_ability", 50)) - 50.0) * 0.03
	if is_home:
		avg += 1.4 + float(context.get("crowd_boost", 0.0))
	var depth := clampf((float(squad.size()) - 18.0) * 0.08, -1.2, 1.0)
	return avg / 9.0 + depth * 0.2 + float(club.get("reputation", 50)) / 220.0

func _append_goal_events(events: Array, side: String, lineup: Array, goals: int, expectation: float, seed: int, key_base: int) -> void:
	if goals <= 0 or lineup.is_empty(): return
	var candidates := _scoring_candidates(lineup)
	for goal_index in range(goals):
		var scorer := _weighted_scorer(candidates, seed, key_base + goal_index * 19)
		var minute := 1 + int(SeededRng.value_for(seed, key_base + goal_index * 19 + 3) % 90)
		var xg := clampf(expectation / maxf(float(goals + 2), 3.0), 0.05, 0.45)
		events.append({"minute":minute,"type":"goal","side":side,"player_id":String(scorer.get("id", "")),"xg":snappedf(xg,0.001),"outcome":"goal","model":"background_statistical"})

func _scoring_candidates(lineup: Array) -> Array:
	var result: Array = []
	for player in lineup:
		if String(player.get("position", "")) != "GK": result.append(player)
	return result if not result.is_empty() else lineup

func _weighted_scorer(candidates: Array, seed: int, key: int) -> Dictionary:
	var total := 0
	var weights: Array = []
	for player in candidates:
		var position := String(player.get("position", "MC"))
		var position_weight := 7 if position == "ST" else (5 if position in ["AML","AMR","AMC"] else (3 if position in ["MC","DM"] else 2))
		var weight := maxi(1, position_weight * 10 + int(player.get("current_ability", 50)) - 40)
		weights.append(weight)
		total += weight
	var roll := int(SeededRng.value_for(seed, key) % maxi(total, 1))
	var running := 0
	for index in range(candidates.size()):
		running += int(weights[index])
		if roll < running: return candidates[index]
	return candidates[candidates.size() - 1]

func _ids(players: Array) -> Array:
	var result: Array = []
	for player in players: result.append(String(player.get("id", "")))
	return result

func apply_to_fixture(fixture: Dictionary, result: Dictionary) -> void:
	if result.has("error"):
		return
	fixture.played = true
	fixture.home_goals = int(result.get("home_goals",0))
	fixture.away_goals = int(result.get("away_goals",0))

func _sample_goals(seed: int, key: int, expectation: float) -> int:
	# Deterministic inverse-Poisson sampling, capped to keep aggregate results sane.
	var threshold := exp(-expectation)
	var product := 1.0
	var count := 0
	while count < 8:
		product *= maxf(0.000001, SeededRng.unit_for(seed, key + count * 17))
		if product <= threshold:
			break
		count += 1
	return count