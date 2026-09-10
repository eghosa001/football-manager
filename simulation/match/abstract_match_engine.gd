class_name AbstractMatchEngine
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

const MATCH_MINUTES := 90
const BASE_POSSESSIONS := 112

func simulate_match(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int) -> Dictionary:
	var rng = SeededRngClass.new(seed)
	var home_players := _players_for_club(players, home_club.id)
	var away_players := _players_for_club(players, away_club.id)
	assert(home_players.size() >= 11 and away_players.size() >= 11)

	var home_lineup := _select_lineup(home_players)
	var away_lineup := _select_lineup(away_players)
	var home_strength := _lineup_strength(home_lineup) + 2.0
	var away_strength := _lineup_strength(away_lineup)
	var strength_share := clampf(home_strength / maxf(home_strength + away_strength, 1.0), 0.35, 0.65)

	var result := {
		"seed": seed,
		"home_club_id": home_club.id,
		"away_club_id": away_club.id,
		"home_goals": 0,
		"away_goals": 0,
		"events": [],
		"lineups": {"home": _ids(home_lineup), "away": _ids(away_lineup)},
		"substitutions": [],
		"ratings": {},
		"stats": {
			"home": _empty_stats(),
			"away": _empty_stats(),
		}
	}

	for sequence_index in range(BASE_POSSESSIONS):
		var minute := clampi(int((float(sequence_index) / BASE_POSSESSIONS) * MATCH_MINUTES) + 1, 1, 90)
		var side := "home" if rng.randf() < strength_share else "away"
		var lineup: Array = home_lineup if side == "home" else away_lineup
		var opponent: Array = away_lineup if side == "home" else home_lineup
		_simulate_possession(result, side, lineup, opponent, minute, rng)
		_maybe_card(result, side, opponent, minute, rng)

	_apply_planned_substitutions(result, home_players, away_players, home_lineup, away_lineup, rng)
	_finalize_possession(result)
	_finalize_ratings(result, home_lineup, away_lineup)
	return result

func apply_to_fixture(fixture: Dictionary, result: Dictionary) -> void:
	fixture.played = true
	fixture.home_goals = result.home_goals
	fixture.away_goals = result.away_goals

func _simulate_possession(result: Dictionary, side: String, lineup: Array, opponent: Array, minute: int, rng) -> void:
	var stats: Dictionary = result.stats[side]
	var pass_attempts := rng.randi_range(1, 7)
	var passer: Dictionary = rng.pick(lineup)
	for _i in range(pass_attempts):
		stats.passes += 1
		var pass_probability := clampf(0.66 + (_player_quality(passer) - 50.0) * 0.0025, 0.54, 0.88)
		if rng.chance(pass_probability):
			stats.completed_passes += 1
			result.events.append({"minute": minute, "type": "pass", "side": side, "player_id": passer.id, "outcome": "complete"})
			passer = rng.pick(lineup)
		else:
			result.events.append({"minute": minute, "type": "pass", "side": side, "player_id": passer.id, "outcome": "incomplete"})
			return

	var team_quality := _lineup_strength(lineup)
	var opponent_quality := _lineup_strength(opponent)
	var shot_probability := clampf(0.13 + (team_quality - opponent_quality) * 0.003, 0.08, 0.24)
	if not rng.chance(shot_probability):
		return

	var shooter: Dictionary = _pick_shooter(lineup, rng)
	var xg := _shot_xg(shooter, rng)
	stats.shots += 1
	stats.xg += xg
	var on_target_probability := clampf(0.30 + (_player_quality(shooter) - 50.0) * 0.003, 0.22, 0.55)
	var on_target := rng.chance(on_target_probability)
	if on_target:
		stats.shots_on_target += 1
	var goal_probability := xg * (0.75 + _player_quality(shooter) / 200.0)
	var goal := on_target and rng.chance(goal_probability)
	if goal:
		stats.goals += 1
		if side == "home":
			result.home_goals += 1
		else:
			result.away_goals += 1
	result.events.append({
		"minute": minute,
		"type": "shot",
		"side": side,
		"player_id": shooter.id,
		"xg": snappedf(xg, 0.001),
		"outcome": "goal" if goal else ("saved" if on_target else "off_target")
	})

func _maybe_card(result: Dictionary, possession_side: String, defenders: Array, minute: int, rng) -> void:
	if not rng.chance(0.021):
		return
	var defending_side := "away" if possession_side == "home" else "home"
	var player: Dictionary = rng.pick(defenders)
	var red := rng.chance(0.035)
	result.stats[defending_side].cards += 1
	if red:
		result.stats[defending_side].red_cards += 1
	result.events.append({"minute": minute, "type": "card", "side": defending_side, "player_id": player.id, "card": "red" if red else "yellow"})

func _apply_planned_substitutions(result: Dictionary, home_players: Array, away_players: Array, home_lineup: Array, away_lineup: Array, rng) -> void:
	_apply_subs_for_side(result, "home", home_players, home_lineup, rng)
	_apply_subs_for_side(result, "away", away_players, away_lineup, rng)

func _apply_subs_for_side(result: Dictionary, side: String, squad: Array, lineup: Array, rng) -> void:
	var bench: Array = []
	var lineup_ids := {}
	for player in lineup:
		lineup_ids[player.id] = true
	for player in squad:
		if not lineup_ids.has(player.id):
			bench.append(player)
	var count := mini(3, bench.size())
	for i in range(count):
		var minute := 60 + i * 10 + rng.randi_range(-3, 3)
		var player_out: Dictionary = lineup[lineup.size() - 1 - i]
		var player_in: Dictionary = bench[i]
		result.substitutions.append({"minute": minute, "side": side, "player_out": player_out.id, "player_in": player_in.id})
		result.events.append({"minute": minute, "type": "substitution", "side": side, "player_out": player_out.id, "player_in": player_in.id})

func _finalize_possession(result: Dictionary) -> void:
	var home_passes: float = result.stats.home.passes
	var away_passes: float = result.stats.away.passes
	var total := maxf(home_passes + away_passes, 1.0)
	result.stats.home.possession = snappedf(home_passes / total * 100.0, 0.1)
	result.stats.away.possession = snappedf(100.0 - result.stats.home.possession, 0.1)
	result.stats.home.xg = snappedf(result.stats.home.xg, 0.01)
	result.stats.away.xg = snappedf(result.stats.away.xg, 0.01)

func _finalize_ratings(result: Dictionary, home_lineup: Array, away_lineup: Array) -> void:
	for player in home_lineup:
		result.ratings[player.id] = _rating_for(player.id, "home", result)
	for player in away_lineup:
		result.ratings[player.id] = _rating_for(player.id, "away", result)

func _rating_for(player_id: String, side: String, result: Dictionary) -> float:
	var rating := 6.5
	for event in result.events:
		if event.get("player_id", "") != player_id:
			continue
		if event.type == "shot" and event.outcome == "goal":
			rating += 0.8
		elif event.type == "pass" and event.outcome == "complete":
			rating += 0.006
		elif event.type == "pass" and event.outcome == "incomplete":
			rating -= 0.012
		elif event.type == "card":
			rating -= 0.25 if event.card == "yellow" else 1.0
	var goal_difference := result.home_goals - result.away_goals
	if side == "away":
		goal_difference *= -1
	rating += clampf(goal_difference * 0.08, -0.4, 0.4)
	return snappedf(clampf(rating, 3.0, 10.0), 0.1)

func _players_for_club(players: Array, club_id: String) -> Array:
	var result: Array = []
	for player in players:
		if player.club_id == club_id and not player.retired:
			result.append(player)
	return result

func _select_lineup(players: Array) -> Array:
	var sorted := players.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.current_ability > b.current_ability)
	return sorted.slice(0, 11)

func _lineup_strength(lineup: Array) -> float:
	var total := 0.0
	for player in lineup:
		total += _player_quality(player)
	return total / maxf(float(lineup.size()), 1.0)

func _player_quality(player: Dictionary) -> float:
	return float(player.current_ability) * (0.85 + float(player.fitness) / 1000.0) * (0.96 + float(player.morale) / 1750.0)

func _pick_shooter(lineup: Array, rng) -> Dictionary:
	var attacking: Array = []
	for player in lineup:
		if player.position in ["ST", "AML", "AMR", "AMC"]:
			attacking.append(player)
	return rng.pick(attacking if not attacking.is_empty() else lineup)

func _shot_xg(shooter: Dictionary, rng) -> float:
	var base := rng.randf_range(0.04, 0.34)
	if shooter.position == "ST":
		base += 0.035
	return clampf(base, 0.02, 0.55)

func _ids(players: Array) -> Array:
	var ids: Array = []
	for player in players:
		ids.append(player.id)
	return ids

func _empty_stats() -> Dictionary:
	return {
		"possession": 0.0,
		"passes": 0,
		"completed_passes": 0,
		"shots": 0,
		"shots_on_target": 0,
		"goals": 0,
		"xg": 0.0,
		"cards": 0,
		"red_cards": 0,
	}
