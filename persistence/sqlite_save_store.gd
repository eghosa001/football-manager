class_name SqliteSaveStore
extends "res://persistence/save_repository.gd"

const CURRENT_SCHEMA_VERSION := 1

func is_available() -> bool:
	return ClassDB.class_exists(&"SQLite")

func save_atomic(path: String, world: Dictionary, history: Array = []) -> Error:
	if not is_available():
		return ERR_UNAVAILABLE
	var database = ClassDB.instantiate(&"SQLite")
	if database == null:
		return ERR_CANT_CREATE
	database.set("path", path)
	if not bool(database.call("open_db")):
		return ERR_CANT_OPEN
	var payload_dict := {"schema_version": CURRENT_SCHEMA_VERSION, "world": world, "history": history}
	var payload: String = Marshalls.raw_to_base64(var_to_bytes(payload_dict))
	var ok := bool(database.call("query", "BEGIN IMMEDIATE;"))
	ok = ok and bool(database.call("query", "CREATE TABLE IF NOT EXISTS save_state (slot INTEGER PRIMARY KEY CHECK(slot = 1), schema_version INTEGER NOT NULL, payload TEXT NOT NULL);"))
	ok = ok and bool(database.call("query_with_bindings", "INSERT INTO save_state(slot, schema_version, payload) VALUES(1, ?, ?) ON CONFLICT(slot) DO UPDATE SET schema_version=excluded.schema_version, payload=excluded.payload;", [CURRENT_SCHEMA_VERSION, payload]))
	if ok:
		ok = bool(database.call("query", "COMMIT;"))
	else:
		database.call("query", "ROLLBACK;")
	database.call("close_db")
	return OK if ok else FAILED

func load_save(path: String) -> Dictionary:
	if not is_available():
		return {}
	var database = ClassDB.instantiate(&"SQLite")
	if database == null:
		return {}
	database.set("path", path)
	if not bool(database.call("open_db")):
		return {}
	if not bool(database.call("query", "CREATE TABLE IF NOT EXISTS save_state (slot INTEGER PRIMARY KEY CHECK(slot = 1), schema_version INTEGER NOT NULL, payload TEXT NOT NULL);")):
		database.call("close_db")
		return {}
	if not bool(database.call("query", "SELECT schema_version, payload FROM save_state WHERE slot = 1;")):
		database.call("close_db")
		return {}
	var rows = database.get("query_result")
	database.call("close_db")
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		return {}
	var raw: PackedByteArray = Marshalls.base64_to_raw(String(rows[0].payload))
	if raw.is_empty():
		return {}
	var parsed = bytes_to_var(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return _migrate(parsed)

func _migrate(payload: Dictionary) -> Dictionary:
	var version: int = int(payload.get("schema_version", 0))
	if version == 0:
		payload["history"] = payload.get("history", [])
		payload["schema_version"] = 1
		version = 1
	if version != CURRENT_SCHEMA_VERSION:
		return {}
	return payload
