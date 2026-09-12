extends SceneTree

const CareerSessionClass = preload("res://application/career/career_session.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")
const SaveStoreClass = preload("res://persistence/save_store.gd")
const ProfilerClass = preload("res://application/performance/matchday_profiler.gd")

func _init() -> void:
	var session = CareerSessionClass.new()
	var created: Dictionary = session.new_career("Save Growth", "", 78123)
	assert(not created.has("error"))

	var store = SaveStoreClass.new()
	var path := "user://production-save-growth.fdn"
	_cleanup(path)

	var t0 := Time.get_ticks_msec()
	assert(store.save_atomic(path, session.world, session.history) == OK)
	var save_ms := float(Time.get_ticks_msec() - t0)
	assert(bool(ProfilerClass.check(save_ms, "save_roundtrip_ms").pass))
	var initial_bytes := FileAccess.get_file_as_bytes(path).size()
	assert(initial_bytes > 0)
	assert(not store.load_save(path).is_empty())

	var runner = DayRunnerClass.new()
	for day in range(35):
		var result: Dictionary = runner.advance_day(session.world, session.history, 78124 + day)
		assert(not result.has("error"))

	assert(store.save_atomic(path, session.world, session.history) == OK)
	var later_bytes := FileAccess.get_file_as_bytes(path).size()
	var growth := ProfilerClass.check_save_growth(initial_bytes, later_bytes)
	assert(bool(growth.pass), "save growth ratio exceeded production limit: %.2f" % float(growth.ratio))
	var loaded := store.load_save(path)
	assert(not loaded.is_empty())
	assert(String((loaded.world as Dictionary).get("date", "")) == String(session.world.get("date", "")))

	# Corrupt the primary and prove the previous atomic backup is recoverable.
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string("corrupt")
	file.close()
	var recovered := store.load_save(path)
	assert(not recovered.is_empty())
	assert(FileAccess.file_exists(path + ".bak"))

	_cleanup(path)
	print("[TEST] LONG SAVE GROWTH PASS")
	quit(0)

func _cleanup(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var candidate := path + suffix
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
