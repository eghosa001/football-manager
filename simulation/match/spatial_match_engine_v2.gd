class_name SpatialMatchEngineV2
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

const PITCH_LENGTH := 105.0
const PITCH_WIDTH := 68.0

func simulate_possession(home_lineup: Array, away_lineup: Array, seed: int, max_actions: int = 24) -> Dictionary:
	var state := _initial_state(home_lineup, away_lineup)
	var events: Array = []
	for action_index in range(max_actions):
		var side := String(state.possession_side)
		var team: Array = home_lineup if side == "home" else away_lineup
		var opponents: Array = away_lineup if side == "home" else home_lineup
		if team.is_empty():
			break
		var actor: Dictionary = team[int(SeededRngClass.value_for(seed, 1000 + action_index) % team.size())]
		var action := _choose_action(actor, state, opponents, seed, action_index)
		var event := _resolve_action(actor, action, state, opponents, seed, action_index)
		events.append(event)
		_apply_event(state, event)
		if String(event.type) in ["goal", "turnover", "out"]:
			break
	return {"state":state, "events":events}

func _initial_state(home_lineup: Array, away_lineup: Array) -> Dictionary:
	return {"ball":{"x":PITCH_LENGTH * 0.5,"y":PITCH_WIDTH * 0.5}, "possession_side":"home", "home_positions":_shape(home_lineup, true), "away_positions":_shape(away_lineup, false)}

func _shape(lineup: Array, home: bool) -> Dictionary:
	var positions := {}
	for i in range(lineup.size()):
		var row := i / 4
		var col := i % 4
		var x := 7.0 + row * 19.0
		if not home:
			x = PITCH_LENGTH - x
		positions[String(lineup[i].id)] = {"x":x,"y":8.0 + col * 16.0}
	return positions

func _choose_action(actor: Dictionary, state: Dictionary, opponents: Array, seed: int, index: int) -> String:
	var attack_direction := 1.0 if String(state.possession_side) == "home" else -1.0
	var distance_to_goal := absf((PITCH_LENGTH if attack_direction > 0 else 0.0) - float(state.ball.x))
	var pressure := _pressure(state, String(state.possession_side), state.ball)
	var shoot_utility := 100.0 - distance_to_goal - pressure * 35.0 + float(actor.get("attributes", {}).get("finishing", actor.get("current_ability", 50))) * 0.25
	var pass_utility := 45.0 - pressure * 10.0 + float(actor.get("attributes", {}).get("passing", actor.get("current_ability", 50))) * 0.4
	var dribble_utility := 35.0 - pressure * 20.0 + float(actor.get("attributes", {}).get("pace", actor.get("current_ability", 50))) * 0.35
	var noise := (SeededRngClass.unit_for(seed, 5000 + index) - 0.5) * 12.0
	shoot_utility += noise
	if shoot_utility >= pass_utility and shoot_utility >= dribble_utility:
		return "shot"
	return "pass" if pass_utility >= dribble_utility else "dribble"

func _resolve_action(actor: Dictionary, action: String, state: Dictionary, opponents: Array, seed: int, index: int) -> Dictionary:
	var pressure := _pressure(state, String(state.possession_side), state.ball)
	if action == "shot":
		var goal_x := PITCH_LENGTH if String(state.possession_side) == "home" else 0.0
		var distance := absf(goal_x - float(state.ball.x))
		var xg := clampf(0.55 - distance / 120.0 - pressure * 0.18, 0.02, 0.55)
		var scored := SeededRngClass.unit_for(seed, 6000 + index) < xg
		return {"type":"goal" if scored else "shot", "player_id":String(actor.id), "side":String(state.possession_side), "xg":xg, "position":state.ball.duplicate(true)}
	if action == "pass":
		var success := SeededRngClass.unit_for(seed, 7000 + index) > pressure * 0.55
		return {"type":"pass" if success else "turnover", "player_id":String(actor.id), "side":String(state.possession_side), "success":success, "pressure":pressure, "position":state.ball.duplicate(true)}
	var retained := SeededRngClass.unit_for(seed, 8000 + index) > pressure * 0.65
	return {"type":"dribble" if retained else "turnover", "player_id":String(actor.id), "side":String(state.possession_side), "success":retained, "pressure":pressure, "position":state.ball.duplicate(true)}

func _apply_event(state: Dictionary, event: Dictionary) -> void:
	if String(event.type) == "turnover":
		state.possession_side = "away" if String(state.possession_side) == "home" else "home"
		return
	var direction := 1.0 if String(state.possession_side) == "home" else -1.0
	state.ball.x = clampf(float(state.ball.x) + direction * 7.0, 0.0, PITCH_LENGTH)

func _pressure(state: Dictionary, attacking_side: String, position: Dictionary) -> float:
	var defenders: Dictionary = state.away_positions if attacking_side == "home" else state.home_positions
	var total := 0.0
	for p in defenders.values():
		var dx := float(p.x) - float(position.x)
		var dy := float(p.y) - float(position.y)
		var d := sqrt(dx * dx + dy * dy)
		total += maxf(0.0, 12.0 - d) / 12.0
	return clampf(total / 3.0, 0.0, 1.0)
