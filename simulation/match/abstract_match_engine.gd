class_name AbstractMatchEngine
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const MatchFactorsClass = preload("res://simulation/match/match_factors.gd")
const SpecialAbilityServiceClass = preload("res://simulation/players/special_ability_service.gd")

const MATCH_MINUTES := 90
const BASE_POSSESSIONS := 112

var _abilities = SpecialAbilityServiceClass.new()

func simulate_match(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int, context: Dictionary = {}) -> Dictionary:
	var home_players: Array = _players_for_club(players, home_club.id)
	var away_players: Array = _players_for_club(players, away_club.id)
	assert(home_players.size() >= 11 and away_players.size() >= 11)

	var home_lineup: Array = _select_lineup(home_players)
	var away_lineup: Array = _select_lineup(away_players)
	var starting_home := _ids(home_lineup)
	var starting_away := _ids(away_lineup)
	var match_context := _match_context(context, home_club, away_club)
	var factors := MatchFactorsClass.new().breakdown(home_club, away_club, players, match_context)
	var home_strength: float = _lineup_strength(home_lineup, 0, 0, match_context) + 2.0 + float(factors.total_home_edge)
	var away_strength: float = _lineup_strength(away_lineup, 0, 0, match_context)
	var strength_share: float = clampf(home_strength / maxf(home_strength + away_strength, 1.0), 0.30, 0.70)

	var result := {
		"seed": seed,
		"home_club_id": home_club.id,
		"away_club_id": away_club.id,
		"home_goals": 0,
		"away_goals": 0,
		"events": [],
		"lineups": {"home": starting_home, "away": starting_away},
		"final_lineups": {"home": [], "away": []},
		"substitutions": [],
		"ratings": {},
		"stats": {
			"home": _empty_stats(),
			"away": _empty_stats(),
		}
	}
	var substitutions := _planned_substitutions(home_players, away_players, home_lineup, away_lineup, seed)

	for sequence_index in range(BASE_POSSESSIONS):
		var base_key: int = sequence_index * 100
		var minute: int = clampi(int((float(sequence_index) / BASE_POSSESSIONS) * MATCH_MINUTES) + 1, 1, 90)
		_apply_due_substitutions(result, substitutions, home_lineup, away_lineup, minute)
		var dynamic_home := _lineup_strength(home_lineup, minute, result.home_goals - result.away_goals, match_context)
		var dynamic_away := _lineup_strength(away_lineup, minute, result.away_goals - result.home_goals, match_context)
		strength_share = clampf((dynamic_home + 2.0 + float(factors.total_home_edge)) / maxf(dynamic_home + dynamic_away + 2.0 + float(factors.total_home_edge), 1.0), 0.30, 0.70)
		var side: String = "home" if _unit(seed, base_key + 1) < strength_share else "away"
		var lineup: Array = home_lineup if side == "home" else away_lineup
		var opponent: Array = away_lineup if side == "home" else home_lineup
		var score_diff := result.home_goals - result.away_goals if side == "home" else result.away_goals - result.home_goals
		_simulate_possession(result, side, lineup, opponent, minute, seed, base_key, score_diff, match_context)
		_maybe_card(result, side, opponent, minute, seed, base_key)

	_finalize_possession(result)
	result.final_lineups.home = _ids(home_lineup)
	result.final_lineups.away = _ids(away_lineup)
	_finalize_ratings(result, home_players, away_players)
	result["factors"] = factors
	result["match_context"] = match_context
	result["special_ability_impact"] = _ability_impact_summary(result, players)
	return result

func apply_to_fixture(fixture: Dictionary, result: Dictionary) -> void:
	fixture.played = true
	fixture.home_goals = result.home_goals
	fixture.away_goals = result.away_goals

func _simulate_possession(result: Dictionary, side: String, lineup: Array, opponent: Array, minute: int, seed: int, base_key: int, score_diff: int, context: Dictionary) -> void:
	var stats: Dictionary = result.stats[side]
	var pass_attempts: int = _rand_int(seed, base_key + 2, 1, 4)
	var passer: Dictionary = _pick_indexed(lineup, seed, base_key + 3)
	for i in range(pass_attempts):
		stats.passes += 1
		var came_on := int(passer.get("_came_on_minute", 0)) > 0
		var situational := _abilities.situational_bonus(passer, {"minute":minute,"score_diff":score_diff,"came_on":came_on,"importance":float(context.get("importance",0.5)),"phase":"midfield"})
		var pass_probability: float = clampf(0.72 + (_player_quality(passer, minute, score_diff, context) - 50.0) * 0.0025 + situational * 0.0015, 0.60, 0.92)
		if _unit(seed, base_key + 10 + i * 2) < pass_probability:
			stats.completed_passes += 1
			result.events.append({"minute": minute, "type": "pass", "side": side, "player_id": passer.id, "outcome": "complete"})
			passer = _pick_indexed(lineup, seed, base_key + 11 + i * 2)
		else:
			result.events.append({"minute": minute, "type": "pass", "side": side, "player_id": passer.id, "outcome": "incomplete"})
			return

	var team_quality: float = _lineup_strength(lineup, minute, score_diff, context)
	var opponent_quality: float = _lineup_strength(opponent, minute, -score_diff, context)
	var shot_probability: float = clampf(0.38 + (team_quality - opponent_quality) * 0.004, 0.24, 0.54)
	if _unit(seed, base_key + 30) >= shot_probability:
		return

	var shooter: Dictionary = _pick_shooter(lineup, seed, base_key + 31)
	var xg: float = _shot_xg(shooter, seed, base_key + 32)
	var shot_context := {"minute":minute,"score_diff":score_diff,"came_on":int(shooter.get("_came_on_minute",0))>0,"importance":float(context.get("importance",0.5)),"phase":"shot"}
	xg = clampf(xg * _abilities.shot_multiplier(shooter, shot_context), 0.01, 0.55)
	stats.shots += 1
	stats.xg += xg
	var goal_probability: float = clampf(xg * (0.82 + _player_quality(shooter, minute, score_diff, context) / 300.0), 0.01, 0.72)
	var keeper := _goalkeeper(opponent)
	if not keeper.is_empty():
		goal_probability *= 1.0 - _abilities.goalkeeper_goal_reduction(keeper, {"minute":minute,"importance":float(context.get("importance",0.5)),"phase":"goalkeeping"})
	var goal: bool = _unit(seed, base_key + 33) < goal_probability
	var on_target_probability: float = clampf(0.30 + (_player_quality(shooter, minute, score_diff, context) - 50.0) * 0.003, 0.24, 0.55)
	var on_target: bool = goal or _unit(seed, base_key + 34) < on_target_probability
	if on_target:
		stats.shots_on_target += 1
	if goal:
		stats.goals += 1
		if side == "home": result.home_goals += 1
		else: result.away_goals += 1
	result.events.append({"minute":minute,"type":"shot","side":side,"player_id":shooter.id,"goalkeeper_id":String(keeper.get("id","")),"xg":snappedf(xg,0.001),"outcome":"goal" if goal else ("saved" if on_target else "off_target"),"special_ability":_active_ability_label(shooter, minute, score_diff, context)})

func _maybe_card(result: Dictionary, possession_side: String, defenders: Array, minute: int, seed: int, base_key: int) -> void:
	if _unit(seed, base_key + 40) >= 0.021: return
	var defending_side: String = "away" if possession_side == "home" else "home"
	var player: Dictionary = _pick_indexed(defenders, seed, base_key + 41)
	var red: bool = _unit(seed, base_key + 42) < 0.035
	result.stats[defending_side].cards += 1
	if red: result.stats[defending_side].red_cards += 1
	result.events.append({"minute": minute, "type": "card", "side": defending_side, "player_id": player.id, "card": "red" if red else "yellow"})

func _planned_substitutions(home_players: Array, away_players: Array, home_lineup: Array, away_lineup: Array, seed: int) -> Array:
	var result: Array = []
	_add_sub_plan(result, "home", home_players, home_lineup, seed, 20_000)
	_add_sub_plan(result, "away", away_players, away_lineup, seed, 20_100)
	return result

func _add_sub_plan(result: Array, side: String, squad: Array, lineup: Array, seed: int, key_base: int) -> void:
	var bench := _bench(squad, lineup)
	var count := mini(5, bench.size(), lineup.size())
	for i in range(count):
		var base_minute := [58, 65, 72, 79, 84][i]
		var minute := base_minute + _rand_int(seed, key_base + i, -2, 2)
		result.append({"minute":minute,"side":side,"player_out":String(lineup[lineup.size()-1-i].id),"player_in":String(bench[i].id),"player":bench[i],"applied":false})

func _apply_due_substitutions(result: Dictionary, plan: Array, home_lineup: Array, away_lineup: Array, minute: int) -> void:
	for substitution in plan:
		if bool(substitution.get("applied", false)) or int(substitution.get("minute", 99)) > minute: continue
		var lineup := home_lineup if String(substitution.side) == "home" else away_lineup
		for i in range(lineup.size()):
			if String(lineup[i].id) != String(substitution.player_out): continue
			var incoming: Dictionary = substitution.player.duplicate(true)
			incoming["_came_on_minute"] = minute
			lineup[i] = incoming
			substitution["applied"] = true
			var event := {"minute":minute,"type":"substitution","side":String(substitution.side),"player_out":String(substitution.player_out),"player_in":String(substitution.player_in)}
			if _abilities.has(incoming, SpecialAbilityServiceClass.SUPER_SUB): event["special_ability"] = "Super Sub"
			result.substitutions.append(event)
			result.events.append(event.duplicate(true))
			break

func _bench(squad: Array, lineup: Array) -> Array:
	var ids := {}
	for player in lineup: ids[String(player.id)] = true
	var bench: Array = []
	for player in squad:
		if not ids.has(String(player.id)): bench.append(player)
	bench.sort_custom(func(a: Dictionary, b: Dictionary):
		var av := float(a.get("current_ability",0)) + (6.0 if _abilities.has(a, SpecialAbilityServiceClass.SUPER_SUB) else 0.0)
		var bv := float(b.get("current_ability",0)) + (6.0 if _abilities.has(b, SpecialAbilityServiceClass.SUPER_SUB) else 0.0)
		if is_equal_approx(av,bv): return String(a.id) < String(b.id)
		return av > bv
	)
	return bench

func _finalize_possession(result: Dictionary) -> void:
	var home_passes: float = result.stats.home.passes
	var away_passes: float = result.stats.away.passes
	var total: float = maxf(home_passes + away_passes, 1.0)
	result.stats.home.possession = snappedf(home_passes / total * 100.0, 0.1)
	result.stats.away.possession = snappedf(100.0 - result.stats.home.possession, 0.1)
	result.stats.home.xg = snappedf(result.stats.home.xg, 0.01)
	result.stats.away.xg = snappedf(result.stats.away.xg, 0.01)

func _finalize_ratings(result: Dictionary, home_players: Array, away_players: Array) -> void:
	var home_ids: Array = result.lineups.home.duplicate()
	var away_ids: Array = result.lineups.away.duplicate()
	for event in result.substitutions:
		if String(event.side) == "home" and String(event.player_in) not in home_ids: home_ids.append(String(event.player_in))
		if String(event.side) == "away" and String(event.player_in) not in away_ids: away_ids.append(String(event.player_in))
	for player in home_players:
		if String(player.id) in home_ids: result.ratings[player.id] = _rating_for(player.id, "home", result)
	for player in away_players:
		if String(player.id) in away_ids: result.ratings[player.id] = _rating_for(player.id, "away", result)

func _rating_for(player_id: String, side: String, result: Dictionary) -> float:
	var rating := 6.5
	for event in result.events:
		if event.get("player_id", "") != player_id: continue
		if event.type == "shot" and event.outcome == "goal": rating += 0.8
		elif event.type == "pass" and event.outcome == "complete": rating += 0.006
		elif event.type == "pass" and event.outcome == "incomplete": rating -= 0.012
		elif event.type == "card": rating -= 0.25 if event.card == "yellow" else 1.0
	var goal_difference: int = result.home_goals - result.away_goals
	if side == "away": goal_difference *= -1
	rating += clampf(goal_difference * 0.08, -0.4, 0.4)
	return snappedf(clampf(rating, 3.0, 10.0), 0.1)

func _players_for_club(players: Array, club_id: String) -> Array:
	var result: Array = []
	for player in players:
		if player.club_id == club_id and not player.retired: result.append(player)
	return result

func _select_lineup(players: Array) -> Array:
	var remaining: Array = players.duplicate()
	var selected: Array = []
	while selected.size() < 11:
		var best_index := 0
		for i in range(1, remaining.size()):
			if _player_precedes(remaining[i], remaining[best_index]): best_index = i
		selected.append(remaining[best_index])
		remaining.remove_at(best_index)
	return selected

func _player_precedes(a: Dictionary, b: Dictionary) -> bool:
	if a.current_ability != b.current_ability: return a.current_ability > b.current_ability
	return String(a.id) < String(b.id)

func _lineup_strength(lineup: Array, minute: int, score_diff: int, context: Dictionary) -> float:
	var total := 0.0
	for player in lineup:
		total += _player_quality(player, minute, score_diff, context)
	return total / maxf(float(lineup.size()), 1.0)

func _player_quality(player: Dictionary, minute: int = 0, score_diff: int = 0, context: Dictionary = {}) -> float:
	var base := float(player.current_ability) * (0.85 + float(player.fitness) / 1000.0) * (0.96 + float(player.morale) / 1750.0)
	var came_on := int(player.get("_came_on_minute", 0)) > 0
	var bonus := _abilities.situational_bonus(player, {"minute":minute,"score_diff":score_diff,"came_on":came_on,"importance":float(context.get("importance",0.5)),"phase":"general"})
	return base + bonus

func _pick_shooter(lineup: Array, seed: int, key: int) -> Dictionary:
	var attacking: Array = []
	for player in lineup:
		if player.position in ["ST", "AML", "AMR", "AMC"]: attacking.append(player)
	return _pick_indexed(attacking if not attacking.is_empty() else lineup, seed, key)

func _goalkeeper(lineup: Array) -> Dictionary:
	for player in lineup:
		if String(player.get("position", "")) == "GK": return player
	return {}

func _shot_xg(shooter: Dictionary, seed: int, key: int) -> float:
	var base: float = 0.02 + (0.23 - 0.02) * _unit(seed, key)
	if shooter.position == "ST": base += 0.02
	return clampf(base, 0.01, 0.45)

func _pick_indexed(values: Array, seed: int, key: int) -> Variant:
	assert(not values.is_empty())
	var index := _rand_int(seed, key, 0, values.size() - 1)
	return values[index]

func _rand_int(seed: int, key: int, min_value: int, max_value: int) -> int:
	assert(max_value >= min_value)
	var span := max_value - min_value + 1
	return min_value + (SeededRngClass.value_for(seed, key) % span)

func _unit(seed: int, key: int) -> float:
	return SeededRngClass.unit_for(seed, key)

func _match_context(context: Dictionary, home_club: Dictionary, away_club: Dictionary) -> Dictionary:
	var merged := {"is_home": true, "importance": 0.5, "stage": "", "derby": false}
	for key in context.keys(): merged[key] = context[key]
	if home_club.has("match_context") and home_club.get("match_context") is Dictionary:
		for key in home_club.get("match_context", {}).keys(): merged[key] = home_club.get("match_context", {})[key]
	if String(home_club.get("country_id", "")) != "" and String(home_club.get("country_id", "")) == String(away_club.get("country_id", "")):
		merged["derby"] = bool(merged.get("derby", false))
	return merged

func _active_ability_label(player: Dictionary, minute: int, score_diff: int, context: Dictionary) -> String:
	if _abilities.situational_bonus(player, {"minute":minute,"score_diff":score_diff,"came_on":int(player.get("_came_on_minute",0))>0,"importance":float(context.get("importance",0.5)),"phase":"shot"}) <= 0.0:
		return ""
	var labels := _abilities.labels_for(player)
	return String(labels[0]) if not labels.is_empty() else ""

func _ability_impact_summary(result: Dictionary, players: Array) -> Array:
	var by_id := {}
	for player in players: by_id[String(player.get("id",""))] = player
	var rows: Array = []
	var seen := {}
	for event in result.events:
		var player_id := String(event.get("player_id", event.get("player_in", "")))
		if player_id == "" or seen.has(player_id) or not by_id.has(player_id): continue
		var player: Dictionary = by_id[player_id]
		var labels := _abilities.labels_for(player)
		if labels.is_empty(): continue
		rows.append({"player_id":player_id,"abilities":labels})
		seen[player_id] = true
	return rows

func _ids(players: Array) -> Array:
	var ids: Array = []
	for player in players: ids.append(player.id)
	return ids

func _empty_stats() -> Dictionary:
	return {"possession":0.0,"passes":0,"completed_passes":0,"shots":0,"shots_on_target":0,"goals":0,"xg":0.0,"cards":0,"red_cards":0}
