class_name SpatialMatchEngineV2
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const SpatialStateClass = preload("res://simulation/match/spatial_state.gd")

const PITCH_LENGTH := 105.0
const PITCH_WIDTH := 68.0

func simulate_possession(home_lineup: Array, away_lineup: Array, seed: int, max_actions: int = 24, starting_side: String = "home", previous_state: Dictionary = {}) -> Dictionary:
	var state := _initial_state(home_lineup, away_lineup, starting_side) if previous_state.is_empty() else previous_state.duplicate(true)
	_sync_players(state, home_lineup, away_lineup)
	var initial: Dictionary = state.duplicate(true)
	var events: Array = []
	var frames: Array = []
	for action_index in range(max_actions):
		var side := String(state.possession_side)
		var team: Array = home_lineup if side == "home" else away_lineup
		var opponents: Array = away_lineup if side == "home" else home_lineup
		if team.is_empty() or opponents.is_empty(): break
		var actor: Dictionary = _player_by_id(team, String(state.ball_owner_id))
		if actor.is_empty():
			actor = team[int(SeededRngClass.value_for(seed, 1000 + action_index) % team.size())]
			state.ball_owner_id = String(actor.id)
		var positions: Dictionary = state.home_positions if side == "home" else state.away_positions
		state.ball = positions.get(String(actor.id), state.ball).duplicate(true)
		var action := _choose_action(actor, state, seed, action_index)
		var event := _resolve_action(actor, team, opponents, action, state, seed, action_index)
		events.append(event); _apply_event(state, event, team, opponents, seed, action_index)
		frames.append({"ball":state.ball.duplicate(true),"home":state.home_positions.duplicate(true),"away":state.away_positions.duplicate(true)})
		if String(event.get("type", "")) == "shot" or not bool(event.get("success", true)): break
	return {"state":state,"events":events,"frames":frames,"initial_state":initial}

func _sync_players(state: Dictionary, home: Array, away: Array) -> void:
	for side in ["home", "away"]:
		var team: Array = home if side == "home" else away
		var positions: Dictionary = state.home_positions if side == "home" else state.away_positions
		var defaults := _shape(team, side == "home")
		for id in positions.keys():
			if not defaults.has(id): positions.erase(id)
		for id in defaults:
			if not positions.has(id): positions[id] = defaults[id]
		if String(state.possession_side) == side and not positions.has(String(state.ball_owner_id)) and not team.is_empty():
			state.ball_owner_id = String(team[0].id); state.ball = positions[state.ball_owner_id].duplicate(true)

func _initial_state(home_lineup: Array, away_lineup: Array, starting_side: String) -> Dictionary:
	var home_positions: Dictionary = _shape(home_lineup, true); var away_positions: Dictionary = _shape(away_lineup, false)
	var starting_team: Array = home_lineup if starting_side == "home" else away_lineup; var owner := ""
	if not starting_team.is_empty(): owner = String(starting_team[mini(6, starting_team.size() - 1)].id)
	var positions := home_positions if starting_side == "home" else away_positions
	return {"ball":positions.get(owner, {"x":PITCH_LENGTH*0.5,"y":PITCH_WIDTH*0.5}).duplicate(true),"ball_owner_id":owner,"possession_side":starting_side,"home_positions":home_positions,"away_positions":away_positions}

func _shape(lineup: Array, home: bool) -> Dictionary:
	var positions := {}
	for i in range(lineup.size()):
		var row: int = i / 4; var col: int = i % 4; var x := 7.0 + float(row) * 19.0
		if i == 0: x = 4.0
		if not home: x = PITCH_LENGTH - x
		positions[String(lineup[i].id)] = {"x":x,"y":clampf(8.0 + float(col) * 16.0, 2.0, PITCH_WIDTH - 2.0)}
	return positions

func _choose_action(actor: Dictionary, state: Dictionary, seed: int, index: int) -> String:
	# Full action vocabulary with softmax sampling. Utilities combine effective
	# ability, spatial opportunity, tactical context, traits and hidden
	# temperament so identical seeds still reproduce identical matches.
	var attack_direction := 1.0 if String(state.possession_side) == "home" else -1.0
	var goal_x := PITCH_LENGTH if attack_direction > 0 else 0.0
	var ball: Dictionary = state.ball
	var distance_to_goal := absf(goal_x - float(ball.x))
	var wide := absf(float(ball.y) - PITCH_WIDTH * 0.5) / (PITCH_WIDTH * 0.5)
	var pressure := _pressure(state, String(state.possession_side), ball)
	var tactic: Dictionary = state.get("tactic_" + String(state.possession_side), {})
	var instructions: Dictionary = tactic.get("instructions", {}).get("in_possession", {}) if tactic.has("instructions") else {}
	var mentality := String(tactic.get("mentality", "balanced"))
	var attrs: Dictionary = actor.get("attributes", {})
	var hidden: Dictionary = actor.get("hidden_attributes", {})
	var traits: Array = actor.get("traits", [])
	var match_importance := float(state.get("match_importance", 0.5))
	var finishing := _effective(actor, "finishing", attrs)
	var passing := _effective(actor, "passing", attrs)
	var technique := _effective(actor, "technique", attrs)
	var dribbling := _effective(actor, "dribbling", attrs)
	var crossing := _effective(actor, "crossing", attrs)
	var decisions := _effective(actor, "decisions", attrs)
	var composure := _effective(actor, "composure", attrs)
	var vision := _effective(actor, "vision", attrs)
	var teamwork := _effective(actor, "teamwork", attrs)
	var pace := _effective(actor, "pace", attrs)
	# Hidden temperament: big-match players keep composure when importance is
	# high; low-pressure players discount risky options under pressure.
	var big_matches := float(hidden.get("big_matches", 50)) / 100.0
	var pressure_attr := float(hidden.get("pressure", 50)) / 100.0
	var consistency := float(hidden.get("consistency", 50)) / 100.0
	var composure_adj := composure * lerpf(0.86, 1.08, pressure_attr) * lerpf(0.94, 1.06, big_matches * match_importance + (1.0 - match_importance) * 0.5)
	var risk_appetite := 0.5 + (decisions - 50.0) / 220.0 + (composure_adj - 50.0) / 260.0
	if mentality in ["attacking", "positive"]:
		risk_appetite += 0.08
	elif mentality in ["cautious", "very_cautious"]:
		risk_appetite -= 0.08
	if String(instructions.get("passing_directness", "standard")) == "more_direct":
		risk_appetite += 0.05
	elif String(instructions.get("passing_directness", "standard")) == "shorter":
		risk_appetite -= 0.05
	# Spatial opportunity.
	var in_final_third := (attack_direction > 0 and float(ball.x) > PITCH_LENGTH * 0.66) or (attack_direction < 0 and float(ball.x) < PITCH_LENGTH * 0.34)
	var in_box := (attack_direction > 0 and float(ball.x) > PITCH_LENGTH * 0.83 and wide < 0.55) or (attack_direction < 0 and float(ball.x) < PITCH_LENGTH * 0.17 and wide < 0.55)
	var wide_area := wide > 0.62 and in_final_third
	var deep := (attack_direction > 0 and float(ball.x) < PITCH_LENGTH * 0.30) or (attack_direction < 0 and float(ball.x) > PITCH_LENGTH * 0.70)
	var shoot_utility := 96.0 - distance_to_goal * 1.18 - pressure * 30.0 + finishing * 0.34 + composure_adj * 0.10
	if in_box:
		shoot_utility += 16.0
	elif not in_final_third:
		shoot_utility -= 26.0
	if String(instructions.get("shoot_on_sight", false)) == "true" or bool(instructions.get("shoot_on_sight", false)):
		shoot_utility += 6.0
	if bool(instructions.get("work_ball_into_box", false)):
		shoot_utility -= 7.0
	var through_utility := 40.0 - pressure * 14.0 + passing * 0.30 + vision * 0.22 + decisions * 0.10 - distance_to_goal * 0.12 + risk_appetite * 10.0
	if not in_final_third:
		through_utility -= 10.0
	var cross_utility := -20.0 + crossing * 0.42 + technique * 0.12 + teamwork * 0.08 - pressure * 12.0
	if wide_area:
		cross_utility += 34.0
	else:
		cross_utility -= 18.0
	if String(instructions.get("crossing", "mixed")) == "early":
		cross_utility += 4.0
	var pass_utility := 46.0 - pressure * 8.0 + passing * 0.36 + decisions * 0.12 + teamwork * 0.06
	var recycle_utility := 38.0 - pressure * 4.0 + decisions * 0.16 + teamwork * 0.12 + composure_adj * 0.06
	if pressure > 0.65:
		recycle_utility += 8.0
	var dribble_utility := 34.0 - pressure * 18.0 + dribbling * 0.32 + pace * 0.08 + decisions * 0.08
	var clear_utility := 6.0 + pressure * 26.0 - composure_adj * 0.10 - decisions * 0.06
	if deep and pressure > 0.55:
		clear_utility += 16.0
	else:
		clear_utility -= 12.0
	# Trait weight shifts (decision weights, never flat bonuses).
	if "tries_long_shots" in traits or "shoots_from_distance" in traits:
		shoot_utility += 7.0
	if "plays_through_balls" in traits or "tries_killer_balls" in traits or "plays_one_twos" in traits:
		through_utility += 7.0
	if "whips_crosses" in traits or "overlaps" in traits or "hugs_touchline" in traits:
		cross_utility += 6.0
	if "cuts_inside" in traits and wide_area:
		dribble_utility += 5.0
		cross_utility -= 4.0
	if "stays_wide" in traits and wide_area:
		cross_utility += 4.0
	if "runs_with_ball" in traits:
		dribble_utility += 5.0
	if "dictates_tempo" in traits or "sprays_passes" in traits:
		recycle_utility += 4.0
		pass_utility += 2.0
	if "holds_up_ball" in traits or "poacher" in traits:
		recycle_utility -= 2.0
	if "beats_offside_trap" in traits and in_final_third:
		through_utility += 3.0
	if "dives_into_tackles" in traits:
		clear_utility += 2.0
	# Consistency narrows noise for reliable players; volatile players vary.
	var noise_scale := lerpf(14.0, 7.0, consistency)
	var utilities := {
		"shot": shoot_utility, "through_ball": through_utility, "cross": cross_utility,
		"pass": pass_utility, "recycle": recycle_utility, "dribble": dribble_utility, "clear": clear_utility,
	}
	# Softmax sampling with deterministic draw: best action is likely but not
	# guaranteed, which preserves variation without pure randomness.
	var temperature := 9.0
	var weights := {}
	var total := 0.0
	for key in utilities.keys():
		var noisy: float = float(utilities[key]) + (SeededRngClass.unit_for(seed, 5000 + index * 13 + _stable_key(key) % 97) - 0.5) * noise_scale
		var w := exp(noisy / temperature)
		weights[key] = w
		total += w
	var roll := SeededRngClass.unit_for(seed, 5100 + index) * total
	var accumulator := 0.0
	for key in ["shot", "through_ball", "cross", "pass", "recycle", "dribble", "clear"]:
		accumulator += float(weights[key])
		if roll <= accumulator:
			return key
	return "pass"

func _resolve_action(actor: Dictionary, team: Array, opponents: Array, action: String, state: Dictionary, seed: int, index: int) -> Dictionary:
	var side := String(state.possession_side); var pressure := _pressure(state, side, state.ball); var attrs: Dictionary = actor.get("attributes", {})
	var weather: Dictionary = state.get("weather", {"pass_factor": 1.0, "touch_factor": 1.0, "shot_factor": 1.0})
	if action == "shot":
		var goal := {"x":PITCH_LENGTH if side == "home" else 0.0,"y":PITCH_WIDTH*0.5}; var distance := SpatialStateClass.distance(state.ball, goal); var angle_factor := 1.0 - minf(0.55, absf(float(state.ball.y) - PITCH_WIDTH*0.5) / PITCH_WIDTH)
		var finishing := _effective(actor, "finishing", attrs); var composure := _effective(actor, "composure", attrs); var technique := _effective(actor, "technique", attrs)
		var xg := clampf((0.62 - distance / 120.0) * angle_factor - pressure * 0.16, 0.015, 0.62) * float(weather.get("shot_factor", 1.0))
		# Finishing executes chances; it never invents xG from 35m.
		var execution := clampf(0.75 + (finishing + composure - 100.0) / 350.0, 0.55, 1.25) * _condition_factor(actor) * (0.94 + technique / 900.0)
		var keeper_decision := _goalkeeper_decision(opponents, state.ball, xg, seed, index)
		if keeper_decision in ["close_angle", "rush_out"]:
			execution *= 0.92
		var scored := SeededRngClass.unit_for(seed, 6000 + index) < clampf(xg * execution, 0.01, 0.85); var on_target := scored or SeededRngClass.unit_for(seed, 6100 + index) < clampf(0.35 + finishing / 250.0 - pressure * 0.12, 0.2, 0.8)
		return {"type":"shot","player_id":String(actor.id),"side":side,"outcome":"goal" if scored else ("saved" if on_target else "missed"),"success":scored,"xg":xg,"position":state.ball.duplicate(true),"pressure":pressure,"goalkeeper_action":keeper_decision,"body_part":_shot_body_part(actor, seed, index)}
	if action == "through_ball":
		var receiver: Dictionary = _best_receiver(actor, team, state, side, seed, index, true)
		if receiver.is_empty(): return {"type":"pass","player_id":String(actor.id),"side":side,"success":false,"outcome":"no_target","position":state.ball.duplicate(true),"pressure":pressure}
		var positions: Dictionary = state.home_positions if side == "home" else state.away_positions; var target_position: Dictionary = positions[String(receiver.id)]; var distance := SpatialStateClass.distance(state.ball, target_position)
		var passing := _effective(actor, "passing", attrs); var vision := _effective(actor, "vision", attrs); var technique := _effective(actor, "technique", attrs)
		var chance := clampf(0.44 + passing / 340.0 + vision / 420.0 + technique / 700.0 - distance / 150.0 - pressure * 0.24, 0.12, 0.92) * float(weather.get("pass_factor", 1.0)) * _condition_factor(actor)
		var success := SeededRngClass.unit_for(seed, 7300 + index) < chance
		var outcome := "complete" if success else ("offside" if SeededRngClass.unit_for(seed, 7310 + index) < 0.12 else "intercepted")
		return {"type":"through_ball","player_id":String(actor.id),"receiver_id":String(receiver.id),"side":side,"success":success,"outcome":outcome,"from":state.ball.duplicate(true),"to":target_position.duplicate(true),"distance":distance,"pressure":pressure,"risk":0.85}
	if action == "cross":
		var receiver: Dictionary = _best_receiver(actor, team, state, side, seed, index, false)
		if receiver.is_empty(): return {"type":"cross","player_id":String(actor.id),"side":side,"success":false,"outcome":"no_target","position":state.ball.duplicate(true),"pressure":pressure}
		var positions: Dictionary = state.home_positions if side == "home" else state.away_positions; var target_position: Dictionary = positions[String(receiver.id)]; var distance := SpatialStateClass.distance(state.ball, target_position)
		var crossing := _effective(actor, "crossing", attrs); var technique := _effective(actor, "technique", attrs)
		var chance := clampf(0.40 + crossing / 300.0 + technique / 600.0 - distance / 170.0 - pressure * 0.20, 0.10, 0.90) * float(weather.get("pass_factor", 1.0)) * _condition_factor(actor)
		var success := SeededRngClass.unit_for(seed, 7400 + index) < chance
		return {"type":"cross","player_id":String(actor.id),"receiver_id":String(receiver.id),"side":side,"success":success,"outcome":"complete" if success else "cleared","from":state.ball.duplicate(true),"to":target_position.duplicate(true),"distance":distance,"pressure":pressure,"cross":true}
	if action == "recycle":
		var receiver: Dictionary = _safest_receiver(actor, team, state, side, seed, index)
		if receiver.is_empty(): return {"type":"pass","player_id":String(actor.id),"side":side,"success":true,"outcome":"recycle","position":state.ball.duplicate(true),"pressure":pressure,"action":"recycle"}
		var positions: Dictionary = state.home_positions if side == "home" else state.away_positions; var target_position: Dictionary = positions[String(receiver.id)]; var distance := SpatialStateClass.distance(state.ball, target_position)
		var passing := _effective(actor, "passing", attrs); var decisions := _effective(actor, "decisions", attrs)
		var chance := clampf(0.72 + passing / 500.0 + decisions / 600.0 - distance / 260.0 - pressure * 0.08, 0.35, 0.985) * float(weather.get("pass_factor", 1.0))
		var success := SeededRngClass.unit_for(seed, 7500 + index) < chance
		return {"type":"pass","player_id":String(actor.id),"receiver_id":String(receiver.id),"side":side,"success":success,"outcome":"complete" if success else "intercepted","action":"recycle","from":state.ball.duplicate(true),"to":target_position.duplicate(true),"distance":distance,"pressure":pressure}
	if action == "clear":
		var direction := 1.0 if side == "away" else -1.0
		var target := SpatialStateClass.clamp_position({"x":float(state.ball.x) + direction * (18.0 + SeededRngClass.unit_for(seed, 7600 + index) * 14.0),"y":PITCH_WIDTH * 0.5 + (SeededRngClass.unit_for(seed, 7601 + index) - 0.5) * 30.0})
		return {"type":"clearance","player_id":String(actor.id),"side":side,"success":true,"outcome":"cleared","from":state.ball.duplicate(true),"to":target,"pressure":pressure,"action":"clear"}
	if action == "pass":
		var receiver: Dictionary = _best_receiver(actor, team, state, side, seed, index)
		if receiver.is_empty(): return {"type":"pass","player_id":String(actor.id),"side":side,"success":false,"outcome":"no_target","position":state.ball.duplicate(true),"pressure":pressure}
		var positions: Dictionary = state.home_positions if side == "home" else state.away_positions; var target_position: Dictionary = positions[String(receiver.id)]; var distance := SpatialStateClass.distance(state.ball, target_position); var passing := _effective(actor, "passing", attrs); var technique := _effective(actor, "technique", attrs); var receiver_pressure := _pressure(state, side, target_position); var success_chance := clampf(0.58 + passing / 300.0 + technique / 500.0 - distance / 180.0 - pressure * 0.18 - receiver_pressure * 0.10, 0.18, 0.96) * float(weather.get("pass_factor", 1.0)); var success := SeededRngClass.unit_for(seed, 7000 + index) < success_chance * _condition_factor(actor)
		# Receiver control failure is distinct from pass failure.
		if success:
			var first_touch := _effective(receiver, "first_touch", receiver.get("attributes", {}))
			var touch_chance := clampf(0.66 + first_touch / 320.0 - receiver_pressure * 0.10, 0.40, 0.985) * float(weather.get("touch_factor", 1.0))
			if SeededRngClass.unit_for(seed, 7050 + index) >= touch_chance * _condition_factor(receiver):
				return {"type":"pass","player_id":String(actor.id),"receiver_id":String(receiver.id),"side":side,"success":false,"outcome":"poor_first_touch","from":state.ball.duplicate(true),"to":target_position.duplicate(true),"distance":distance,"pressure":pressure}
		return {"type":"pass","player_id":String(actor.id),"receiver_id":String(receiver.id),"side":side,"success":success,"outcome":"complete" if success else "intercepted","from":state.ball.duplicate(true),"to":target_position.duplicate(true),"distance":distance,"pressure":pressure}
	var direction := 1.0 if side == "home" else -1.0; var target := SpatialStateClass.clamp_position({"x":float(state.ball.x)+direction*6.0,"y":float(state.ball.y)+(SeededRngClass.unit_for(seed, 8100+index)-0.5)*5.0}); var dribbling := _effective(actor, "dribbling", attrs); var chance := clampf(0.48 + dribbling / 260.0 - pressure * 0.42, 0.08, 0.9); var retained := SeededRngClass.unit_for(seed, 8000 + index) < chance * _condition_factor(actor)
	return {"type":"dribble","player_id":String(actor.id),"side":side,"success":retained,"outcome":"retained" if retained else "tackled","from":state.ball.duplicate(true),"to":target,"pressure":pressure}

func _fitness_factor(player: Dictionary) -> float: return _condition_factor(player)
func _condition_factor(player: Dictionary) -> float:
	# Effective-condition model: fitness matters most, fatigue/morale/
	# confidence/familiarity stay subtle per design (morale 0.94-1.04 etc).
	var fitness := clampf(float(player.get("fitness", 100)) / 100.0, 0.0, 1.0)
	var fatigue := clampf(float(player.get("fatigue", 0)) / 100.0, 0.0, 1.0)
	var morale := clampf(float(player.get("morale", 50)) / 100.0, 0.0, 1.0)
	var confidence := clampf(float(player.get("confidence", 50)) / 100.0, 0.0, 1.0)
	var familiarity := clampf(float(player.get("tactical_familiarity", 50)) / 100.0, 0.0, 1.0)
	var fitness_mod := lerpf(0.65, 1.0, fitness)
	var fatigue_mod := lerpf(1.0, 0.82, fatigue)
	var morale_mod := lerpf(0.94, 1.04, morale)
	var confidence_mod := lerpf(0.96, 1.03, confidence)
	var familiarity_mod := lerpf(0.94, 1.02, familiarity)
	return fitness_mod * fatigue_mod * morale_mod * confidence_mod * familiarity_mod
func _effective(player: Dictionary, attr_name: String, attrs: Dictionary) -> float:
	var raw := float(attrs.get(attr_name, player.get("current_ability", 50)))
	if raw <= 20.0:
		raw *= 5.0
	return raw * _condition_factor(player)
func _goalkeeper_decision(opponents: Array, ball: Dictionary, xg: float, seed: int, index: int) -> String:
	var keeper := {}
	for player in opponents:
		if String(player.get("position", "")) == "GK":
			keeper = player
			break
	if keeper.is_empty():
		return "set_position"
	var attrs: Dictionary = keeper.get("attributes", {})
	var rushing := float(attrs.get("rushing_out", 50 if float(attrs.get("rushing_out", 50)) <= 20.0 else float(attrs.get("rushing_out", 50)) / 5.0))
	# Normalize 1-20 displays to 1-100 scale when needed.
	if rushing <= 20.0:
		rushing *= 5.0
	var role := String(keeper.get("role", keeper.get("match_role", ""))).to_lower()
	var dist := absf(float(ball.x) - (4.0 if float(ball.x) < 52.5 else 101.0))
	var roll := SeededRngClass.unit_for(seed, 6200 + index)
	if xg >= 0.30:
		return "close_angle"
	if dist < 22.0 and (rushing > 62.0 or role == "sweeper_keeper") and roll < 0.45:
		return "rush_out"
	if bool(ball.get("cross_origin", false)):
		return "claim_cross" if rushing > 55.0 else "punch_cross"
	if xg >= 0.15 and roll < 0.30:
		return "sweep_out" if role == "sweeper_keeper" else "hold_line"
	return "set_position"
func _shot_body_part(actor: Dictionary, seed: int, index: int) -> String:
	var foot := String(actor.get("preferred_foot", "right"))
	var roll := SeededRngClass.unit_for(seed, 6300 + index)
	var heading := float(actor.get("attributes", {}).get("heading", 50))
	if roll < clampf((heading - 45.0) / 220.0, 0.04, 0.22):
		return "head"
	if foot == "both":
		return "right_foot" if roll < 0.55 else "left_foot"
	if String(actor.get("traits", []).has("avoids_weak_foot")):
		return foot + "_foot"
	return foot + "_foot" if roll < 0.82 else ("left_foot" if foot == "right" else "right_foot")
func _best_receiver(actor: Dictionary, team: Array, state: Dictionary, side: String, seed: int, index: int, through_bias: bool = false) -> Dictionary:
	var positions: Dictionary = state.home_positions if side == "home" else state.away_positions; var direction := 1.0 if side == "home" else -1.0; var actor_pos: Dictionary = positions.get(String(actor.id), state.ball); var best: Dictionary = {}; var best_score := -INF
	for candidate in team:
		if String(candidate.id) == String(actor.id): continue
		var pos: Dictionary = positions.get(String(candidate.id), actor_pos); var forward := (float(pos.x)-float(actor_pos.x))*direction; var distance := SpatialStateClass.distance(actor_pos, pos); var pressure := _pressure(state, side, pos)
		var score := forward * (1.15 if through_bias else 0.8) - distance * (0.22 if through_bias else 0.15) - pressure * 12.0 + float(candidate.get("current_ability", 50)) * 0.08
		if through_bias and "beats_offside_trap" in candidate.get("traits", []):
			score += 3.0
		score += (SeededRngClass.unit_for(seed, 7200 + index * 31 + _stable_key(String(candidate.id)) % 29) - 0.5) * 2.0
		if score > best_score: best_score = score; best = candidate
	return best
func _safest_receiver(actor: Dictionary, team: Array, state: Dictionary, side: String, seed: int, index: int) -> Dictionary:
	var positions: Dictionary = state.home_positions if side == "home" else state.away_positions; var direction := 1.0 if side == "home" else -1.0; var actor_pos: Dictionary = positions.get(String(actor.id), state.ball); var best: Dictionary = {}; var best_score := -INF
	for candidate in team:
		if String(candidate.id) == String(actor.id): continue
		var pos: Dictionary = positions.get(String(candidate.id), actor_pos); var backward := (float(actor_pos.x) - float(pos.x)) * direction; var distance := SpatialStateClass.distance(actor_pos, pos); var pressure := _pressure(state, side, pos)
		var score := backward * 0.6 - distance * 0.30 - pressure * 16.0 + float(candidate.get("current_ability", 50)) * 0.05
		score += (SeededRngClass.unit_for(seed, 7550 + index * 17 + _stable_key(String(candidate.id)) % 23) - 0.5) * 1.5
		if score > best_score: best_score = score; best = candidate
	return best
func _apply_event(state: Dictionary, event: Dictionary, team: Array, opponents: Array, seed: int, index: int) -> void:
	var side := String(state.possession_side); var own_positions: Dictionary = state.home_positions if side == "home" else state.away_positions
	if String(event.type) in ["pass", "through_ball", "cross"] and bool(event.success): state.ball_owner_id = String(event.receiver_id); state.ball = event.to.duplicate(true); _shift_shape(state, side, 1.8 if String(event.type) == "through_ball" else 1.5); return
	if String(event.type) == "pass" and String(event.get("action", "")) == "recycle" and bool(event.success): state.ball_owner_id = String(event.receiver_id); state.ball = event.to.duplicate(true); _shift_shape(state, side, 0.6); return
	if String(event.type) == "dribble" and bool(event.success): state.ball = event.to.duplicate(true); own_positions[String(event.player_id)] = event.to.duplicate(true); _shift_shape(state, side, 1.0); return
	if String(event.type) == "clearance": _turnover(state, opponents, seed, index); return
	if String(event.type) == "shot": state.ball_owner_id = ""; return
	_turnover(state, opponents, seed, index)
func _turnover(state: Dictionary, opponents: Array, seed: int, index: int) -> void:
	state.possession_side = "away" if String(state.possession_side) == "home" else "home"
	if opponents.is_empty(): state.ball_owner_id = ""; return
	var new_positions: Dictionary = state.home_positions if String(state.possession_side) == "home" else state.away_positions; var nearest := SpatialStateClass.nearest(state.ball, new_positions); state.ball_owner_id = String(nearest.id) if String(nearest.id) != "" else String(opponents[int(SeededRngClass.value_for(seed, 9000+index)%opponents.size())].id)
func _shift_shape(state: Dictionary, side: String, metres: float) -> void:
	var positions: Dictionary = state.home_positions if side == "home" else state.away_positions; var direction := 1.0 if side == "home" else -1.0
	for id in positions.keys(): var p: Dictionary = positions[id]; p.x = clampf(float(p.x)+direction*metres, 0.0, PITCH_LENGTH)
func _pressure(state: Dictionary, attacking_side: String, position: Dictionary) -> float:
	var defenders: Dictionary = state.away_positions if attacking_side == "home" else state.home_positions; var total := 0.0
	for p in defenders.values(): var d := SpatialStateClass.distance(p, position); total += maxf(0.0, 12.0 - d) / 12.0
	return clampf(total / 3.0, 0.0, 1.0)
func _player_by_id(team: Array, player_id: String) -> Dictionary:
	for player in team:
		if String(player.id) == player_id: return player
	return {}
func _stable_key(text: String) -> int:
	var value := 67
	for character in text.to_utf8_buffer(): value = posmod(value * 167 + int(character), 2_147_483_647)
	return value
