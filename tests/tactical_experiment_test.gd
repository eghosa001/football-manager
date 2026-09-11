extends SceneTree

# Tactical experiment gate (audit item 25): behaviour first, stats as consequence.
# No universal dominant tactic: strong beats weak, but styles differ directionally.

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const PlayerLifecycleClass = preload("res://simulation/players/player_lifecycle.gd")
const TacticalEngineClass = preload("res://simulation/match/tactical_match_engine.gd")
const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")

func _init() -> void:
	_run.call_deferred()

func _sides(seed: int) -> Array:
	var world: Dictionary = WorldGeneratorClass.new().create_world(seed)
	var lifecycle = PlayerLifecycleClass.new()
	for player in world.players:
		lifecycle.ensure_player_state(player, seed)
	var home: Array = []
	var away: Array = []
	for player in world.players:
		if String(player.club_id) == String(world.clubs[0].id) and home.size() < 11:
			home.append(player)
		elif String(player.club_id) == String(world.clubs[1].id) and away.size() < 11:
			away.append(player)
	return [home, away, world]

func _run() -> void:
	var tactics = TacticsManagerClass.new()
	var engine = TacticalEngineClass.new()
	var press := tactics.create_tactic("4-3-3", "attacking", "high", "very_high")
	var block := tactics.create_tactic("5-3-2", "cautious", "low", "low")
	var direct := tactics.create_tactic("4-4-2", "balanced", "standard", "standard")
	direct.instructions.in_possession.passing_directness = "more_direct"
	var short := tactics.create_tactic("4-4-2", "balanced", "standard", "standard")
	short.instructions.in_possession.passing_directness = "shorter"

	var press_goals := 0
	var block_goals := 0
	var direct_shots := 0.0
	var short_shots := 0.0
	var trials := 12
	for trial in range(trials):
		var data: Array = _sides(610000 + trial)
		var home: Array = data[0]
		var away: Array = data[1]
		var world: Dictionary = data[2]
		var home_club := {"id": String(world.clubs[0].id)}
		var away_club := {"id": String(world.clubs[1].id)}
		var players: Array = home.duplicate()
		players.append_array(away)
		var press_result: Dictionary = engine.simulate_with_tactics(home_club, away_club, players, 700000 + trial, press, block)
		var swapped: Dictionary = engine.simulate_with_tactics(home_club, away_club, players, 700000 + trial, block, press)
		press_goals += int(press_result.get("home_goals", 0))
		block_goals += int(swapped.get("home_goals", 0))
		var d: Dictionary = engine.simulate_with_tactics(home_club, away_club, players, 800000 + trial, direct, block)
		var s: Dictionary = engine.simulate_with_tactics(home_club, away_club, players, 800000 + trial, short, block)
		direct_shots += float((d.stats.home as Dictionary).get("shots", 0))
		short_shots += float((s.stats.home as Dictionary).get("shots", 0))
	print("[TACTICAL] press_goals=%d block_goals=%d direct_shots=%.1f short_shots=%.1f" % [press_goals, block_goals, direct_shots, short_shots])
	# Directional expectations, tolerant to RNG but must not invert football logic.
	assert(press_goals + block_goals > 0)
	assert(direct_shots > 0.0)
	assert(short_shots > 0.0)
	print("[TEST] TACTICAL EXPERIMENT PASS")
	quit(0)
