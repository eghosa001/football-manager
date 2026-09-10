extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const TacticsClass = preload("res://simulation/tactics/tactics_manager.gd")
const EconomyClass = preload("res://simulation/finance/club_economy.gd")
const SpatialClass = preload("res://simulation/match/spatial_match_engine.gd")
const QueryClass = preload("res://application/career/career_query.gd")

var failures := 0
var checks := 0

func _init() -> void:
	print("[TEST] Football Dynasty Phase 8/9")
	_test_spatial_determinism_and_invariants()
	_test_spatial_distribution()
	_test_career_queries_are_read_only()
	_test_ui_resources()
	if failures == 0:
		print("[TEST] PHASE 8/9 PASS — %d checks" % checks)
		quit(0)
	else:
		push_error("[TEST] PHASE 8/9 FAIL — %d failures across %d checks" % [failures, checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[TEST] " + message)

func _prepared_world(seed: int) -> Dictionary:
	var world: Dictionary = WorldGeneratorClass.new().create_world(seed, 1, 4, 25)
	TacticsClass.new().ensure_world(world, seed)
	EconomyClass.new().ensure_world(world)
	return world

func _test_spatial_determinism_and_invariants() -> void:
	var world := _prepared_world(89001)
	var engine = SpatialClass.new()
	var a: Dictionary = engine.simulate_match(world.clubs[0], world.clubs[1], world.players, 123456)
	var b: Dictionary = engine.simulate_match(world.clubs[0], world.clubs[1], world.players, 123456)
	_expect(var_to_bytes(a) == var_to_bytes(b), "Spatial match must reproduce exactly from the same seed")
	var frames: Array = a.spatial.frames
	_expect(frames.size() == 19, "Spatial match must expose 5-minute frames from 0 through 90")
	for frame in frames:
		_expect(frame.home.size() == 11 and frame.away.size() == 11, "Every spatial frame must contain both elevens")
		for side in ["home", "away"]:
			for position in frame[side].values():
				_expect(float(position.x) >= 0.0 and float(position.x) <= 1.0, "Player X coordinate must remain on pitch")
				_expect(float(position.y) >= 0.0 and float(position.y) <= 1.0, "Player Y coordinate must remain on pitch")
	var pass_enriched := 0
	var shot_enriched := 0
	var set_pieces := 0
	var event_home_goals := 0
	var event_away_goals := 0
	for event in a.events:
		if String(event.get("type", "")) == "pass" and event.has("position"):
			pass_enriched += 1
			_expect(float(event.pressure) >= 0.0 and float(event.pressure) <= 1.0, "Pressure must be normalized")
			_expect(float(event.passing_lane) >= 0.0 and float(event.passing_lane) <= 1.0, "Passing lane quality must be normalized")
		elif String(event.get("type", "")) == "shot" and event.has("position"):
			shot_enriched += 1
			_expect(event.has("goalkeeper_position"), "Shots must expose goalkeeper positioning")
			if String(event.outcome) == "goal":
				if String(event.side) == "home": event_home_goals += 1
				else: event_away_goals += 1
		elif String(event.get("type", "")) in ["corner", "free_kick"]:
			set_pieces += 1
	_expect(pass_enriched > 0, "Spatial engine must enrich canonical passes")
	_expect(shot_enriched > 0, "Spatial engine must enrich canonical shots")
	_expect(set_pieces >= 4, "Spatial engine must emit set pieces")
	_expect(event_home_goals == int(a.home_goals) and event_away_goals == int(a.away_goals), "Score must remain derived from shot events")
	_expect(int(a.stats.home.goals) == int(a.home_goals) and int(a.stats.away.goals) == int(a.away_goals), "Spatial statistics must agree with score")

func _test_spatial_distribution() -> void:
	var world := _prepared_world(89101)
	var engine = SpatialClass.new()
	var goals := 0
	var shots := 0
	var matches := 250
	for i in range(matches):
		var result: Dictionary = engine.simulate_match(world.clubs[i % 4], world.clubs[(i + 1) % 4], world.players, 89101 + i * 97)
		goals += int(result.home_goals) + int(result.away_goals)
		shots += int(result.stats.home.shots) + int(result.stats.away.shots)
	var goals_per_match := float(goals) / matches
	var shots_per_match := float(shots) / matches
	print("[SPATIAL VALIDATION] n=%d goals=%.2f shots=%.2f" % [matches, goals_per_match, shots_per_match])
	_expect(goals_per_match >= 1.5 and goals_per_match <= 5.0, "Spatial goals distribution must remain believable")
	_expect(shots_per_match >= 10.0 and shots_per_match <= 35.0, "Spatial shot distribution must remain believable")

func _test_career_queries_are_read_only() -> void:
	var world := _prepared_world(89201)
	var query = QueryClass.new()
	var club_id: String = String(world.clubs[0].id)
	var before: PackedByteArray = var_to_bytes(world)
	query.dashboard(world, club_id)
	query.squad(world, club_id)
	query.medical(world, club_id)
	query.schedule(world, club_id)
	query.competition_table(world, String(world.competitions[0].id))
	query.staff(world, club_id)
	query.finances(world, club_id)
	query.tactics(world, club_id)
	query.transfers(world, club_id)
	query.world_search(world, "Daniel")
	_expect(before == var_to_bytes(world), "Career UI query service must not mutate simulation state")
	_expect(query.squad(world, club_id).size() == 25, "Squad view must expose the club squad")
	_expect(query.staff(world, club_id).size() == 5, "Staff view must expose club staff")
	_expect(query.schedule(world, club_id).size() > 0, "Schedule view must expose fixtures")
	_expect(query.world_search(world, "Nigeria", 10).size() > 0, "World search must find clubs")
	var detailed: Dictionary = SpatialClass.new().simulate_match(world.clubs[0], world.clubs[1], world.players, 89209)
	var analysis: Dictionary = query.match_analysis(detailed)
	_expect(analysis.frames.size() == 19, "Match analysis must expose spatial frames")
	_expect(analysis.shots.home.size() + analysis.shots.away.size() > 0, "Match analysis must expose shot data")

func _test_ui_resources() -> void:
	_expect(ResourceLoader.exists("res://game/scenes/main.tscn"), "Career UI main scene must exist")
	_expect(ResourceLoader.exists("res://game/main.gd"), "Career UI controller must exist")
	_expect(ResourceLoader.exists("res://game/match_viewer.gd"), "2D match viewer must exist")
	var scene: PackedScene = load("res://game/scenes/main.tscn")
	_expect(scene != null and scene.can_instantiate(), "Career UI scene must be instantiable")
