extends SceneTree

# Independent spatial-engine distribution gate (audit item 24).
# Abstract 100k gate does not prove continuous engine health.

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const PlayerLifecycleClass = preload("res://simulation/players/player_lifecycle.gd")
const ContinuousSpatialClass = preload("res://simulation/match/continuous_spatial_engine.gd")
const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var tactics = TacticsManagerClass.new()
	var home_tactic := tactics.create_tactic("4-3-3", "balanced", "standard", "standard")
	var away_tactic := tactics.create_tactic("4-4-2", "balanced", "standard", "standard")
	var engine = ContinuousSpatialClass.new()
	var total_shots := 0
	var total_goals := 0
	var total_interceptions := 0
	var total_distance := 0.0
	var samples := 24
	for sample in range(samples):
		var world: Dictionary = WorldGeneratorClass.new().create_world(910000 + sample)
		var lifecycle = PlayerLifecycleClass.new()
		for player in world.players:
			lifecycle.ensure_player_state(player, 910000 + sample)
		var home: Array = []
		var away: Array = []
		for player in world.players:
			if String(player.club_id) == String(world.clubs[0].id) and home.size() < 11:
				home.append(player)
			elif String(player.club_id) == String(world.clubs[1].id) and away.size() < 11:
				away.append(player)
		var result: Dictionary = engine.simulate_continuous(home, away, 300000 + sample, home_tactic, away_tactic, 540)
		total_shots += int(result.summary.shots)
		total_goals += int(result.summary.goals)
		total_interceptions += int(result.summary.interceptions)
		total_distance += float(result.summary.home_distance) + float(result.summary.away_distance)
	var avg_shots := float(total_shots) / float(samples)
	var avg_goals := float(total_goals) / float(samples)
	var avg_interceptions := float(total_interceptions) / float(samples)
	var avg_distance := total_distance / float(samples) / 22.0
	print("[SPATIAL] samples=%d shots=%.2f goals=%.2f interceptions=%.2f dist/player=%.0fm" % [samples, avg_shots, avg_goals, avg_interceptions, avg_distance])
	# Sanity bounds per 540-tick (54s) sample: engine must produce football activity,
	# not frozen players or pinball interceptions. Full-match scaling happens in the
	# abstract engine gate; this proves the continuous tier is alive and bounded.
	assert(avg_shots >= 0.5 and avg_shots <= 12.0)
	assert(avg_goals >= 0.05 and avg_goals <= 3.0)
	assert(avg_interceptions >= 0.5 and avg_interceptions <= 60.0)
	assert(avg_distance >= 80.0 and avg_distance <= 900.0)
	print("[TEST] SPATIAL DISTRIBUTION PASS")
	quit(0)
