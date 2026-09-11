class_name ContinuousSpatialEngine
extends RefCounted

const SpatialMatchEngineClass = preload("res://simulation/match/spatial_match_engine_v2.gd")
const SpatialStateClass = preload("res://simulation/match/spatial_state.gd")
const TacticalProfileClass = preload("res://simulation/match/tactical_spatial_profile.gd")
const PhysicalModelClass = preload("res://simulation/players/physical_model.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

const DEFAULT_SUBSTEPS := 4
const MIN_ENERGY := 0.35
const PITCH_LENGTH := 105.0
const PITCH_WIDTH := 68.0
const TICK_HZ := 10.0
const BALL_TRAVEL_SPEED := 22.0
const INTERCEPT_RADIUS := 1.6

var _base = SpatialMatchEngineClass.new()

func simulate_segment(home_lineup: Array, away_lineup: Array, seed: int, max_actions: int = 24, starting_side: String = "home", previous_state: Dictionary = {}, substeps: int = DEFAULT_SUBSTEPS) -> Dictionary:
	var base_result: Dictionary = _base.simulate_possession(home_lineup, away_lineup, seed, max_actions, starting_side, previous_state)
	var dense_frames: Array = []
	var energy := _initial_energy(home_lineup, away_lineup, previous_state)
	var previous_frame := _snapshot_from_state(base_result.initial_state)
	var action_index := 0
	for target_frame in base_result.frames:
		var steps := maxi(1, substeps)
		for step in range(1, steps + 1):
			var t := float(step) / float(steps)
			var frame := _interpolate_frame(previous_frame, target_frame, t)
			_update_energy(energy, previous_frame, frame, home_lineup, away_lineup)
			frame["energy"] = energy.duplicate(true)
			frame["action_index"] = action_index
			frame["substep"] = step
			dense_frames.append(frame)
			previous_frame = frame
		action_index += 1
	var final_state: Dictionary = base_result.state.duplicate(true)
	final_state["energy"] = energy.duplicate(true)
	return {"state": final_state,"events": base_result.events,"frames": dense_frames,"action_frames": base_result.frames,"initial_state": base_result.initial_state,"model": "continuous_spatial_2d","substeps": maxi(1, substeps)}

func simulate_continuous(home_lineup: Array, away_lineup: Array, seed: int, home_tactic: Dictionary = {}, away_tactic: Dictionary = {}, ticks: int = 540, previous_state: Dictionary = {}) -> Dictionary:
	var home_profile := TacticalProfileClass.for_tactic(home_tactic if not home_tactic.is_empty() else _default_tactic())
	var away_profile := TacticalProfileClass.for_tactic(away_tactic if not away_tactic.is_empty() else _default_tactic())
	var home_pos := _anchors(home_lineup, true, home_profile)
	var away_pos := _anchors(away_lineup, false, away_profile)
	if previous_state.has("home_positions"):
		for id in home_pos.keys():
			if previous_state["home_positions"].has(id): home_pos[id] = (previous_state["home_positions"][id] as Dictionary).duplicate(true)
	if previous_state.has("away_positions"):
		for id in away_pos.keys():
			if previous_state["away_positions"].has(id): away_pos[id] = (previous_state["away_positions"][id] as Dictionary).duplicate(true)
	var loads := {"home": {}, "away": {}}
	for player in home_lineup: loads["home"][String(player.id)] = PhysicalModelClass.initial_load() if not _has_load(previous_state, "home", String(player.id)) else (previous_state["loads"]["home"][String(player.id)] as Dictionary).duplicate(true)
	for player in away_lineup: loads["away"][String(player.id)] = PhysicalModelClass.initial_load() if not _has_load(previous_state, "away", String(player.id)) else (previous_state["loads"]["away"][String(player.id)] as Dictionary).duplicate(true)
	var ball := {"x": PITCH_LENGTH * 0.5, "y": PITCH_WIDTH * 0.5}
	var ball_target := ball.duplicate(true)
	var ball_owner := {"side": "home", "id": String(home_lineup[mini(6, home_lineup.size() - 1)].id) if not home_lineup.is_empty() else ""}
	var possession := "home"
	var frames: Array = []
	var events: Array = []
	var interceptions := 0
	var shots := 0
	var goals := 0
	var dt := 1.0 / TICK_HZ
	for tick in range(ticks):
		var marking_home := _assignments(away_pos, home_pos)
		var marking_away := _assignments(home_pos, away_pos)
		_move_side(home_lineup, home_pos, away_pos, ball, home_profile, loads["home"], marking_home, possession == "home", dt, tick)
		_move_side(away_lineup, away_pos, home_pos, ball, away_profile, loads["away"], marking_away, possession == "away", dt, tick)
		_move_goalkeeper(home_pos, home_lineup, ball, true)
		_move_goalkeeper(away_pos, away_lineup, ball, false)
		ball = SpatialStateClass.advance(ball, ball_target, BALL_TRAVEL_SPEED * dt)
		var ball_travelling := SpatialStateClass.distance(ball, ball_target) > 2.5
		var owner_pos := _owner_position(ball_owner, home_pos, away_pos, ball)
		var interceptor := {"side": "", "id": ""}
		if ball_travelling and SpatialStateClass.distance(ball, owner_pos) > 2.0: interceptor = _check_interception(ball, home_pos, away_pos, ball_owner)
		if String(interceptor.side) != "" and String(interceptor.side) != ball_owner.side:
			interceptions += 1; possession = String(interceptor.side); ball_owner = interceptor; ball_target = ball.duplicate(true)
			events.append({"type": "interception", "side": interceptor.side, "player_id": interceptor.id, "tick": tick})
		elif SpatialStateClass.distance(ball, ball_target) < 1.2:
			var profile: Dictionary = home_profile if possession == "home" else away_profile
			var interval := maxi(4, int(roundi(float(profile.decision_interval) * TICK_HZ * 0.5)))
			if tick % interval == 0:
				var outcome := _decide_action(ball, ball_owner, possession, home_lineup, away_lineup, home_pos, away_pos, home_profile, away_profile, loads, seed, tick)
				possession = String(outcome.get("possession", possession)); ball_owner = {"side": possession, "id": String(outcome.get("owner_id", ball_owner.id))}; ball_target = (outcome.get("target", ball) as Dictionary).duplicate(true)
				if String(outcome.get("event", "")) != "":
					events.append({"type": outcome.event, "side": possession, "player_id": ball_owner.id, "tick": tick, "xg": outcome.get("xg", 0.0)})
					if outcome.event == "shot": shots += 1
					if outcome.event == "goal": shots += 1; goals += 1
		frames.append({"tick": tick, "ball": ball.duplicate(true), "home": _copy_positions(home_pos), "away": _copy_positions(away_pos), "possession": possession, "loads": _copy_loads(loads)})
	var summary := {"ticks": ticks, "shots": shots, "goals": goals, "interceptions": interceptions, "events": events.size(), "home_distance": _total_distance(loads["home"]), "away_distance": _total_distance(loads["away"])}
	return {"frames": frames, "events": events, "summary": summary, "loads": loads, "final": {"home_positions": home_pos, "away_positions": away_pos, "ball": ball, "possession": possession}, "model": "continuous_10hz"}

func _default_tactic() -> Dictionary:
	return {"formation": "4-3-3", "mentality": "balanced", "tempo": "standard", "pressing": "standard", "familiarity": 50.0, "instructions": {"in_possession": {"width": "standard", "passing_directness": "standard"}, "transition": {}, "out_of_possession": {"defensive_line": "standard", "defensive_width": "standard", "marking": "zonal", "pressing_triggers": "standard"}}}

func _anchors(lineup: Array, home: bool, profile: Dictionary) -> Dictionary:
	var positions := {}; var width: float = profile.width; var line: float = profile.line_height
	for i in range(lineup.size()):
		var id := String(lineup[i].id)
		if i == 0:
			positions[id] = {"x": 3.0 if home else PITCH_LENGTH - 3.0, "y": PITCH_WIDTH * 0.5}; continue
		var row := float((i - 1) % 10) / 9.0; var col := float((i * 37) % 11) / 10.0
		var x := lerpf(12.0, PITCH_LENGTH - 12.0, clampf((row * 0.7 + line * 0.3) if home else 1.0 - (row * 0.7 + line * 0.3), 0.0, 1.0))
		var y := lerpf(PITCH_WIDTH * (0.5 - width * 0.55), PITCH_WIDTH * (0.5 + width * 0.55), col)
		positions[id] = SpatialStateClass.clamp_position({"x": x, "y": y})
	return positions

func _assignments(attackers: Dictionary, defenders: Dictionary) -> Dictionary:
	var result := {}; var used := {}
	for aid in attackers.keys():
		var best := ""; var best_d := INF
		for did in defenders.keys():
			if used.has(did): continue
			var d := SpatialStateClass.distance(attackers[aid], defenders[did])
			if d < best_d: best_d = d; best = did
		if best != "": used[best] = true; result[best] = aid
	return result

func _move_side(lineup: Array, own: Dictionary, opp: Dictionary, ball: Dictionary, profile: Dictionary, loads: Dictionary, marking: Dictionary, in_possession: bool, dt: float, tick: int) -> void:
	var by_id := {}
	for player in lineup: by_id[String(player.id)] = player
	for i in range(lineup.size()):
		var id := String(lineup[i].id)
		if i == 0: continue
		var pos: Dictionary = own[id]; var anchor: Dictionary = _role_anchor(lineup[i], i, profile); var target := anchor.duplicate(true)
		if in_possession:
			target = _blend(target, {"x": float(anchor.x) + (6.0 if _is_home_side(own, pos) else -6.0), "y": anchor.y}, 0.35)
			if marking.has(id): target = _blend(target, ball, 0.15)
		else:
			var ball_d := SpatialStateClass.distance(pos, ball)
			if ball_d < float(profile.press_trigger): target = ball.duplicate(true)
			elif marking.has(id):
				var aid: String = marking[id]; var mark_pos: Dictionary = _opp_position(opp, aid, pos); target = _blend(anchor, mark_pos, 0.55)
			else: target = _blend(anchor, ball, 0.25)
		var energy := PhysicalModelClass.energy_factor(loads.get(id, {"energy": 1.0})); var speed: float = float(profile.closing_speed) * (0.6 + 0.4 * energy) * float(profile.execution); var step := speed * dt
		var before := pos.duplicate(true); var moved: Dictionary = SpatialStateClass.advance(pos, target, step); own[id] = moved; var dist := SpatialStateClass.distance(before, moved)
		var pressing := (not in_possession) and SpatialStateClass.distance(before, ball) < float(profile.press_trigger)
		loads[id] = PhysicalModelClass.update(loads.get(id, PhysicalModelClass.initial_load()), dist, dist / maxf(dt, 0.001), pressing, by_id.get(id, {}), false)

func _move_goalkeeper(positions: Dictionary, lineup: Array, ball: Dictionary, home: bool) -> void:
	if lineup.is_empty(): return
	var id := String(lineup[0].id)
	if not positions.has(id): return
	var gx := 3.0 if home else PITCH_LENGTH - 3.0
	var target := {"x": gx + clampf((float(ball.x) - gx) * 0.12, -4.0, 4.0), "y": lerpf(PITCH_WIDTH * 0.5, float(ball.y), 0.25)}
	positions[id] = SpatialStateClass.advance(positions[id], target, 2.2 * (1.0 / TICK_HZ))

func _check_interception(ball: Dictionary, home_pos: Dictionary, away_pos: Dictionary, owner: Dictionary) -> Dictionary:
	for side in ["home", "away"]:
		if side == String(owner.get("side", "")): continue
		var positions: Dictionary = home_pos if side == "home" else away_pos
		for id in positions.keys():
			if SpatialStateClass.distance(ball, positions[id]) < INTERCEPT_RADIUS: return {"side": side, "id": id}
	return {"side": "", "id": ""}

func _owner_position(owner: Dictionary, home_pos: Dictionary, away_pos: Dictionary, fallback: Dictionary) -> Dictionary:
	var positions: Dictionary = home_pos if String(owner.get("side", "home")) == "home" else away_pos
	return positions.get(String(owner.get("id", "")), fallback)

func _decide_action(ball: Dictionary, owner: Dictionary, possession: String, home_lineup: Array, away_lineup: Array, home_pos: Dictionary, away_pos: Dictionary, home_profile: Dictionary, away_profile: Dictionary, loads: Dictionary, seed: int, tick: int) -> Dictionary:
	var team: Array = home_lineup if possession == "home" else away_lineup; var positions: Dictionary = home_pos if possession == "home" else away_pos; var profile: Dictionary = home_profile if possession == "home" else away_profile
	var goal_x := PITCH_LENGTH if possession == "home" else 0.0; var dist_goal := absf(goal_x - float(ball.x)); var direct: float = profile.directness; var r := SeededRngClass.unit_for(seed, 20000 + tick)
	if dist_goal < 28.0 and r < 0.08:
		var xg := clampf(0.45 - dist_goal / 90.0, 0.03, 0.42) * float(profile.execution); var scored := SeededRngClass.unit_for(seed, 21000 + tick) < xg; var target := {"x": goal_x, "y": PITCH_WIDTH * 0.5}
		return {"possession": possession, "owner_id": owner.id, "target": target, "event": "goal" if scored else "shot", "xg": xg}
	var mates: Array = []
	for player in team:
		if String(player.id) != owner.id: mates.append(player)
	if mates.is_empty(): return {"possession": possession, "owner_id": owner.id, "target": ball, "event": ""}
	var direction := 1.0 if possession == "home" else -1.0
	if r > 0.62:
		var advance := 5.0 + direct * 6.0; var dribble_target := SpatialStateClass.clamp_position({"x": float(ball.x) + direction * advance, "y": clampf(float(ball.y) + (SeededRngClass.unit_for(seed, 23000 + tick) - 0.5) * 8.0, 2.0, PITCH_WIDTH - 2.0)})
		return {"possession": possession, "owner_id": owner.id, "target": dribble_target, "event": ""}
	var best: Dictionary = mates[0]; var best_score := -INF
	for mate in mates:
		var pos: Dictionary = positions.get(String(mate.id), ball); var forward := (float(pos.x) - float(ball.x)) * direction; var score := forward * (0.4 + direct) - SpatialStateClass.distance(ball, pos) * 0.12
		score += (SeededRngClass.unit_for(seed, 22000 + tick + abs(hash(String(mate.id))) % 97) - 0.5) * 2.0
		if score > best_score: best_score = score; best = mate
	return {"possession": possession, "owner_id": String(best.id), "target": (positions.get(String(best.id), ball) as Dictionary).duplicate(true), "event": ""}

func _role_anchor(player: Dictionary, index: int, profile: Dictionary) -> Dictionary:
	var pos_name := String(player.get("position", "MC")); var wide := float(profile.width); var line := float(profile.line_height); var x := lerpf(18.0, PITCH_LENGTH - 18.0, line)
	if pos_name in ["ST", "AMR", "AML", "AMC"]: x += 14.0
	elif pos_name in ["GK"]: x = 4.0
	elif pos_name in ["DC", "DR", "DL"]: x -= 16.0
	var y := PITCH_WIDTH * 0.5
	if pos_name in ["DR", "MR", "AMR", "WBR"]: y = lerpf(PITCH_WIDTH * 0.5, PITCH_WIDTH * (0.5 + wide * 0.6), 0.8)
	elif pos_name in ["DL", "ML", "AML", "WBL"]: y = lerpf(PITCH_WIDTH * 0.5, PITCH_WIDTH * (0.5 - wide * 0.6), 0.8)
	return SpatialStateClass.clamp_position({"x": x, "y": y})

func _blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {"x": lerpf(float(a.x), float(b.x), t), "y": lerpf(float(a.y), float(b.y), t)}
func _is_home_side(own: Dictionary, pos: Dictionary) -> bool:
	return float(pos.get("x", 52.5)) < PITCH_LENGTH * 0.5
func _opp_position(opp: Dictionary, aid: String, fallback: Dictionary) -> Dictionary:
	return opp.get(aid, fallback)
func _copy_positions(positions: Dictionary) -> Dictionary:
	var result := {}
	for id in positions.keys(): result[id] = (positions[id] as Dictionary).duplicate(true)
	return result
func _copy_loads(loads: Dictionary) -> Dictionary:
	var result := {}
	for side in loads.keys():
		result[side] = {}
		for id in (loads[side] as Dictionary).keys(): result[side][id] = ((loads[side] as Dictionary)[id] as Dictionary).duplicate(true)
	return result
func _has_load(state: Dictionary, side: String, id: String) -> bool:
	return state.has("loads") and (state["loads"] as Dictionary).has(side) and ((state["loads"] as Dictionary)[side] as Dictionary).has(id)
func _total_distance(side_loads: Dictionary) -> float:
	var total := 0.0
	for id in side_loads.keys(): total += float((side_loads[id] as Dictionary).get("distance", 0.0))
	return total
func _snapshot_from_state(state: Dictionary) -> Dictionary:
	return {"ball": state.get("ball", {"x": PITCH_LENGTH * 0.5, "y": PITCH_WIDTH * 0.5}).duplicate(true),"home": state.get("home_positions", {}).duplicate(true),"away": state.get("away_positions", {}).duplicate(true)}
func _initial_energy(home: Array, away: Array, previous_state: Dictionary) -> Dictionary:
	if previous_state.has("energy"): return previous_state.energy.duplicate(true)
	var energy := {"home": {}, "away": {}}
	for player in home: energy.home[String(player.id)] = 1.0
	for player in away: energy.away[String(player.id)] = 1.0
	return energy
func _interpolate_frame(previous: Dictionary, target: Dictionary, t: float) -> Dictionary:
	return {"ball": _lerp_position(previous.get("ball", target.ball), target.ball, t),"home": _interpolate_positions(previous.get("home", {}), target.home, t),"away": _interpolate_positions(previous.get("away", {}), target.away, t)}
func _interpolate_positions(previous: Dictionary, target: Dictionary, t: float) -> Dictionary:
	var result := {}
	for id in target.keys():
		var end_pos: Dictionary = target[id]; var start_pos: Dictionary = previous.get(id, end_pos); result[id] = _lerp_position(start_pos, end_pos, t)
	return result
func _lerp_position(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return SpatialStateClass.clamp_position({"x": lerpf(float(a.get("x", 0.0)), float(b.get("x", 0.0)), t),"y": lerpf(float(a.get("y", 0.0)), float(b.get("y", 0.0)), t)})
func _update_energy(energy: Dictionary, previous: Dictionary, frame: Dictionary, home: Array, away: Array) -> void:
	_update_side_energy(energy.home, previous.get("home", {}), frame.home, home); _update_side_energy(energy.away, previous.get("away", {}), frame.away, away)
func _update_side_energy(side_energy: Dictionary, previous_positions: Dictionary, positions: Dictionary, lineup: Array) -> void:
	var players := {}
	for player in lineup: players[String(player.id)] = player
	for id in positions.keys():
		if not side_energy.has(id): side_energy[id] = 1.0
		var before: Dictionary = previous_positions.get(id, positions[id]); var after: Dictionary = positions[id]; var distance := SpatialStateClass.distance(before, after); var player: Dictionary = players.get(id, {}); var stamina := float(player.get("attributes", {}).get("stamina", 50)); var work_rate := float(player.get("attributes", {}).get("work_rate", 50)); var resilience := 0.65 + stamina / 180.0; var effort := 0.00045 + work_rate / 500000.0; var drain := distance * effort / resilience
		side_energy[id] = clampf(float(side_energy[id]) - drain, MIN_ENERGY, 1.0)
func energy_factor(state: Dictionary, side: String, player_id: String) -> float:
	var energy: Dictionary = state.get("energy", {}); var side_energy: Dictionary = energy.get(side, {}); return clampf(float(side_energy.get(player_id, 1.0)), MIN_ENERGY, 1.0)
