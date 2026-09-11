class_name TacticalMatchEngine
extends RefCounted

const BaseMatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")
const TacticsClass = preload("res://simulation/tactics/tactics_manager.gd")

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
	result["tactical_causality"] = "event_generation"
	_apply_role_aware_ratings(result, role_fits)
	return result

func apply_to_fixture(fixture: Dictionary, result: Dictionary) -> void:
	_base.apply_to_fixture(fixture, result)

func _apply_team_style(players: Array, club_id: String, modifiers: Dictionary) -> void:
	for player in players:
		if String(player.get("club_id", "")) != club_id:
			continue
		player["_match_pass_modifier"] = float(modifiers.get("pass", 0.0))
		player["_match_shot_modifier"] = float(modifiers.get("shot", 0.0))
		player["_match_card_modifier"] = float(modifiers.get("card", 0.0))
		player["_match_possession_modifier"] = float(modifiers.get("possession", 0.0))
		player["_match_sequence_modifier"] = float(modifiers.get("sequence_multiplier", 1.0)) - 1.0

func _apply_role_aware_ratings(result: Dictionary, role_fits: Dictionary) -> void:
	for player_id in result.ratings.keys():
		var fit: float = float(role_fits.get(String(player_id), 50.0))
		var adjustment: float = clampf((fit - 50.0) / 100.0, -0.35, 0.35)
		result.ratings[player_id] = snappedf(clampf(float(result.ratings[player_id]) + adjustment, 3.0, 10.0), 0.1)
	result["rating_policy"] = "role_aware"
