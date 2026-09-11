extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const PlayerLifecycleClass = preload("res://simulation/players/player_lifecycle.gd")
const ContinuousSpatialClass = preload("res://simulation/match/continuous_spatial_engine.gd")
const TacticsClass = preload("res://simulation/tactics/tactics_manager.gd")
const SpatialStateClass = preload("res://simulation/match/spatial_state.gd")

func _init() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(120012)
	var lifecycle = PlayerLifecycleClass.new()
	for player in world.players:
		lifecycle.ensure_player_state(player, 120012)
	var home: Array = []
	var away: Array = []
	for player in world.players:
		if String(player.club_id) == String(world.clubs[0].id) and home.size() < 11:
			home.append(player)
		elif String(player.club_id) == String(world.clubs[1].id) and away.size() < 11:
			away.append(player)

	var engine = ContinuousSpatialClass.new()
	var first: Dictionary = engine.simulate_segment(home, away, 991122, 18, "home", {}, 4)
	var second: Dictionary = engine.simulate_segment(home, away, 991122, 18, "home", {}, 4)
	assert(var_to_bytes(first) == var_to_bytes(second))
	assert(first.model == "continuous_spatial_2d")
	assert(first.frames.size() >= first.action_frames.size())
	assert(first.frames.size() > 0)
	assert(first.events.size() > 0)

	var initial_home: Dictionary = first.initial_state.home_positions
	var moved := false
	for frame in first.frames:
		assert(float(frame.ball.x) >= 0.0 and float(frame.ball.x) <= 105.0)
		assert(float(frame.ball.y) >= 0.0 and float(frame.ball.y) <= 68.0)
		for side in ["home", "away"]:
			var positions: Dictionary = frame[side]
			var energy: Dictionary = frame.energy[side]
			for id in positions.keys():
				assert(float(positions[id].x) >= 0.0 and float(positions[id].x) <= 105.0)
				assert(float(positions[id].y) >= 0.0 and float(positions[id].y) <= 68.0)
				assert(float(energy.get(id, 1.0)) >= 0.35 and float(energy.get(id, 1.0)) <= 1.0)
				if side == "home" and initial_home.has(id):
					if SpatialStateClass.distance(initial_home[id], positions[id]) > 0.01:
						moved = true
	assert(moved)

	var carry: Dictionary = first.state.duplicate(true)
	var continued: Dictionary = engine.simulate_segment(home, away, 991123, 18, String(carry.possession_side), carry, 4)
	for side in ["home", "away"]:
		for id in carry.energy[side].keys():
			assert(float(continued.state.energy[side].get(id, 1.0)) <= float(carry.energy[side][id]) + 0.000001)

	_test_fatigue_limits_movement(engine, home, away, first.initial_state)
	_test_tactics_change_shape(engine, home, away)

	print("[TEST] PHASE 12 CONTINUOUS SPATIAL PASS")
	quit(0)

func _test_fatigue_limits_movement(engine, home: Array, away: Array, initial_state: Dictionary) -> void:
	var fresh_state: Dictionary = initial_state.duplicate(true)
	var tired_state: Dictionary = initial_state.duplicate(true)
	fresh_state["energy"] = _energy_for(home, away, 1.0)
	tired_state["energy"] = _energy_for(home, away, 0.35)
	var fresh: Dictionary = engine.simulate_segment(home, away, 771100, 8, String(initial_state.possession_side), fresh_state, 4)
	var tired: Dictionary = engine.simulate_segment(home, away, 771100, 8, String(initial_state.possession_side), tired_state, 4)
	var fresh_distance := _team_movement(initial_state.home_positions, fresh.state.home_positions) + _team_movement(initial_state.away_positions, fresh.state.away_positions)
	var tired_distance := _team_movement(initial_state.home_positions, tired.state.home_positions) + _team_movement(initial_state.away_positions, tired.state.away_positions)
	assert(tired_distance < fresh_distance)

func _test_tactics_change_shape(engine, home: Array, away: Array) -> void:
	var tactics = TacticsClass.new()
	var wide: Dictionary = tactics.create_tactic("4-3-3", "attacking", "high", "high")
	var narrow: Dictionary = tactics.create_tactic("4-3-3", "cautious", "low", "low")
	assert(tactics.set_instruction(wide, "in_possession", "width", "wide") == OK)
	assert(tactics.set_instruction(narrow, "in_possession", "width", "narrow") == OK)
	var wide_result: Dictionary = engine.simulate_segment(home, away, 881122, 10, "home", {}, 6, wide, narrow)
	var narrow_result: Dictionary = engine.simulate_segment(home, away, 881122, 10, "home", {}, 6, narrow, wide)
	assert(wide_result.tactical_motion)
	assert(narrow_result.tactical_motion)
	assert(_average_width(wide_result.state.home_positions) > _average_width(narrow_result.state.home_positions))
	assert(_average_x(wide_result.state.home_positions) > _average_x(narrow_result.state.home_positions))

func _energy_for(home: Array, away: Array, value: float) -> Dictionary:
	var result := {"home": {}, "away": {}}
	for player in home:
		result.home[String(player.id)] = value
	for player in away:
		result.away[String(player.id)] = value
	return result

func _team_movement(before: Dictionary, after: Dictionary) -> float:
	var total := 0.0
	for id in before.keys():
		if after.has(id):
			total += SpatialStateClass.distance(before[id], after[id])
	return total

func _average_width(positions: Dictionary) -> float:
	if positions.is_empty():
		return 0.0
	var total := 0.0
	for position in positions.values():
		total += absf(float(position.y) - 34.0)
	return total / float(positions.size())

func _average_x(positions: Dictionary) -> float:
	if positions.is_empty():
		return 0.0
	var total := 0.0
	for position in positions.values():
		total += float(position.x)
	return total / float(positions.size())
