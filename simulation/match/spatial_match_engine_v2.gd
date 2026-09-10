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
		if team.is_empty() or opponents.is_empty():
			break
		var actor: Dictionary = _player_by_id(team, String(state.ball_owner_id))
		if actor.is_empty():
			actor = team[int(SeededRngClass.value_for(seed, 1000 + action_index) % team.size())]
			state.ball_owner_id = String(actor.id)
		var positions: Dictionary = state.home_positions if side == "home" else state.away_positions
		state.ball = positions.get(String(actor.id), state.ball).duplicate(true)
		var action := _choose_action(actor, state, seed, action_index)
		var event := _resolve_action(actor, team, opponents, action, state, seed, action_index)
		events.append(event)
		_apply_event(state, event, team, opponents, seed, action_index)
		frames.append({"ball":state.ball.duplicate(true),"home":state.home_positions.duplicate(true),"away":state.away_positions.duplicate(true)})
		if String(event.get("type", "")) == "shot" or not bool(event.get("success", true)):
			break
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
			state.ball_owner_id = String(team[0].id)
			state.ball = positions[state.ball_owner_id].duplicate(true)

func _initial_state(home_lineup: Array, away_lineup: Array, starting_side: String) -> Dictionary:
	var home_positions: Dictionary = _shape(home_lineup, true)
	var away_positions: Dictionary = _shape(away_lineup, false)
	var starting_team: Array = home_lineup if starting_side == "home" else away_lineup
	var owner := ""
	if not starting_team.is_empty():
		var index := mini(6, starting_team.size() - 1)
		owner = String(starting_team[index].id)
	var positions := home_positions if starting_side == "home" else away_positions
	return {"ball":positions.get(owner, {"x":PITCH_LENGTH*0.5,"y":PITCH_WIDTH*0.5}).duplicate(true),"ball_owner_id":owner,"possession_side":starting_side,"home_positions":home_positions,"away_positions":away_positions}

func _shape(lineup: Array, home: bool) -> Dictionary:
	var positions := {}
	for i in range(lineup.size()):
		var row: int = i / 4
		var col: int = i % 4
		var x := 7.0 + float(row) * 19.0
		if i == 0: x = 4.0
		if not home: x = PITCH_LENGTH - x
		positions[String(lineup[i].id)] = {"x":x,"y":clampf(8.0 + float(col) * 16.0, 2.0, PITCH_WIDTH - 2.0)}
	return positions

func _choose_action(actor: Dictionary, state: Dictionary, seed: int, index: int) -> String:
	var attack_direction := 1.0 if String(state.possession_side) == "home" else -1.0
	var goal_x := PITCH_LENGTH if attack_direction > 0 else 0.0
	var distance_to_goal := absf(goal_x - float(state.ball.x))
	var pressure := _pressure(state, String(state.possession_side), state.ball)
	var attrs: Dictionary = actor.get("attributes", {})
	var finishing := float(attrs.get("finishing", actor.get("current_ability", 50)))
	var passing := float(attrs.get("passing", actor.get("current_ability", 50)))
	var dribbling := float(attrs.get("dribbling", attrs.get("pace", actor.get("current_ability", 50))))
	var decisions := float(attrs.get("decisions", actor.get("current_ability", 50)))
	var shoot_utility := 92.0 - distance_to_goal * 1.15 - pressure * 30.0 + finishing * 0.32
	var pass_utility := 44.0 - pressure * 8.0 + passing * 0.38 + decisions * 0.12
	var dribble_utility := 34.0 - pressure * 18.0 + dribbling * 0.32 + decisions * 0.08
	var noise := (SeededRngClass.unit_for(seed, 5000 + index) - 0.5) * 10.0
	shoot_utility += noise
	if shoot_utility >= pass_utility and shoot_utility >= dribble_utility:
		return "shot"
	return "pass" if pass_utility >= dribble_utility else "dribble"

func _resolve_action(actor: Dictionary, team: Array, opponents: Array, action: String, state: Dictionary, seed: int, index: int) -> Dictionary:
	var side := String(state.possession_side)
	var pressure := _pressure(state, side, state.ball)
	var attrs: Dictionary = actor.get("attributes", {})
	if action == "shot":
		var goal := {"x":PITCH_LENGTH if side == "home" else 0.0,"y":PITCH_WIDTH*0.5}
		var distance := SpatialStateClass.distance(state.ball, goal)
		var angle_factor := 1.0 - minf(0.55, absf(float(state.ball.y) - PITCH_WIDTH*0.5) / PITCH_WIDTH)
		var finishing := float(attrs.get("finishing", actor.get("current_ability", 50)))
		var composure := float(attrs.get("composure", attrs.get("decisions", actor.get("current_ability", 50))))
		var xg := clampf((0.62 - distance / 120.0) * angle_factor - pressure * 0.16, 0.015, 0.62)
		var execution := clampf(0.75 + (finishing + composure - 100.0) / 350.0, 0.55, 1.25) * _fitness_factor(actor)
		var scored := SeededRngClass.unit_for(seed, 6000 + index) < clampf(xg * execution, 0.01, 0.85)
		var on_target := scored or SeededRngClass.unit_for(seed, 6100 + index) < clampf(0.35 + finishing / 250.0 - pressure * 0.12, 0.2, 0.8)
		return {"type":"shot","player_id":String(actor.id),"side":side,"outcome":"goal" if scored else ("saved" if on_target else "missed"),"success":scored,"xg":xg,"position":state.ball.duplicate(true),"pressure":pressure}
	if action == "pass":
		var receiver: Dictionary = _best_receiver(actor, team, state, side, seed, index)
		if receiver.is_empty():
			return {"type":"pass","player_id":String(actor.id),"side":side,"success":false,"outcome":"no_target","position":state.ball.duplicate(true),"pressure":pressure}
		var positions: Dictionary = state.home_positions if side == "home" else state.away_positions
		var target_position: Dictionary = positions[String(receiver.id)]
		var distance := SpatialStateClass.distance(state.ball, target_position)
		var passing := float(attrs.get("passing", actor.get("current_ability", 50)))
		var technique := float(attrs.get("technique", actor.get("current_ability", 50)))
		var receiver_pressure := _pressure(state, side, target_position)
		var success_chance := clampf(0.58 + passing / 300.0 + technique / 500.0 - distance / 180.0 - pressure * 0.18 - receiver_pressure * 0.10, 0.18, 0.96)
		var success := SeededRngClass.unit_for(seed, 7000 + index) < success_chance * _fitness_factor(actor)
		return {"type":"pass","player_id":String(actor.id),"receiver_id":String(receiver.id),"side":side,"success":success,"outcome":"complete" if success else "intercepted","from":state.ball.duplicate(true),"to":target_position.duplicate(true),"distance":distance,"pressure":pressure}
	var direction := 1.0 if side == "home" else -1.0
	var target := SpatialStateClass.clamp_position({"x":float(state.ball.x)+direction*6.0,"y":float(state.ball.y)+(SeededRngClass.unit_for(seed, 8100+index)-0.5)*5.0})
	var dribbling := float(attrs.get("dribbling", attrs.get("pace", actor.get("current_ability", 50))))
	var chance := clampf(0.48 + dribbling / 260.0 - pressure * 0.42, 0.08, 0.9)
	var retained := SeededRngClass.unit_for(seed, 8000 + index) < chance * _fitness_factor(actor)
	return {"type":"dribble","player_id":String(actor.id),"side":side,"success":retained,"outcome":"retained" if retained else "tackled","from":state.ball.duplicate(true),"to":target,"pressure":pressure}

func _fitness_factor(player: Dictionary) -> float:
	return 0.65 + 0.35 * clampf(float(player.get("fitness", 100)) / 100.0, 0.0, 1.0)

func _best_receiver(actor: Dictionary, team: Array, state: Dictionary, side: String, seed: int, index: int) -> Dictionary:
	var positions: Dictionary = state.home_positions if side == "home" else state.away_positions
	var direction := 1.0 if side == "home" else -1.0
	var actor_pos: Dictionary = positions.get(String(actor.id), state.ball)
	var best: Dictionary = {}
	var best_score := -INF
	for candidate in team:
		if String(candidate.id) == String(actor.id): continue
		var pos: Dictionary = positions.get(String(candidate.id), actor_pos)
		var forward := (float(pos.x)-float(actor_pos.x))*direction
		var distance := SpatialStateClass.distance(actor_pos, pos)
		var pressure := _pressure(state, side, pos)
		var score := forward*0.8 - distance*0.15 - pressure*12.0 + float(candidate.get("current_ability",50))*0.08
		score += (SeededRngClass.unit_for(seed, 7200 + index*31 + _stable_key(String(candidate.id)) % 29)-0.5)*2.0
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _apply_event(state: Dictionary, event: Dictionary, team: Array, opponents: Array, seed: int, index: int) -> void:
	var side := String(state.possession_side)
	var own_positions: Dictionary = state.home_positions if side == "home" else state.away_positions
	if String(event.type) == "pass" and bool(event.success):
		state.ball_owner_id = String(event.receiver_id)
		state.ball = event.to.duplicate(true)
		_shift_shape(state, side, 1.5)
		return
	if String(event.type) == "dribble" and bool(event.success):
		state.ball = event.to.duplicate(true)
		own_positions[String(event.player_id)] = event.to.duplicate(true)
		_shift_shape(state, side, 1.0)
		return
	if String(event.type) == "shot":
		state.ball_owner_id = ""
		return
	_turnover(state, opponents, seed, index)

func _turnover(state: Dictionary, opponents: Array, seed: int, index: int) -> void:
	state.possession_side = "away" if String(state.possession_side) == "home" else "home"
	if opponents.is_empty():
		state.ball_owner_id = ""
		return
	var new_positions: Dictionary = state.home_positions if String(state.possession_side) == "home" else state.away_positions
	var nearest := SpatialStateClass.nearest(state.ball, new_positions)
	state.ball_owner_id = String(nearest.id) if String(nearest.id) != "" else String(opponents[int(SeededRngClass.value_for(seed, 9000+index)%opponents.size())].id)

func _shift_shape(state: Dictionary, side: String, metres: float) -> void:
	var positions: Dictionary = state.home_positions if side == "home" else state.away_positions
	var direction := 1.0 if side == "home" else -1.0
	for id in positions.keys():
		var p: Dictionary = positions[id]
		p.x = clampf(float(p.x)+direction*metres, 0.0, PITCH_LENGTH)

func _pressure(state: Dictionary, attacking_side: String, position: Dictionary) -> float:
	var defenders: Dictionary = state.away_positions if attacking_side == "home" else state.home_positions
	var total := 0.0
	for p in defenders.values():
		var d := SpatialStateClass.distance(p, position)
		total += maxf(0.0, 12.0 - d) / 12.0
	return clampf(total / 3.0, 0.0, 1.0)

func _player_by_id(team: Array, player_id: String) -> Dictionary:
	for player in team:
		if String(player.id) == player_id: return player
	return {}

func _stable_key(text: String) -> int:
	var value := 67
	for character in text.to_utf8_buffer(): value = posmod(value * 167 + int(character), 2_147_483_647)
	return value
