class_name SpatialMatchEngine
extends RefCounted

const TacticalMatchEngineClass = preload("res://simulation/match/tactical_match_engine.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

var _tactical = TacticalMatchEngineClass.new()

func simulate_match(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int) -> Dictionary:
	var result: Dictionary = _tactical.simulate_match(home_club, away_club, players, seed)
	var frames: Array = _build_spatial_frames(result, seed)
	result["spatial"] = {
		"pitch_width": 1.0,
		"pitch_height": 1.0,
		"frames": frames,
		"model": "normalized_2d_v1"
	}
	_enrich_events_with_space(result, frames, seed)
	_append_set_pieces(result, seed)
	_recalculate_from_events(result)
	return result

func apply_to_fixture(fixture: Dictionary, result: Dictionary) -> void:
	_tactical.apply_to_fixture(fixture, result)

func _build_spatial_frames(result: Dictionary, seed: int) -> Array:
	var frames: Array = []
	for minute in range(0, 91, 5):
		var home_positions := {}
		var away_positions := {}
		for i in range(result.lineups.home.size()):
			var player_id: String = String(result.lineups.home[i])
			home_positions[player_id] = _position_for(seed, minute, i, true)
		for i in range(result.lineups.away.size()):
			var player_id: String = String(result.lineups.away[i])
			away_positions[player_id] = _position_for(seed, minute, i, false)
		frames.append({"minute": minute, "home": home_positions, "away": away_positions})
	return frames

func _position_for(seed: int, minute: int, index: int, home: bool) -> Dictionary:
	var row: int = index / 4
	var column: int = index % 4
	var base_x: float = 0.08 + float(row) * 0.20
	var base_y: float = 0.12 + float(column) * 0.22
	if index == 0:
		base_x = 0.05
		base_y = 0.5
	var jitter_x: float = (SeededRngClass.unit_for(seed, 700_000 + minute * 100 + index * 2) - 0.5) * 0.08
	var jitter_y: float = (SeededRngClass.unit_for(seed, 700_001 + minute * 100 + index * 2) - 0.5) * 0.10
	var x: float = clampf(base_x + jitter_x, 0.02, 0.98)
	if not home:
		x = 1.0 - x
	return {"x": x, "y": clampf(base_y + jitter_y, 0.02, 0.98)}

func _enrich_events_with_space(result: Dictionary, frames: Array, seed: int) -> void:
	for event_index in range(result.events.size()):
		var event: Dictionary = result.events[event_index]
		var player_id: String = String(event.get("player_id", ""))
		if player_id == "":
			continue
		var frame: Dictionary = _nearest_frame(frames, int(event.get("minute", 0)))
		var side: String = String(event.get("side", "home"))
		var team_positions: Dictionary = frame.get(side, {})
		var position: Dictionary = team_positions.get(player_id, {"x": 0.5, "y": 0.5})
		event["position"] = position.duplicate(true)
		event["pressure"] = _pressure_at(frame, side, position)
		if String(event.get("type", "")) == "pass":
			event["passing_lane"] = _passing_lane_quality(frame, side, position, seed, event_index)
		elif String(event.get("type", "")) == "shot":
			event["goalkeeper_position"] = _goalkeeper_position(frame, side)

func _nearest_frame(frames: Array, minute: int) -> Dictionary:
	var best: Dictionary = frames[0]
	var best_distance := 999
	for frame in frames:
		var distance: int = absi(int(frame.minute) - minute)
		if distance < best_distance:
			best_distance = distance
			best = frame
	return best

func _pressure_at(frame: Dictionary, attacking_side: String, position: Dictionary) -> float:
	var defending_side := "away" if attacking_side == "home" else "home"
	var pressure := 0.0
	for defender in frame.get(defending_side, {}).values():
		var dx: float = float(defender.x) - float(position.x)
		var dy: float = float(defender.y) - float(position.y)
		var distance := sqrt(dx * dx + dy * dy)
		pressure += maxf(0.0, 0.24 - distance)
	return snappedf(clampf(pressure * 2.0, 0.0, 1.0), 0.001)

func _passing_lane_quality(frame: Dictionary, side: String, position: Dictionary, seed: int, event_index: int) -> float:
	var defending_side := "away" if side == "home" else "home"
	var blockers := 0
	for defender in frame.get(defending_side, {}).values():
		if absf(float(defender.y) - float(position.y)) < 0.12:
			blockers += 1
	var noise: float = SeededRngClass.unit_for(seed, 800_000 + event_index)
	return snappedf(clampf(0.9 - blockers * 0.08 + (noise - 0.5) * 0.1, 0.1, 1.0), 0.001)

func _goalkeeper_position(frame: Dictionary, attacking_side: String) -> Dictionary:
	var defending_side := "away" if attacking_side == "home" else "home"
	var positions: Dictionary = frame.get(defending_side, {})
	for position in positions.values():
		if (attacking_side == "home" and float(position.x) > 0.85) or (attacking_side == "away" and float(position.x) < 0.15):
			return position.duplicate(true)
	return {"x": 0.95 if attacking_side == "home" else 0.05, "y": 0.5}

func _append_set_pieces(result: Dictionary, seed: int) -> void:
	for side_index in range(2):
		var side := "home" if side_index == 0 else "away"
		var count: int = 2 + int(SeededRngClass.value_for(seed, 900_000 + side_index) % 4)
		for i in range(count):
			var minute: int = 8 + int(SeededRngClass.value_for(seed, 900_100 + side_index * 20 + i) % 78)
			var event_type := "corner" if i % 2 == 0 else "free_kick"
			result.events.append({"minute": minute, "type": event_type, "side": side, "outcome": "taken", "spatial": true})

func _recalculate_from_events(result: Dictionary) -> void:
	for side in ["home", "away"]:
		result.stats[side].shots = 0
		result.stats[side].shots_on_target = 0
		result.stats[side].goals = 0
		result.stats[side].xg = 0.0
	result.home_goals = 0
	result.away_goals = 0
	for event in result.events:
		if String(event.get("type", "")) != "shot":
			continue
		var side: String = String(event.side)
		result.stats[side].shots += 1
		result.stats[side].xg += float(event.get("xg", 0.0))
		if String(event.outcome) in ["goal", "saved"]:
			result.stats[side].shots_on_target += 1
		if String(event.outcome) == "goal":
			result.stats[side].goals += 1
			if side == "home": result.home_goals += 1
			else: result.away_goals += 1
	result.stats.home.xg = snappedf(float(result.stats.home.xg), 0.01)
	result.stats.away.xg = snappedf(float(result.stats.away.xg), 0.01)
