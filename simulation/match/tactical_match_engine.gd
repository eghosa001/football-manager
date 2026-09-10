class_name TacticalMatchEngine
extends RefCounted

const BaseMatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")
const TacticsClass = preload("res://simulation/tactics/tactics_manager.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

var _base = BaseMatchEngineClass.new()
var _tactics = TacticsClass.new()

func simulate_match(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int) -> Dictionary:
	var home_tactic: Dictionary = home_club.get("tactic", _tactics.create_tactic("4-3-3"))
	var away_tactic: Dictionary = away_club.get("tactic", _tactics.create_tactic("4-3-3"))
	return simulate_with_tactics(home_club, away_club, players, seed, home_tactic, away_tactic)

func simulate_with_tactics(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int, home_tactic: Dictionary, away_tactic: Dictionary) -> Dictionary:
	var adapted_players: Array = []
	var role_fits := {}
	var home_id := String(home_club.id)
	var away_id := String(away_club.id)
	for player in players:
		var club_id := String(player.get("club_id", ""))
		if club_id != home_id and club_id != away_id:
			continue
		var copy: Dictionary = player.duplicate(true)
		var tactic: Dictionary = home_tactic if club_id == home_id else away_tactic
		var fit: float = _tactics.role_rating(copy, tactic)
		role_fits[String(copy.id)] = fit
		copy.current_ability = clampi(int(float(copy.current_ability) * 0.72 + fit * 0.28), 1, 100)
		adapted_players.append(copy)

	var home_mod: Dictionary = _tactics.style_modifiers(home_tactic)
	var away_mod: Dictionary = _tactics.style_modifiers(away_tactic)
	_apply_team_style(adapted_players, home_id, home_mod)
	_apply_team_style(adapted_players, away_id, away_mod)

	var result: Dictionary = _base.simulate_match(home_club, away_club, adapted_players, seed)
	result["tactics"] = {"home": home_tactic.duplicate(true), "away": away_tactic.duplicate(true)}
	result["style"] = {"home": home_mod, "away": away_mod}
	_apply_style_events(result, "home", home_mod, seed, 610_000)
	_apply_style_events(result, "away", away_mod, seed, 620_000)
	_recalculate_score_and_stats(result)
	_apply_role_aware_ratings(result, role_fits)
	return result

func apply_to_fixture(fixture: Dictionary, result: Dictionary) -> void:
	_base.apply_to_fixture(fixture, result)

func _apply_team_style(players: Array, club_id: String, modifiers: Dictionary) -> void:
	for player in players:
		if String(player.get("club_id", "")) != club_id:
			continue
		var pass_bonus: float = float(modifiers.get("pass", 0.0)) * 100.0
		var possession_bonus: float = float(modifiers.get("possession", 0.0)) * 80.0
		player.current_ability = clampi(int(float(player.current_ability) + pass_bonus + possession_bonus), 1, 100)

func _apply_style_events(result: Dictionary, side: String, modifiers: Dictionary, seed: int, key_base: int) -> void:
	var multiplier: float = float(modifiers.get("sequence_multiplier", 1.0))
	var extra_attempts: int = int(absf(multiplier - 1.0) * 35.0)
	if multiplier > 1.0:
		for i in range(extra_attempts):
			if _unit(seed, key_base + i * 7) < 0.48 + float(modifiers.get("shot", 0.0)):
				_append_extra_shot(result, side, seed, key_base + i * 7 + 1, float(modifiers.get("shot", 0.0)))
	elif multiplier < 1.0:
		_remove_low_value_shots(result, side, extra_attempts)
	var card_bias: float = float(modifiers.get("card", 0.0))
	if card_bias > 0.0:
		var chances: int = int(card_bias * 450.0)
		for i in range(chances):
			if _unit(seed, key_base + 20_000 + i) < 0.20:
				result.events.append({"minute": 15 + (i * 13) % 74, "type": "card", "side": side, "player_id": _lineup_player(result, side, seed, key_base + 30_000 + i), "card": "yellow"})

func _append_extra_shot(result: Dictionary, side: String, seed: int, key: int, shot_modifier: float) -> void:
	var player_id: String = _lineup_player(result, side, seed, key)
	var xg: float = clampf(0.04 + _unit(seed, key + 1) * 0.13 + shot_modifier * 0.4, 0.02, 0.30)
	var goal: bool = _unit(seed, key + 2) < xg
	var on_target: bool = goal or _unit(seed, key + 3) < 0.34
	result.events.append({"minute": 5 + (key % 84), "type": "shot", "side": side, "player_id": player_id, "xg": snappedf(xg, 0.001), "outcome": "goal" if goal else ("saved" if on_target else "off_target"), "tactical": true})

func _remove_low_value_shots(result: Dictionary, side: String, count: int) -> void:
	var removed := 0
	for i in range(result.events.size() - 1, -1, -1):
		if removed >= count:
			break
		var event: Dictionary = result.events[i]
		if String(event.get("side", "")) == side and String(event.get("type", "")) == "shot" and String(event.get("outcome", "")) != "goal":
			result.events.remove_at(i)
			removed += 1

func _recalculate_score_and_stats(result: Dictionary) -> void:
	for side in ["home", "away"]:
		result.stats[side].shots = 0
		result.stats[side].shots_on_target = 0
		result.stats[side].goals = 0
		result.stats[side].xg = 0.0
		result.stats[side].cards = 0
		result.stats[side].red_cards = 0
	result.home_goals = 0
	result.away_goals = 0
	for event in result.events:
		var side: String = String(event.get("side", ""))
		if not side in ["home", "away"]:
			continue
		if String(event.get("type", "")) == "shot":
			result.stats[side].shots += 1
			result.stats[side].xg += float(event.get("xg", 0.0))
			if String(event.get("outcome", "")) in ["goal", "saved"]:
				result.stats[side].shots_on_target += 1
			if String(event.get("outcome", "")) == "goal":
				result.stats[side].goals += 1
				if side == "home":
					result.home_goals += 1
				else:
					result.away_goals += 1
		elif String(event.get("type", "")) == "card":
			result.stats[side].cards += 1
			if String(event.get("card", "")) == "red":
				result.stats[side].red_cards += 1
	result.stats.home.xg = snappedf(float(result.stats.home.xg), 0.01)
	result.stats.away.xg = snappedf(float(result.stats.away.xg), 0.01)

func _apply_role_aware_ratings(result: Dictionary, role_fits: Dictionary) -> void:
	for player_id in result.ratings.keys():
		var fit: float = float(role_fits.get(String(player_id), 50.0))
		var adjustment: float = clampf((fit - 50.0) / 100.0, -0.35, 0.35)
		result.ratings[player_id] = snappedf(clampf(float(result.ratings[player_id]) + adjustment, 3.0, 10.0), 0.1)
	result["rating_policy"] = "role_aware"

func _lineup_player(result: Dictionary, side: String, seed: int, key: int) -> String:
	var lineup: Array = result.lineups[side]
	if lineup.is_empty():
		return ""
	return String(lineup[SeededRngClass.value_for(seed, key) % lineup.size()])

func _unit(seed: int, key: int) -> float:
	return SeededRngClass.unit_for(seed, key)
