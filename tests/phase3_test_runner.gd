extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const SaveStoreClass = preload("res://persistence/save_store.gd")

var failures := 0
var checks := 0

func _init() -> void:
	print("[TEST] Football Dynasty Phase 3 foundation")
	_test_save_reload_continue()
	if failures == 0:
		print("[TEST] PHASE 3 FOUNDATION PASS — %d checks" % checks)
		quit(0)
	else:
		push_error("[TEST] PHASE 3 FOUNDATION FAIL — %d failures across %d checks" % [failures, checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[TEST] %s" % message)

func _deep_equal(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if typeof(left) == TYPE_DICTIONARY:
		if left.size() != right.size():
			return false
		for key in left.keys():
			if not right.has(key) or not _deep_equal(left[key], right[key]):
				return false
		return true
	if typeof(left) == TYPE_ARRAY:
		if left.size() != right.size():
			return false
		for i in range(left.size()):
			if not _deep_equal(left[i], right[i]):
				return false
		return true
	return left == right

func _test_save_reload_continue() -> void:
	var generator = WorldGeneratorClass.new()
	var uninterrupted: Dictionary = generator.create_world(12345)
	var interrupted: Dictionary = generator.create_world(12345)
	var competition_id: String = uninterrupted.competitions[0].id
	var season_seed := 2026_0701
	var runner = SeasonRunnerClass.new()
	var baseline_record: Dictionary = runner.complete_competition(uninterrupted, competition_id, season_seed)
	_expect(baseline_record.complete, "Uninterrupted league should complete")
	_expect(baseline_record.fixture_count == 380, "20-team league should contain 380 fixtures")

	for _i in range(37):
		var result: Dictionary = runner.play_next_fixture(interrupted, competition_id, season_seed)
		_expect(not result.is_empty(), "Interrupted run should still have a fixture to play")

	var save_path := "user://phase3-ci.save"
	var store = SaveStoreClass.new()
	_expect(store.save_atomic(save_path, interrupted, []) == OK, "Atomic save should succeed")
	var loaded: Dictionary = store.load_save(save_path)
	_expect(not loaded.is_empty(), "Saved game should load")
	_expect(loaded.schema_version == SaveStoreClass.CURRENT_SCHEMA_VERSION, "Save schema version should be current")
	_expect(_deep_equal(interrupted, loaded.world), "Save/load must preserve world state exactly")

	var continued_record: Dictionary = runner.complete_competition(loaded.world, competition_id, season_seed)
	_expect(continued_record.complete, "Reloaded league should complete")
	_expect(_deep_equal(baseline_record.table, continued_record.table), "Save/reload/continue must match uninterrupted final table")
	_expect(baseline_record.champion_club_id == continued_record.champion_club_id, "Champion must be identical after save/reload continuation")

	var history: Array = [continued_record]
	_expect(store.save_atomic(save_path, loaded.world, history) == OK, "Save with season history should succeed")
	var history_loaded: Dictionary = store.load_save(save_path)
	_expect(history_loaded.history.size() == 1, "Historical season record should persist")
	_expect(history_loaded.history[0].champion_club_id == continued_record.champion_club_id, "Historical champion should persist")

	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
