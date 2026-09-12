extends SceneTree

const CareerSessionClass = preload("res://application/career/career_session.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")
const ProfilerClass = preload("res://application/performance/matchday_profiler.gd")

func _init() -> void:
	var session = CareerSessionClass.new()
	var created: Dictionary = session.new_career("Memory Soak", "", 444777)
	assert(not created.has("error"))
	var runner = DayRunnerClass.new()
	var start_memory := OS.get_static_memory_usage()

	for day in range(180):
		var result: Dictionary = runner.advance_day(session.world, session.history, 445000 + day)
		assert(not result.has("error"))
		if day % 30 == 0:
			print("[MEMORY] day=%d bytes=%d" % [day, OS.get_static_memory_usage()])

	var end_memory := OS.get_static_memory_usage()
	var checked := ProfilerClass.check_memory_growth(start_memory, end_memory)
	print("[MEMORY] start=%d end=%d growth=%.1fMB limit=%.1fMB" % [start_memory, end_memory, float(checked.growth_mb), float(checked.limit_mb)])
	assert(bool(checked.pass), "long-session memory growth exceeded production limit")
	assert(session.history.size() > 0)
	print("[TEST] LONG SESSION MEMORY PASS")
	quit(0)
