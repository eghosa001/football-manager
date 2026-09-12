extends SceneTree

const CareerSessionClass = preload("res://application/career/career_session.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")
const ContinuousEngineClass = preload("res://simulation/match/continuous_spatial_engine_v3.gd")
const ProfilerClass = preload("res://application/performance/matchday_profiler.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var session = CareerSessionClass.new()
	var t0 := Time.get_ticks_msec()
	var created: Dictionary = session.new_career("Performance", "", 202607)
	var creation_ms := float(Time.get_ticks_msec() - t0)
	assert(not created.has("error"))
	_check_time(creation_ms, "world_creation_ms")

	var runner = DayRunnerClass.new()
	t0 = Time.get_ticks_msec()
	var ordinary: Dictionary = runner.advance_day(session.world, session.history, 202608)
	var ordinary_ms := float(Time.get_ticks_msec() - t0)
	assert(not ordinary.has("error"))
	_check_time(ordinary_ms, "ordinary_day_ms")

	t0 = Time.get_ticks_msec()
	for index in range(7):
		var result: Dictionary = runner.advance_day(session.world, session.history, 202700 + index)
		assert(not result.has("error"))
	var weekly_ms := float(Time.get_ticks_msec() - t0)
	_check_time(weekly_ms, "weekly_advance_ms")

	# Force the opening matchday path and measure all scheduled processing.
	session.world.date = "2026-07-31"
	t0 = Time.get_ticks_msec()
	var matchday: Dictionary = runner.advance_day(session.world, session.history, 202801)
	var matchday_ms := float(Time.get_ticks_msec() - t0)
	assert(not matchday.has("error"))
	assert(int(matchday.get("fixtures_played", 0)) > 0)
	_check_time(matchday_ms, "matchday_162_ms")

	var home := _lineup("home", 66)
	var away := _lineup("away", 64)
	t0 = Time.get_ticks_msec()
	var detailed: Dictionary = ContinuousEngineClass.new().simulate_continuous(home, away, 778899, {}, {}, 900, {}, 30)
	var detailed_ms := float(Time.get_ticks_msec() - t0)
	assert(not detailed.is_empty())
	_check_time(detailed_ms, "detailed_match_ms")

	print("[TEST] PERFORMANCE BASELINE PASS")
	quit(0)

func _check_time(observed_ms: float, key: String) -> void:
	var result := ProfilerClass.check(observed_ms, key)
	print("[PERF] %s=%.0fms baseline=%.0fms ratio=%.2f" % [key, observed_ms, float(result.baseline_ms), float(result.ratio)])
	assert(bool(result.pass), "%s exceeded performance tolerance" % key)

func _lineup(prefix: String, rating: int) -> Array:
	var positions := ["GK","DR","DC","DC","DL","DM","MC","MC","AMR","AML","ST"]
	var rows: Array = []
	for i in range(11):
		rows.append({
			"id":"%s-%02d" % [prefix,i],
			"position":positions[i],
			"current_ability":rating,
			"fitness":100,
			"attributes":{
				"pace":rating,"acceleration":rating,"agility":rating,"stamina":rating,"natural_fitness":rating,
				"passing":rating,"technique":rating,"finishing":rating,"dribbling":rating,"balance":rating,
				"decisions":rating,"vision":rating,"composure":rating,"work_rate":rating,"anticipation":rating,
				"marking":rating,"positioning":rating,"reflexes":rating,"one_on_ones":rating,
				"goalkeeper_positioning":rating,"handling":rating
			}
		})
	return rows
