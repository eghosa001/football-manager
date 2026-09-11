class_name ContinuousSpatialEngine
extends RefCounted

const SpatialMatchEngineClass = preload("res://simulation/match/spatial_match_engine_v2.gd")
const SpatialStateClass = preload("res://simulation/match/spatial_state.gd")

const DEFAULT_SUBSTEPS := 4
const MIN_ENERGY := 0.35
const PITCH_LENGTH := 105.0
const PITCH_WIDTH := 68.0

var _base = SpatialMatchEngineClass.new()

func simulate_segment(home_lineup: Array, away_lineup: Array, seed: int, max_actions: int = 24, starting_side: String = "home", previous_state: Dictionary = {}, substeps: int = DEFAULT_SUBSTEPS, home_tactic: Dictionary = {}, away_tactic: Dictionary = {}) -> Dictionary:
	var base_result: Dictionary = _base.simulate_possession(home_lineup, away_lineup, seed, max_actions, starting_side, previous_state)
	var dense_frames: Array = []
	var energy := _initial_energy(home_lineup, away_lineup, previous_state)
	var previous_frame := _snapshot_from_state(base_result.initial_state)
	var action_index := 0
	for target_frame in base_result.frames:
		var steps := maxi(1, substeps)
		for step in range(1, steps + 1):
			var remaining_steps := maxi(1, steps - step + 1)
			var frame := _advance_frame(previous_frame, target_frame, energy, home_lineup, away_lineup, home_tactic, away_tactic, String(base_result.state.get("possession_side", starting_side)), remaining_steps)
			_update_energy(energy, previous_frame, frame, home_lineup, away_lineup)
			frame["energy"] = energy.duplicate(true)
			frame["action_index"] = action_index
			frame["substep"] = step
			dense_frames.append(frame)
			previous_frame = frame
		action_index += 1
	var final_state: Dictionary = base_result.state.duplicate(true)
	final_state["energy"] = energy.duplicate(true)
	if not dense_frames.is_empty():
		final_state["home_positions"] = dense_frames[-1].home.duplicate(true)
		final_state["away_positions"] = dense_frames[-1].away.duplicate(true)
		final_state["ball"] = dense_frames[-1].ball.duplicate(true)
	return {
		"state": final_state,
		"events": base_result.events,
		"frames": dense_frames,
		"action_frames": base_result.frames,
		"initial_state": base_result.initial_state,
		"model": "continuous_spatial_2d",
		"substeps": maxi(1, substeps),
		"tactical_motion": not home_tactic.is_empty() or not away_tactic.is_empty()
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

func _advance_frame(previous: Dictionary, target: Dictionary, energy: Dictionary, home: Array, away: Array, home_tactic: Dictionary, away_tactic: Dictionary, possession_side: String, remaining_steps: int) -> Dictionary:
	var ball_target: Dictionary = target.get("ball", previous.get("ball", {"x": PITCH_LENGTH * 0.5, "y": PITCH_WIDTH * 0.5}))
	return {
		"ball": _step_towards(previous.get("ball", ball_target), ball_target, 1000.0 / float(remaining_steps)),
		"home": _advance_positions(previous.get("home", {}), target.get("home", {}), energy.get("home", {}), home, home_tactic, true, possession_side == "home", ball_target, remaining_steps),
		"away": _advance_positions(previous.get("away", {}), target.get("away", {}), energy.get("away", {}), away, away_tactic, false, possession_side == "away", ball_target, remaining_steps)
	}

func _advance_positions(previous: Dictionary, target: Dictionary, side_energy: Dictionary, lineup: Array, tactic: Dictionary, is_home: bool, in_possession: bool, ball: Dictionary, remaining_steps: int) -> Dictionary:
	var players := {}
	for player in lineup:
		players[String(player.id)] = player
	var result := {}
	for id in target.keys():
		var end_pos: Dictionary = _tactical_target(target[id], ball, tactic, is_home, in_possession)
		var start_pos: Dictionary = previous.get(id, end_pos)
		var player: Dictionary = players.get(id, {})
		var attrs: Dictionary = player.get("attributes", {})
		var pace := float(attrs.get("pace", player.get("current_ability", 50)))
		var energy_factor := clampf(float(side_energy.get(id, 1.0)), MIN_ENERGY, 1.0)
		var max_step := (0.8 + pace / 70.0) * energy_factor
		max_step = maxf(max_step, SpatialStateClass.distance(start_pos, end_pos) / float(maxi(1, remaining_steps)))
		result[id] = _step_towards(start_pos, end_pos, max_step)
	return result

func _tactical_target(position: Dictionary, ball: Dictionary, tactic: Dictionary, is_home: bool, in_possession: bool) -> Dictionary:
	if tactic.is_empty():
		return position.duplicate(true)
	var result: Dictionary = position.duplicate(true)
	var attack_direction := 1.0 if is_home else -1.0
	var mentality := String(tactic.get("mentality", "balanced"))
	var mentality_shift := 0.0
	match mentality:
		"very_cautious": mentality_shift = -3.0
		"cautious": mentality_shift = -1.5
		"positive": mentality_shift = 2.0
		"attacking": mentality_shift = 4.0
	if in_possession:
		result.x = float(result.x) + attack_direction * mentality_shift
	else:
		result.x = float(result.x) + attack_direction * mentality_shift * 0.35

	var instructions: Dictionary = tactic.get("instructions", {})
	var in_possession_instructions: Dictionary = instructions.get("in_possession", {})
	var out_of_possession: Dictionary = instructions.get("out_of_possession", {})
	var width_key := String(in_possession_instructions.get("width", "standard")) if in_possession else String(out_of_possession.get("defensive_width", "standard"))
	var width_factor := 1.0
	match width_key:
		"very_wide": width_factor = 1.22
		"wide": width_factor = 1.12
		"narrow": width_factor = 0.86
		"very_narrow": width_factor = 0.76
	result.y = PITCH_WIDTH * 0.5 + (float(result.y) - PITCH_WIDTH * 0.5) * width_factor

	if not in_possession:
		var line := String(out_of_possession.get("defensive_line", "standard"))
		var line_shift := 0.0
		match line:
			"much_higher": line_shift = 6.0
			"higher": line_shift = 3.0
			"lower": line_shift = -3.0
			"much_lower": line_shift = -6.0
		result.x = float(result.x) + attack_direction * line_shift
		var pressing := String(tactic.get("pressing", out_of_possession.get("pressing_triggers", "standard")))
		var press_blend := 0.0
		match pressing:
			"high": press_blend = 0.08
			"very_high": press_blend = 0.14
			"low": press_blend = -0.03
		if press_blend > 0.0:
			result.x = lerpf(float(result.x), float(ball.get("x", result.x)), press_blend)
			result.y = lerpf(float(result.y), float(ball.get("y", result.y)), press_blend)
	return SpatialStateClass.clamp_position(result)

func _step_towards(a: Dictionary, b: Dictionary, max_distance: float) -> Dictionary:
	var dx := float(b.get("x", 0.0)) - float(a.get("x", 0.0))
	var dy := float(b.get("y", 0.0)) - float(a.get("y", 0.0))
	var distance := sqrt(dx * dx + dy * dy)
	if distance <= max_distance or distance <= 0.000001:
		return SpatialStateClass.clamp_position(b.duplicate(true))
	var scale := max_distance / distance
	return SpatialStateClass.clamp_position({"x": float(a.get("x", 0.0)) + dx * scale, "y": float(a.get("y", 0.0)) + dy * scale})

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
