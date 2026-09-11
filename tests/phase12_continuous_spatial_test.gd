extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const PlayerLifecycleClass = preload("res://simulation/players/player_lifecycle.gd")
const ContinuousSpatialClass = preload("res://simulation/match/continuous_spatial_engine.gd")

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
					if absf(float(initial_home[id].x) - float(positions[id].x)) > 0.01 or absf(float(initial_home[id].y) - float(positions[id].y)) > 0.01:
						moved = true
	assert(moved)

	var carry: Dictionary = first.state.duplicate(true)
	var continued: Dictionary = engine.simulate_segment(home, away, 991123, 18, String(carry.possession_side), carry, 4)
	for side in ["home", "away"]:
		for id in carry.energy[side].keys():
			assert(float(continued.state.energy[side].get(id, 1.0)) <= float(carry.energy[side][id]) + 0.000001)

	print("[TEST] PHASE 12 CONTINUOUS SPATIAL PASS")
	quit(0)
