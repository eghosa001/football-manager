class_name MatchFactors
extends RefCounted

# Explicit causal weights for match simulation. All computations are
# deterministic functions of (home, away, players, context, seed-tiebreaks);
# randomness enters only through the engine RNG draws, never through weights.
const WEIGHTS := {
	"team_quality": 0.34,
	"form": 0.10,
	"home_advantage": 0.08,
	"morale": 0.08,
	"manager_ability": 0.07,
	"tactical_matchup": 0.12,
	"fitness_availability": 0.12,
	"pressure": 0.09,
}

const FORMATION_COUNTERS := {
	"4-3-3": ["5-3-2", "4-1-4-1"],
	"4-2-3-1": ["3-5-2", "4-4-2"],
	"4-4-2": ["4-2-3-1", "3-4-3"],
	"3-5-2": ["4-3-3", "4-2-2-2"],
	"5-3-2": ["3-4-3", "4-2-3-1"],
	"3-4-3": ["5-3-2", "4-1-4-1"],
	"4-3-1-2": ["3-5-2", "5-3-2"],
	"4-2-2-2": ["4-3-1-2", "4-4-2"],
	"4-1-4-1": ["4-2-2-2", "4-3-1-2"],
}

func breakdown(home_club: Dictionary, away_club: Dictionary, players: Array, context: Dictionary = {}) -> Dictionary:
	var home_ids := _club_player_ids(players, String(home_club.get("id", "")))
	var away_ids := _club_player_ids(players, String(away_club.get("id", "")))
	var home_best := _best_eleven(players, String(home_club.get("id", "")), home_ids)
	var away_best := _best_eleven(players, String(away_club.get("id", "")), away_ids)
	var quality := _avg_ca(home_best) - _avg_ca(away_best)
	var form := _form_value(home_club) - _form_value(away_club)
	var home_edge := _home_value(home_club, context)
	var morale := _avg_morale(home_best) - _avg_morale(away_best)
	var manager := _manager_value(home_club) - _manager_value(away_club)
	var tactics := _tactical_edge(home_club, away_club)
	var fitness := _fitness_value(home_club, home_best, home_ids) - _fitness_value(away_club, away_best, away_ids)
	var pressure := _pressure_edge(home_club, away_club, context)
	var weighted := (
		quality * WEIGHTS.team_quality
		+ form * WEIGHTS.form
		+ home_edge * WEIGHTS.home_advantage * 10.0
		+ morale * WEIGHTS.morale
		+ manager * WEIGHTS.manager_ability
		+ tactics * WEIGHTS.tactical_matchup
		+ fitness * WEIGHTS.fitness_availability
		+ pressure * WEIGHTS.pressure
	)
	return {
		"team_quality": snappedf(quality, 0.01),
		"form": snappedf(form, 0.01),
		"home_advantage": snappedf(home_edge, 0.01),
		"morale": snappedf(morale, 0.01),
		"manager_ability": snappedf(manager, 0.01),
		"tactical_matchup": snappedf(tactics, 0.01),
		"fitness_availability": snappedf(fitness, 0.01),
		"pressure": snappedf(pressure, 0.01),
		"total_home_edge": snappedf(weighted, 0.01),
		"weights": WEIGHTS.duplicate(true),
	}

func home_strength_adjustment(home_club: Dictionary, away_club: Dictionary, players: Array, context: Dictionary = {}) -> float:
	# Additive strength points applied to the home side (negative favors away).
	return float(breakdown(home_club, away_club, players, context).total_home_edge)

func importance_for(competition: Dictionary, fixture: Dictionary = {}) -> Dictionary:
	var comp_type := String(competition.get("competition_type", "league"))
	var importance := 0.5
	var label := "league"
	if bool(competition.get("club_world_cup", false)):
		importance = 1.0; label = "club_world_cup_final"
	elif bool(competition.get("continental", false)):
		importance = 0.9 if int(competition.get("continental_tier", 1)) <= 1 else 0.75; label = "continental_knockout"
	elif comp_type == "knockout":
		importance = 0.8; label = "domestic_cup"
	elif String(fixture.get("competition_id", "")).begins_with("international"):
		importance = 0.85; label = "international"
	elif String(fixture.get("competition_id", "")).begins_with("world-cup"):
		importance = 1.0; label = "world_cup"
	elif String(fixture.get("competition_id", "")).begins_with("continental-"):
		importance = 0.85; label = "continental_championship"
	return {"importance": importance, "label": label}

func _avg_ca(lineup: Array) -> float:
	if lineup.is_empty(): return 50.0
	var total := 0.0
	for player in lineup: total += float(player.get("current_ability", 50))
	return total / float(lineup.size())

func _avg_morale(lineup: Array) -> float:
	if lineup.is_empty(): return 50.0
	var total := 0.0
	for player in lineup: total += float(player.get("morale", 50))
	return (total / float(lineup.size())) - 50.0

func _form_value(club: Dictionary) -> float:
	# 0-15 recent-points scale mapped to +/-6 strength points.
	if club.has("form_points"): return (clampf(float(club.get("form_points", 7.5)), 0.0, 15.0) - 7.5) * 0.8
	var recent: Array = club.get("recent_results", [])
	if recent.is_empty(): return 0.0
	var points := 0.0
	for r in recent.slice(maxi(0, recent.size() - 5)):
		if String(r) == "W": points += 3.0
		elif String(r) == "D": points += 1.0
	return (points - 7.5) * 0.8

func _home_value(home_club: Dictionary, context: Dictionary) -> float:
	if not bool(context.get("is_home", true)): return 0.0
	var base := 3.0
	var capacity := int(home_club.get("stadium_capacity", 20000))
	base += clampf((float(capacity) - 20000.0) / 40000.0, -1.0, 1.5)
	if bool(context.get("derby", false)): base += 0.5
	return base

func _manager_value(club: Dictionary) -> float:
	var ability := float(club.get("manager_ability", 50))
	if club.has("manager_profile"): ability = float(club.get("manager_profile", {}).get("ability", ability))
	# Staff-backed ability lives on staff records; clubs cache it at world init.
	return (ability - 50.0) * 0.12

func _tactical_edge(home_club: Dictionary, away_club: Dictionary) -> float:
	var home_tactic: Dictionary = home_club.get("tactic", {})
	var away_tactic: Dictionary = away_club.get("tactic", {})
	var home_formation := String(home_tactic.get("formation", "4-3-3"))
	var away_formation := String(away_tactic.get("formation", "4-3-3"))
	var edge := 0.0
	if away_formation in FORMATION_COUNTERS.get(home_formation, []): edge -= 2.5
	if home_formation in FORMATION_COUNTERS.get(away_formation, []): edge += 2.5
	edge += (float(home_tactic.get("familiarity", 50.0)) - float(away_tactic.get("familiarity", 50.0))) * 0.04
	edge += _mentality_edge(String(home_tactic.get("mentality", "balanced")), String(away_tactic.get("mentality", "balanced")))
	return edge

func _mentality_edge(home_mentality: String, away_mentality: String) -> float:
	var order := {"very_cautious": 0, "cautious": 1, "balanced": 2, "positive": 3, "attacking": 4}
	var h := int(order.get(home_mentality, 2))
	var a := int(order.get(away_mentality, 2))
	# Attacking beats cautious, cautious absorbs attacking; balanced is neutral.
	if h == 4 and a <= 1: return 1.2
	if h <= 1 and a == 4: return -1.2
	return float(h - a) * 0.15

func _fitness_value(club: Dictionary, best: Array, ids: Array) -> float:
	var fitness := 0.0
	if not best.is_empty():
		var total := 0.0
		for player in best: total += float(player.get("fitness", 100))
		fitness = (total / float(best.size()) - 85.0) * 0.15
	var available := 0
	for id in ids:
		var player := _player_by_id(best, String(id))
		if player.is_empty(): continue
		if int(player.get("injured_days", 0)) <= 0 and not bool(player.get("retired", false)): available += 1
	# Missing depth hurts: fewer than 18 available is a thin squad.
	var depth := clampf((float(mini(available, 25)) - 18.0) * 0.3, -3.0, 2.0)
	var injured_penalty := 0.0
	if club.has("injured_count"): injured_penalty = -clampf(float(club.get("injured_count", 0)) * 0.25, 0.0, 2.5)
	return fitness + depth + injured_penalty

func _pressure_edge(home_club: Dictionary, away_club: Dictionary, context: Dictionary) -> float:
	var importance := float(context.get("importance", 0.5))
	var home_rep := float(home_club.get("reputation", 50))
	var away_rep := float(away_club.get("reputation", 50))
	# Big occasions slightly favor experienced (high-reputation) sides; the
	# effect is small and symmetric so underdogs still win through quality.
	var experience := (home_rep - away_rep) * 0.03 * importance
	# Home crowd pressure: slight home penalty in the very biggest finals.
	var finals_penalty := 0.0
	if String(context.get("stage", "")) in ["final", "semi_final"] and importance >= 0.9:
		finals_penalty = -0.6
	return experience + finals_penalty

func _club_player_ids(players: Array, club_id: String) -> Array:
	var result: Array = []
	for player in players:
		if String(player.get("club_id", "")) == club_id: result.append(String(player.get("id", "")))
	return result

func _best_eleven(players: Array, club_id: String, _ids: Array) -> Array:
	var squad: Array = []
	for player in players:
		if String(player.get("club_id", "")) != club_id: continue
		if bool(player.get("retired", false)): continue
		if int(player.get("injured_days", 0)) > 0: continue
		squad.append(player)
	squad.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.get("current_ability", 0)) == int(b.get("current_ability", 0)): return String(a.get("id", "")) < String(b.get("id", ""))
		return int(a.get("current_ability", 0)) > int(b.get("current_ability", 0))
	)
	return squad.slice(0, mini(11, squad.size()))

func _player_by_id(lineup: Array, player_id: String) -> Dictionary:
	for player in lineup:
		if String(player.get("id", "")) == player_id: return player
	return {}
