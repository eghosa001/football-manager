extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const LeagueSystemClass = preload("res://application/season/league_system.gd")
const SaveStoreClass = preload("res://persistence/save_store.gd")

var failures := 0
var checks := 0

func _init() -> void:
	print("[TEST] Football Dynasty Phase 3")
	_test_save_reload_continue()
	_test_calendar_matchdays()
	_test_backup_recovery()
	_test_promotion_relegation()
	_test_ten_season_soak()
	if failures == 0:
		print("[TEST] PHASE 3 PASS — %d checks" % checks)
		quit(0)
	else:
		push_error("[TEST] PHASE 3 FAIL — %d failures across %d checks" % [failures, checks])
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
	_cleanup_save(save_path)
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
	_cleanup_save(save_path)

func _test_calendar_matchdays() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(222, 1, 8, 15)
	var runner = SeasonRunnerClass.new()
	runner.assign_fixture_dates(world)
	var first_date := String(world.fixtures[0].date)
	_expect(first_date == "2026-08-01", "First matchday should begin on configured season start")
	var results: Array = runner.advance_to_next_matchday(world, 2026_0801)
	_expect(results.size() == 4, "Eight-team league matchday should play four fixtures")
	_expect(world.date == first_date, "World calendar should advance to played matchday")
	for result in results:
		_expect(result.fixture.played, "Every matchday result should mark its fixture played")

func _test_backup_recovery() -> void:
	var save_path := "user://phase3-recovery.save"
	_cleanup_save(save_path)
	var store = SaveStoreClass.new()
	var first_world: Dictionary = WorldGeneratorClass.new().create_world(333, 1, 4, 11)
	var second_world: Dictionary = first_world.duplicate(true)
	second_world.date = "2026-08-01"
	_expect(store.save_atomic(save_path, first_world, []) == OK, "Initial recovery save should succeed")
	_expect(store.save_atomic(save_path, second_world, []) == OK, "Second recovery save should create backup")
	var corrupt := FileAccess.open(save_path, FileAccess.WRITE)
	corrupt.store_string("{ definitely-not-valid-json")
	corrupt.close()
	var recovered: Dictionary = store.load_save(save_path)
	_expect(not recovered.is_empty(), "Corrupt primary save should recover from backup")
	_expect(recovered.world.date == first_world.date, "Recovery should return last known-good backup")
	_cleanup_save(save_path)

func _test_promotion_relegation() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(444, 1, 8, 15)
	var all_clubs: Array = world.competitions[0].club_ids.duplicate()
	var country_id: String = world.countries[0].id
	world.competitions = [
		{"id": "tier-1", "country_id": country_id, "name": "Premier", "club_ids": all_clubs.slice(0, 4), "points_win": 3, "points_draw": 1, "tier": 1},
		{"id": "tier-2", "country_id": country_id, "name": "Championship", "club_ids": all_clubs.slice(4, 8), "points_win": 3, "points_draw": 1, "tier": 2},
	]
	var league_system = LeagueSystemClass.new()
	league_system.rollover(world, 2026)
	var runner = SeasonRunnerClass.new()
	var records: Array = runner.complete_world_season(world, 444_2026)
	_expect(records.size() == 2, "Two-tier test world should produce two season records")
	var upper_bottom: String = records[0].table[-1].club_id
	var lower_champion: String = records[1].table[0].club_id
	var movements: Array = league_system.apply_promotion_relegation(world, records, 1)
	_expect(movements.size() == 1, "Adjacent tiers should produce one promotion/relegation movement")
	_expect(lower_champion in world.competitions[0].club_ids, "Lower-tier champion should be promoted")
	_expect(upper_bottom in world.competitions[1].club_ids, "Upper-tier bottom club should be relegated")
	_expect(world.competitions[0].club_ids.size() == 4 and world.competitions[1].club_ids.size() == 4, "Promotion/relegation must preserve league sizes")

func _test_ten_season_soak() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(555, 1, 8, 15)
	var history: Array = []
	var runner = SeasonRunnerClass.new()
	var store = SaveStoreClass.new()
	var save_path := "user://phase3-soak.save"
	_cleanup_save(save_path)
	for season_index in range(10):
		var expected_year: int = 2026 + season_index
		_expect(int(world.season_year) == expected_year, "Soak season year should advance monotonically")
		var outcome: Dictionary = runner.complete_and_rollover(world, history, 555_000 + expected_year, 1)
		_expect(outcome.records.size() == 1, "Single-country soak should record one competition per season")
		_expect(outcome.records[0].complete, "Every soak season should complete")
		_expect(outcome.records[0].fixture_count == 56, "Eight-team double round robin should remain 56 fixtures")
		_expect(history.size() == season_index + 1, "History should retain every completed season")
		_expect(store.save_atomic(save_path, world, history) == OK, "Soak save should succeed after each season")
		var loaded: Dictionary = store.load_save(save_path)
		_expect(not loaded.is_empty(), "Soak save should reload after each season")
		world = loaded.world
		history = loaded.history
		_expect(int(world.season_year) == expected_year + 1, "Reloaded world should retain rolled-over season year")
		_expect(world.fixtures.size() == 56, "Rolled-over season should regenerate complete fixture list")
		for fixture in world.fixtures:
			_expect(not fixture.played, "New-season fixtures must be unplayed")
	_expect(history.size() == 10, "Ten-season soak should retain ten historical records")
	_cleanup_save(save_path)

func _cleanup_save(path: String) -> void:
	for candidate in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
