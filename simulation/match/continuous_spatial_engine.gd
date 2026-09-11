class_name ContinuousSpatialEngine
extends RefCounted

const SpatialMatchEngineClass = preload("res://simulation/match/spatial_match_engine_v2.gd")
const SpatialStateClass = preload("res://simulation/match/spatial_state.gd")

const DEFAULT_SUBSTEPS := 4
const MIN_ENERGY := 0.35
const PITCH_LENGTH := 105.0
const PITCH_WIDTH := 68.0

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
	return {
		"state": final_state,
		"events": base_result.events,
		"frames": dense_frames,
		"action_frames": base_result.frames,
		"initial_state": base_result.initial_state,
		"model": "continuous_spatial_2d",
		"substeps": maxi(1, substeps)
	}

func _snapshot_from_state(state: Dictionary) -> Dictionary:
	return {
		"ball": state.get("ball", {"x": PITCH_LENGTH * 0.5, "y": PITCH_WIDTH * 0.5}).duplicate(true),
		"home": state.get("home_positions", {}).duplicate(true),
		"away": state.get("away_positions", {}).duplicate(true)
	}

func _initial_energy(home: Array, away: Array, previous_state: Dictionary) -> Dictionary:
	if previous_state.has("energy"):
		return previous_state.energy.duplicate(true)
	var energy := {"home": {}, "away": {}}
	for player in home:
		energy.home[String(player.id)] = 1.0
	for player in away:
		energy.away[String(player.id)] = 1.0
	return energy

func _interpolate_frame(previous: Dictionary, target: Dictionary, t: float) -> Dictionary:
	return {
		"ball": _lerp_position(previous.get("ball", target.ball), target.ball, t),
		"home": _interpolate_positions(previous.get("home", {}), target.home, t),
		"away": _interpolate_positions(previous.get("away", {}), target.away, t)
	}

func _interpolate_positions(previous: Dictionary, target: Dictionary, t: float) -> Dictionary:
	var result := {}
	for id in target.keys():
		var end_pos: Dictionary = target[id]
		var start_pos: Dictionary = previous.get(id, end_pos)
		result[id] = _lerp_position(start_pos, end_pos, t)
	return result

func _lerp_position(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return SpatialStateClass.clamp_position({
		"x": lerpf(float(a.get("x", 0.0)), float(b.get("x", 0.0)), t),
		"y": lerpf(float(a.get("y", 0.0)), float(b.get("y", 0.0)), t)
	})

func _update_energy(energy: Dictionary, previous: Dictionary, frame: Dictionary, home: Array, away: Array) -> void:
	_update_side_energy(energy.home, previous.get("home", {}), frame.home, home)
	_update_side_energy(energy.away, previous.get("away", {}), frame.away, away)

func _update_side_energy(side_energy: Dictionary, previous_positions: Dictionary, positions: Dictionary, lineup: Array) -> void:
	var players := {}
	for player in lineup:
		players[String(player.id)] = player
	for id in positions.keys():
		if not side_energy.has(id): side_energy[id] = 1.0
		var before: Dictionary = previous_positions.get(id, positions[id])
		var after: Dictionary = positions[id]
		var distance := SpatialStateClass.distance(before, after)
		var player: Dictionary = players.get(id, {})
		var stamina := float(player.get("attributes", {}).get("stamina", 50))
		var work_rate := float(player.get("attributes", {}).get("work_rate", 50))
		var resilience := 0.65 + stamina / 180.0
		var effort := 0.00045 + work_rate / 500000.0
		var drain := distance * effort / resilience
		side_energy[id] = clampf(float(side_energy[id]) - drain, MIN_ENERGY, 1.0)

func energy_factor(state: Dictionary, side: String, player_id: String) -> float:
	var energy: Dictionary = state.get("energy", {})
	var side_energy: Dictionary = energy.get(side, {})
	return clampf(float(side_energy.get(player_id, 1.0)), MIN_ENERGY, 1.0)
