extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const InspectorClass = preload("res://tools/world_inspector/world_inspector.gd")
const MatchDebuggerClass = preload("res://tools/match_debugger/match_debugger.gd")
const MatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")
const SaveFuzzerClass = preload("res://tools/save_debugger/save_fuzzer.gd")
const PerformanceClass = preload("res://tools/performance/performance_baseline.gd")
const CompetitionInspectorClass = preload("res://tools/competition_inspector/competition_inspector.gd")

func _init() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(70707)
	var inspector = InspectorClass.new()
	var summary: Dictionary = inspector.summarize(world)
	assert(int(summary.clubs) == world.clubs.size())
	assert(int(summary.players_active) > 0)
	assert(inspector.validate(world).is_empty())

	var result: Dictionary = MatchEngineClass.new().simulate_match(world.clubs[0], world.clubs[1], world.players, 777)
	var debugger = MatchDebuggerClass.new()
	assert(debugger.validate(result).is_empty())
	assert(int(debugger.summarize(result).events) > 0)

	var competition_id := String(world.competitions[0].id)
	var comp_report: Dictionary = CompetitionInspectorClass.new().inspect(world, competition_id)
	assert(not comp_report.has("error"))
	assert(int(comp_report.fixture_count) > 0)
	assert(CompetitionInspectorClass.new().duplicate_fixtures(world, competition_id).is_empty())

	var perf = PerformanceClass.new()
	var world_size: Dictionary = perf.measure_world(world)
	assert(int(world_size.serialized_bytes) > 0)
	var bench: Dictionary = perf.benchmark(func(): return inspector.summarize(world), 5)
	assert(float(bench.avg_usec) >= 0.0)

	var path := "user://tooling_save_test.fdn"
	var fuzzer = SaveFuzzerClass.new()
	var first: Dictionary = fuzzer.round_trip(path, world, [])
	assert(bool(first.ok) and bool(first.same_world))
	var second: Dictionary = fuzzer.round_trip(path, world, [])
	assert(bool(second.ok))
	var recovered: Dictionary = fuzzer.corrupt_and_recover(path)
	assert(bool(recovered.ok))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	print("[TEST] DEVELOPER TOOLING PASS")
	quit(0)
