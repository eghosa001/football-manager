extends SceneTree

const CareerSessionClass = preload("res://application/career/career_session.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")
const ContinuousEngineClass = preload("res://simulation/match/continuous_spatial_engine_v4.gd")
const ProfilerClass = preload("res://application/performance/matchday_profiler.gd")

var _failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var session = CareerSessionClass.new()
	var t0 := Time.get_ticks_msec()
	var created: Dictionary = session.new_career("Performance", "", 202607)
	var creation_ms := float(Time.get_ticks_msec() - t0)
	if created.has("error"):
		_failures.append("world creation returned an error")
	else:
		_check_time(creation_ms, "world_creation_ms")

	var runner = DayRunnerClass.new()
	t0 = Time.get_ticks_msec()
	var ordinary: Dictionary = runner.advance_day(session.world, session.history, 202608)
	var ordinary_ms := float(Time.get_ticks_msec() - t0)
	if ordinary.has("error"):
		_failures.append("ordinary Continue returned an error")
	else:
		_check_time(ordinary_ms, "ordinary_day_ms")

	t0 = Time.get_ticks_msec()
	for index in range(7):
		var result: Dictionary = runner.advance_day(session.world, session.history, 202700 + index)
		if result.has("error"):
			_failures.append("weekly Continue returned an error on day %d" % (index + 1))
			break
	var weekly_ms := float(Time.get_ticks_msec() - t0)
	_check_time(weekly_ms, "weekly_advance_ms")

	# Force the opening matchday path and measure all scheduled processing.
	session.world.date = "2026-07-31"
	t0 = Time.get_ticks_msec()
	var matchday: Dictionary = runner.advance_day(session.world, session.history, 202801)
	var matchday_ms := float(Time.get_ticks_msec() - t0)
	if matchday.has("error"):
		_failures.append("opening matchday returned an error")
	elif int(matchday.get("fixtures_played", 0)) <= 0:
		_failures.append("opening matchday played no fixtures")
	else:
		_check_time(matchday_ms, "matchday_162_ms")

	# Exercise the same spatial engine class that production managed matches use.
	var home := _lineup("home", 66)
	var away := _lineup("away", 64)
	t0 = Time.get_ticks_msec()
	var detailed: Dictionary = ContinuousEngineClass.new().simulate_continuous(home, away, 778899, {}, {}, 900, {}, 30)
	var detailed_ms := float(Time.get_ticks_msec() - t0)
	if detailed.is_empty():
		_failures.append("detailed spatial benchmark returned no result")
	else:
		_check_time(detailed_ms, "detailed_match_ms")

	if _failures.is_empty():
		print("[TEST] PERFORMANCE BASELINE PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[PERF] %s" % failure)
	print("[TEST] PERFORMANCE BASELINE FAIL: %d issue(s)" % _failures.size())
	quit(1)

func _check_time(observed_ms: float, key: String) -> void:
	var result := ProfilerClass.check(observed_ms, key)
	print("[PERF] %s=%.0fms baseline=%.0fms ratio=%.2f" % [key, observed_ms, float(result.baseline_ms), float(result.ratio)])
	if not bool(result.pass):
		_failures.append("%s exceeded performance tolerance: %.0fms vs %.0fms baseline (%.2fx)" % [key, observed_ms, float(result.baseline_ms), float(result.ratio)])

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
