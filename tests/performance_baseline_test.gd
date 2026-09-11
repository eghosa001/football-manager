extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const ProfilerClass = preload("res://application/performance/matchday_profiler.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var world: Dictionary = WorldGeneratorClass.new().create_world(202607)
	var creation_ms := float(Time.get_ticks_msec() - t0)
	var c := ProfilerClass.check(creation_ms, "world_creation_ms")
	print("[PERF] creation=%.0fms ratio=%.2f" % [creation_ms, float(c.ratio)])
	assert(bool(c.pass))

	var runner = SeasonRunnerClass.new()
	t0 = Time.get_ticks_msec()
	runner.assign_fixture_dates(world)
	var results: Array = runner.advance_to_next_matchday(world, 202607)
	var matchday_ms := float(Time.get_ticks_msec() - t0)
	var m := ProfilerClass.check(matchday_ms, "matchday_162_ms")
	print("[PERF] matchday fixtures=%d ms=%.0f ratio=%.2f" % [results.size(), matchday_ms, float(m.ratio)])
	assert(bool(m.pass))
	assert(results.size() > 0)
	print("[TEST] PERFORMANCE BASELINE PASS")
	quit(0)
