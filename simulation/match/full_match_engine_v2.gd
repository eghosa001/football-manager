class_name FullMatchEngineV2
extends RefCounted

const PossessionEngineClass = preload("res://simulation/match/spatial_match_engine_v2.gd")
const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const MatchFactorsClass = preload("res://simulation/match/match_factors.gd")

var _possession = PossessionEngineClass.new()
var _tactics = TacticsManagerClass.new()

func simulate_match(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int, context: Dictionary = {}) -> Dictionary:
	var home_tactic: Dictionary = home_club.get("tactic", _tactics.create_tactic("4-3-3"))
	var away_tactic: Dictionary = away_club.get("tactic", _tactics.create_tactic("4-3-3"))
	var home: Array = _tactics.select_lineup(players, String(home_club.id), home_tactic).duplicate(true)
	var away: Array = _tactics.select_lineup(players, String(away_club.id), away_tactic).duplicate(true)
	var travel_fatigue := clampf(float(context.get("travel_fatigue", 0.0)), 0.0, 0.38)
	if travel_fatigue > 0.0:
		for player in away:
			player["fitness"] = clampi(int(player.get("fitness", 100)) - int(round(travel_fatigue * 22.0)), 25, 100)
	if home.size() < 11 or away.size() < 11:
		return {"error": ERR_UNAVAILABLE, "home_goals": 0, "away_goals": 0, "events": [], "stats": {}}
	var starters := {"home": _ids(home), "away": _ids(away)}
	var participants: Dictionary = starters.duplicate(true)
	var planned := _planned_substitutions(players, String(home_club.id), String(away_club.id), home, away)
	var substitutions: Array = []
	var cautions: Dictionary = {}
	var home_mod: Dictionary = _tactics.style_modifiers(home_tactic)
	var away_mod: Dictionary = _tactics.style_modifiers(away_tactic)
	var factor_edge := float(MatchFactorsClass.new().breakdown(home_club, away_club, players, context).total_home_edge)
	var importance := float(context.get("importance", 0.5))
	var weather := {"kind": "clear", "pass_factor": 1.0, "touch_factor": 1.0, "stamina_factor": 1.0, "shot_factor": 1.0, "attendance_factor": 1.0}
	var weather_roll := SeededRngClass.unit_for(seed, 91001)
	if weather_roll < 0.12:
		weather = {"kind": "heavy_rain", "pass_factor": 0.90, "touch_factor": 0.86, "stamina_factor": 0.92, "shot_factor": 0.94, "attendance_factor": 0.88}
	elif weather_roll < 0.30:
		weather = {"kind": "rain", "pass_factor": 0.95, "touch_factor": 0.93, "stamina_factor": 0.96, "shot_factor": 0.97, "attendance_factor": 0.94}
	elif weather_roll > 0.92:
		weather = {"kind": "hot", "pass_factor": 0.99, "touch_factor": 0.98, "stamina_factor": 0.88, "shot_factor": 0.98, "attendance_factor": 0.96}
	var events: Array = []
	var possession_counts := {"home": 0, "away": 0}
	var frames: Array = []
	var carry: Dictionary = {}
	for possession_index in range(54):
		var minute := mini(90, int(floor(float(possession_index) * 90.0 / 54.0)))
		for substitution in planned:
			if bool(substitution.get("applied", false)) or int(substitution.minute) > minute: continue
			substitution["applied"] = true
			var lineup: Array = home if String(substitution.side) == "home" else away
			for player_index in range(lineup.size()):
				if String(lineup[player_index].id) != String(substitution.player_out): continue
				for player in players:
					if String(player.id) != String(substitution.player_in): continue
					lineup[player_index] = player.duplicate(true)
					if not carry.is_empty():
						var positions: Dictionary = carry.home_positions if String(substitution.side) == "home" else carry.away_positions
						if positions.has(String(substitution.player_out)):
							positions[String(player.id)] = positions[String(substitution.player_out)]
							positions.erase(String(substitution.player_out))
						if String(carry.ball_owner_id) == String(substitution.player_out): carry.ball_owner_id = String(player.id)
					var event: Dictionary = substitution.duplicate(true)
					event.erase("applied")
					event.minute = minute
					events.append(event)
					substitutions.append(event)
					participants[String(event.side)].append(String(player.id))
					break
				break
		var home_share := _possession_share(home, away, home_mod, away_mod, factor_edge)
		var starting_side := "home" if SeededRngClass.unit_for(seed, 31_000 + possession_index) < home_share else "away"
		if not carry.is_empty(): starting_side = String(carry.possession_side)
		possession_counts[starting_side] += 1
		var sequence_factor := float(home_mod.sequence_multiplier) if starting_side == "home" else float(away_mod.sequence_multiplier)
		var max_actions := clampi(int(round(18.0 * sequence_factor)), 14, 22)
		carry["tactic_home"] = home_tactic
		carry["tactic_away"] = away_tactic
		carry["weather"] = weather
		carry["match_importance"] = importance
		var possession: Dictionary = _possession.simulate_possession(home, away, seed + possession_index * 7919, max_actions, starting_side, carry)
		for frame_index in range(possession.frames.size()):
			var frame: Dictionary = possession.frames[frame_index]
			frame["minute"] = float(possession_index) * 90.0 / 54.0 + float(frame_index) * 90.0 / 54.0 / maxf(1.0, float(possession.frames.size()))
			frames.append(frame)
		for event in possession.events:
			var copy: Dictionary = event.duplicate(true)
			copy["minute"] = minute
			_enrich_shot(copy, home, away, possession.state)
			events.append(copy)
		_maybe_set_piece(events, home, away, possession.state, starting_side, minute, seed, possession_index)
		var before_card := events.size()
		_maybe_card(events, home, away, starting_side, minute, seed, possession_index, home_mod, away_mod)
		if events.size() > before_card:
			var card: Dictionary = events.back()
			var player_id := String(card.player_id)
			if String(card.card) == "yellow":
				cautions[player_id] = int(cautions.get(player_id, 0)) + 1
				if int(cautions[player_id]) >= 2:
					card.card = "red"
					card["second_yellow"] = true
			if String(card.card) == "red":
				var lineup: Array = home if String(card.side) == "home" else away
				for player_index in range(lineup.size() - 1, -1, -1):
					if String(lineup[player_index].id) == player_id: lineup.remove_at(player_index)
				var positions: Dictionary = possession.state.home_positions if String(card.side) == "home" else possession.state.away_positions
				positions.erase(player_id)
		carry = possession.state
		if String(carry.ball_owner_id).is_empty():
			var next_side := "away" if starting_side == "home" else "home"
			carry = _possession._initial_state(home, away, next_side)
		for team in [home, away]:
			for player in team:
				var stamina := float(player.get("attributes", {}).get("stamina", 50))
				player.fitness = maxf(25.0, float(player.get("fitness", 100)) - (0.55 - stamina * 0.003))
	# Preserve causal ordering within each minute: substitutions precede play,
	# and cards follow the possession that caused them.
	var stats := {"home":_blank_stats(),"away":_blank_stats()}
	var goals := {"home":0,"away":0}
	for event in events: _accumulate_event(stats, goals, event)
	stats.home.xg = snappedf(float(stats.home.xg), 0.01); stats.away.xg = snappedf(float(stats.away.xg), 0.01)
	var total_possessions := maxi(1, int(possession_counts.home) + int(possession_counts.away))
	stats.home.possession = snappedf(float(possession_counts.home) / total_possessions * 100.0, 0.1)
	stats.away.possession = snappedf(100.0 - float(stats.home.possession), 0.1)
	var factors := MatchFactorsClass.new().breakdown(home_club, away_club, players, context)
	return {
		"home_goals": int(goals.home), "away_goals": int(goals.away), "events": events, "stats": stats,
		"lineups": starters, "participants": participants, "final_lineups": {"home": _ids(home), "away": _ids(away)}, "substitutions": substitutions,
		"spatial": {"pitch_length": 105.0, "pitch_width": 68.0, "frames": frames, "model": "persistent_action_2d"},
		"tactics": {"home": home_tactic.duplicate(true), "away": away_tactic.duplicate(true)}, "seed": seed,
		"factors": factors, "match_context": context, "weather": weather, "importance": importance
	}

func apply_to_fixture(fixture: Dictionary, result: Dictionary) -> void:
	if result.has("error"): return
	fixture.played = true; fixture.home_goals = int(result.home_goals); fixture.away_goals = int(result.away_goals)

func _possession_share(home: Array, away: Array, home_mod: Dictionary, away_mod: Dictionary, factor_edge: float = 0.0) -> float:
	var hs := _strength(home); var as_ := _strength(away)
	var base := 0.5 + (hs - as_ + factor_edge) / 240.0 + 0.025 + float(home_mod.get("possession", 0.0)) - float(away_mod.get("possession", 0.0))
	return clampf(base, 0.30, 0.70)

func _maybe_set_piece(events: Array, home: Array, away: Array, state: Dictionary, attacking_side: String, minute: int, seed: int, index: int) -> void:
	if SeededRngClass.unit_for(seed, 40_000 + index) >= 0.145: return
	var team := home if attacking_side == "home" else away
	var defending := away if attacking_side == "home" else home
	if team.is_empty(): return
	var roll := SeededRngClass.unit_for(seed, 41_000 + index)
	var set_type := "corner"
	if roll < 0.48:
		set_type = "corner"
	elif roll < 0.78:
		set_type = "free_kick"
	elif roll < 0.90:
		set_type = "throw_in"
	else:
		set_type = "penalty"
	var taker: Dictionary = _best_set_piece_taker_for_kind(team, set_type)
	var targets := _aerial_targets(team, taker)
	var marker := _best_aerial_defender(defending)
	var routines := {"corner": ["near_post", "far_post", "edge_of_box", "short_corner"], "free_kick": ["direct", "delivery_far", "delivery_near", "layoff"], "throw_in": ["long_throw", "retain_possession", "flick_on"], "penalty": ["placed", "power"]}
	var routine_roll := SeededRngClass.unit_for(seed, 41_500 + index)
	var options: Array = routines[set_type]
	var routine: String = options[mini(options.size() - 1, int(floor(routine_roll * float(options.size()))))]
	var marking := "zonal_plus_man" if not marker.is_empty() else "zonal"
	events.append({"minute": minute, "type": set_type, "side": attacking_side, "player_id": String(taker.id), "success": true, "routine": routine, "primary_target_id": String(targets[0].id) if not targets.is_empty() else "", "marker_id": String(marker.id) if not marker.is_empty() else "", "marking": marking, "zone": routine})
	if set_type == "throw_in":
		return
	var base_chance := 0.28 if set_type == "corner" else (0.78 if set_type == "penalty" else 0.22)
	if SeededRngClass.unit_for(seed, 42_000 + index) < base_chance:
		var shooter := _best_shooter(team) if not targets.is_empty() else taker
		if set_type == "penalty":
			shooter = _best_penalty_taker(team)
		var xg := 0.08 + SeededRngClass.unit_for(seed, 43_000 + index) * 0.12
		if set_type == "penalty":
			xg = 0.76
		elif set_type == "free_kick" and routine == "direct":
			xg = 0.06 + SeededRngClass.unit_for(seed, 43_000 + index) * 0.08
		var scored := SeededRngClass.unit_for(seed, 44_000 + index) < xg * (0.75 + float(shooter.get("current_ability", 50)) / 250.0)
		var on_target := scored or SeededRngClass.unit_for(seed, 45_000 + index) < (0.85 if set_type == "penalty" else 0.42)
		var shot := {"minute": minute, "type": "shot", "side": attacking_side, "player_id": String(shooter.id), "outcome": "goal" if scored else ("saved" if on_target else "missed"), "success": scored, "xg": xg, "set_piece": set_type, "position": {"x": 90.0 if attacking_side == "home" else 15.0, "y": 34.0}, "pressure": 0.15 if set_type == "penalty" else 0.35}
		_enrich_shot(shot, home, away, state)
		events.append(shot)

func _maybe_card(events: Array, home: Array, away: Array, attacking_side: String, minute: int, seed: int, index: int, home_mod: Dictionary, away_mod: Dictionary) -> void:
	var defending_side := "away" if attacking_side == "home" else "home"
	var defenders := away if defending_side == "away" else home
	if defenders.is_empty(): return
	var mod := away_mod if defending_side == "away" else home_mod
	var chance := clampf(0.018 + float(mod.get("card",0.0)),0.008,0.045)
	if SeededRngClass.unit_for(seed, 46_000 + index) >= chance: return
	var player: Dictionary = defenders[int(SeededRngClass.value_for(seed,46_500+index)%defenders.size())]
	var red := SeededRngClass.unit_for(seed, 47_000 + index) < 0.035
	events.append({"minute":minute,"type":"card","side":defending_side,"player_id":String(player.id),"card":"red" if red else "yellow"})

func _enrich_shot(event: Dictionary, home: Array, away: Array, state: Dictionary) -> void:
	if String(event.get("type", "")) != "shot": return
	var defending := away if String(event.get("side", "home")) == "home" else home
	var keeper := _goalkeeper(defending)
	if not keeper.is_empty():
		event["goalkeeper_id"] = String(keeper.id)
		var positions: Dictionary = state.away_positions if String(event.get("side","home")) == "home" else state.home_positions
		event["goalkeeper_position"] = positions.get(String(keeper.id), {"x":102.0 if String(event.get("side","home"))=="home" else 3.0,"y":34.0}).duplicate(true)

func _planned_substitutions(players: Array, home_id: String, away_id: String, home: Array, away: Array) -> Array:
	var result: Array = []
	_add_subs(result,"home",_bench(players,home_id,home),home)
	_add_subs(result,"away",_bench(players,away_id,away),away)
	return result

func _add_subs(result: Array, side: String, bench: Array, lineup: Array) -> void:
	for i in range(mini(3,bench.size())):
		result.append({"minute":62+i*10,"type":"substitution","side":side,"player_out":String(lineup[lineup.size()-1-i].id),"player_in":String(bench[i].id),"success":true})

func _bench(players: Array, club_id: String, lineup: Array) -> Array:
	var ids := {}; for player in lineup: ids[String(player.id)] = true
	var bench: Array = []
	for player in players:
		if String(player.get("club_id","")) == club_id and not bool(player.get("retired",false)) and not ids.has(String(player.id)): bench.append(player)
	bench.sort_custom(func(a: Dictionary,b: Dictionary):
		if int(a.get("current_ability",0)) == int(b.get("current_ability",0)): return String(a.id)<String(b.id)
		return int(a.get("current_ability",0))>int(b.get("current_ability",0))
	)
	return bench

func _accumulate_event(stats: Dictionary, goals: Dictionary, event: Dictionary) -> void:
	var side := String(event.get("side", "home"))
	if not stats.has(side): return
	match String(event.get("type", "")):
		"pass": stats[side].passes += 1; stats[side].passes_completed += 1 if bool(event.get("success", false)) else 0; stats[side].progressive_passes += 1 if bool(event.get("success", false)) and float(event.get("distance", 0.0)) >= 10.0 and String(event.get("action", "")) != "recycle" else 0
		"through_ball": stats[side].passes += 1; stats[side].through_balls += 1; stats[side].passes_completed += 1 if bool(event.get("success", false)) else 0; stats[side].progressive_passes += 1 if bool(event.get("success", false)) else 0; stats[side].key_passes += 1 if bool(event.get("success", false)) else 0
		"cross": stats[side].passes += 1; stats[side].crosses += 1; stats[side].passes_completed += 1 if bool(event.get("success", false)) else 0
		"clearance": stats[side].clearances += 1
		"dribble": stats[side].dribbles += 1; stats[side].dribbles_completed += 1 if bool(event.get("success", false)) else 0
		"corner": stats[side].corners += 1
		"free_kick": stats[side].free_kicks += 1
		"throw_in": stats[side].throw_ins += 1
		"penalty": stats[side].penalties += 1
		"card":
			stats[side].cards += 1
			if String(event.get("card","")) == "red": stats[side].red_cards += 1
		"shot":
			stats[side].shots += 1; stats[side].xg += float(event.get("xg",0.0))
			if String(event.get("outcome","")) in ["goal","saved"]: stats[side].shots_on_target += 1
			if String(event.get("outcome","")) == "goal": stats[side].goals += 1; goals[side] += 1
			elif String(event.get("outcome","")) == "saved":
				var opponent := "away" if side == "home" else "home"; stats[opponent].saves += 1

func _best_set_piece_taker(team: Array) -> Dictionary:
	return _best_set_piece_taker_for_kind(team, "corner")

func _best_set_piece_taker_for_kind(team: Array, kind: String) -> Dictionary:
	var best: Dictionary = team[0]
	for player in team:
		var a: Dictionary = player.get("attributes", {}); var b: Dictionary = best.get("attributes", {})
		var score := _set_piece_score(a, player, kind)
		var best_score := _set_piece_score(b, best, kind)
		if score > best_score: best = player
	return best

func _set_piece_score(a: Dictionary, player: Dictionary, kind: String) -> int:
	match kind:
		"penalty":
			return int(a.get("penalties", a.get("finishing", player.get("current_ability", 50))))
		"free_kick":
			return int(a.get("free_kicks", a.get("technique", player.get("current_ability", 50))))
		"throw_in":
			return int(a.get("long_throws", a.get("strength", player.get("current_ability", 50))))
		_:
			return int(a.get("corners", a.get("crossing", player.get("current_ability", 50))))

func _best_penalty_taker(team: Array) -> Dictionary:
	return _best_set_piece_taker_for_kind(team, "penalty")

func _aerial_targets(team: Array, taker: Dictionary) -> Array:
	var rows: Array = []
	for player in team:
		if String(player.get("id", "")) == String(taker.get("id", "")):
			continue
		rows.append(player)
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return _aerial_score(a) > _aerial_score(b))
	return rows.slice(0, mini(3, rows.size()))

func _aerial_score(player: Dictionary) -> float:
	var a: Dictionary = player.get("attributes", {})
	return float(a.get("heading", 50)) * 0.45 + float(a.get("jumping", a.get("jumping_reach", 50))) * 0.30 + float(a.get("strength", 50)) * 0.15 + float(player.get("height_cm", 180)) * 0.02

func _best_aerial_defender(team: Array) -> Dictionary:
	var targets := _aerial_targets(team, {})
	return targets[0] if not targets.is_empty() else {}

func _best_shooter(team: Array) -> Dictionary:
	var best: Dictionary = team[0]
	for player in team:
		if int(player.get("attributes",{}).get("finishing",player.get("current_ability",50))) > int(best.get("attributes",{}).get("finishing",best.get("current_ability",50))): best = player
	return best

func _goalkeeper(team: Array) -> Dictionary:
	for player in team:
		if String(player.get("position","")) == "GK": return player
	return team[0] if not team.is_empty() else {}

func _strength(team: Array) -> float:
	var total := 0.0
	for player in team: total += float(player.get("current_ability",50))*float(player.get("fitness",100))/100.0
	# Missing players reduce team strength rather than improving an average.
	return total/11.0

func _blank_stats() -> Dictionary:
	return {"passes": 0, "passes_completed": 0, "progressive_passes": 0, "through_balls": 0, "key_passes": 0, "crosses": 0, "clearances": 0, "dribbles": 0, "dribbles_completed": 0, "shots": 0, "shots_on_target": 0, "goals": 0, "xg": 0.0, "possession": 0.0, "corners": 0, "free_kicks": 0, "throw_ins": 0, "penalties": 0, "cards": 0, "red_cards": 0, "saves": 0}

func _ids(players: Array) -> Array:
	var ids: Array = []
	for player in players: ids.append(String(player.id))
	return ids
