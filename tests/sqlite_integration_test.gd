extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const SqliteStoreClass = preload("res://persistence/sqlite_save_store.gd")

func _init() -> void:
	print("[TEST] Phase 3 SQLite integration")
	var store = SqliteStoreClass.new()
	if not store.is_available():
		push_error("[TEST] SQLite GDExtension is not available")
		quit(1)
		return
	var path := "user://phase3-sqlite-ci.db"
	_cleanup(path)
	var world: Dictionary = WorldGeneratorClass.new().create_world(777, 1, 4, 11)
	world.date = "2026-08-15"
	var history: Array = [{"competition_id": world.competitions[0].id, "season_start_year": 2025, "champion_club_id": world.clubs[0].id}]
	if store.save_atomic(path, world, history) != OK:
		push_error("[TEST] SQLite atomic save failed")
		quit(1)
		return
	var loaded: Dictionary = store.load_save(path)
	if loaded.is_empty():
		push_error("[TEST] SQLite load returned empty payload")
		quit(1)
		return
	if int(loaded.schema_version) != SqliteStoreClass.CURRENT_SCHEMA_VERSION:
		push_error("[TEST] SQLite schema version mismatch")
		quit(1)
		return
	if String(loaded.world.date) != String(world.date):
		push_error("[TEST] SQLite world state did not round-trip")
		quit(1)
		return
	if loaded.world.fixtures.size() != world.fixtures.size() or loaded.world.players.size() != world.players.size():
		push_error("[TEST] SQLite world collections did not round-trip")
		quit(1)
		return
	if loaded.history.size() != 1 or String(loaded.history[0].champion_club_id) != String(history[0].champion_club_id):
		push_error("[TEST] SQLite history did not round-trip")
		quit(1)
		return
	_cleanup(path)
	print("[TEST] SQLITE PASS")
	quit(0)

func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
