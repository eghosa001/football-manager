class_name SqliteSaveStore
extends "res://persistence/save_store.gd"

const EXTENSION_PATH := "res://addons/godot-sqlite/gdsqlite.gdextension"
const NORMALIZED_COLLECTIONS := [
	"countries", "clubs", "players", "staff", "contracts", "competitions", "fixtures",
	"transfers", "injuries", "relationships", "news", "news_events", "awards", "legends",
	"player_history", "player_match_stats", "manager_history", "club_honours",
]
var _extension_resource: Resource

func is_available() -> bool:
	if ClassDB.class_exists(&"SQLite"):
		return true
	if not ResourceLoader.exists(EXTENSION_PATH):
		return false
	_extension_resource = ResourceLoader.load(EXTENSION_PATH)
	return _extension_resource != null and ClassDB.class_exists(&"SQLite")

func save_atomic(path: String, world: Dictionary, history: Array = []) -> Error:
	if not is_available(): return ERR_UNAVAILABLE
	var database = ClassDB.instantiate(&"SQLite")
	if database == null: return ERR_CANT_CREATE
	database.set("path", path)
	if not bool(database.call("open_db")): return ERR_CANT_OPEN

	var meta := world.duplicate(true)
	for collection in NORMALIZED_COLLECTIONS: meta.erase(collection)
	var meta_payload := _encode(meta)
	var history_payload := _encode(history)
	# Keep the legacy aggregate payload for downgrade/backward compatibility while
	# normalized rows are the canonical representation for current builds.
	var legacy_payload := _encode({"schema_version":CURRENT_SCHEMA_VERSION,"world":world,"history":history})

	var ok := bool(database.call("query", "BEGIN IMMEDIATE;"))
	ok = ok and bool(database.call("query", "CREATE TABLE IF NOT EXISTS save_meta (slot INTEGER PRIMARY KEY CHECK(slot = 1), schema_version INTEGER NOT NULL, world_meta TEXT NOT NULL, history_payload TEXT NOT NULL);"))
	ok = ok and bool(database.call("query", "CREATE TABLE IF NOT EXISTS entity_state (collection TEXT NOT NULL, ordinal INTEGER NOT NULL, entity_id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(collection, ordinal));"))
	ok = ok and bool(database.call("query", "CREATE INDEX IF NOT EXISTS idx_entity_state_id ON entity_state(collection, entity_id);"))
	ok = ok and bool(database.call("query", "CREATE TABLE IF NOT EXISTS save_state (slot INTEGER PRIMARY KEY CHECK(slot = 1), schema_version INTEGER NOT NULL, payload TEXT NOT NULL);"))
	if ok:
		ok = bool(database.call("query_with_bindings", "INSERT INTO save_meta(slot, schema_version, world_meta, history_payload) VALUES(1, ?, ?, ?) ON CONFLICT(slot) DO UPDATE SET schema_version=excluded.schema_version, world_meta=excluded.world_meta, history_payload=excluded.history_payload;", [CURRENT_SCHEMA_VERSION, meta_payload, history_payload]))
	if ok:
		ok = bool(database.call("query", "DELETE FROM entity_state;"))
	if ok:
		for collection in NORMALIZED_COLLECTIONS:
			var values = world.get(collection, [])
			if typeof(values) != TYPE_ARRAY: continue
			for ordinal in range(values.size()):
				var value = values[ordinal]
				var entity_id := String(value.get("id", "%s:%d" % [collection, ordinal])) if typeof(value) == TYPE_DICTIONARY else "%s:%d" % [collection, ordinal]
				if not bool(database.call("query_with_bindings", "INSERT INTO entity_state(collection, ordinal, entity_id, payload) VALUES(?, ?, ?, ?);", [collection, ordinal, entity_id, _encode(value)])):
					ok = false
					break
			if not ok: break
	if ok:
		ok = bool(database.call("query_with_bindings", "INSERT INTO save_state(slot, schema_version, payload) VALUES(1, ?, ?) ON CONFLICT(slot) DO UPDATE SET schema_version=excluded.schema_version, payload=excluded.payload;", [CURRENT_SCHEMA_VERSION, legacy_payload]))
	if ok: ok = bool(database.call("query", "COMMIT;"))
	else: database.call("query", "ROLLBACK;")
	database.call("close_db")
	return OK if ok else FAILED

func load_save(path: String) -> Dictionary:
	if not is_available(): return {}
	var database = ClassDB.instantiate(&"SQLite")
	if database == null: return {}
	database.set("path", path)
	if not bool(database.call("open_db")): return {}

	# Create current tables non-destructively; an older one-blob save will simply
	# have no save_meta row and fall through to the legacy loader below.
	if not bool(database.call("query", "CREATE TABLE IF NOT EXISTS save_meta (slot INTEGER PRIMARY KEY CHECK(slot = 1), schema_version INTEGER NOT NULL, world_meta TEXT NOT NULL, history_payload TEXT NOT NULL);")):
		database.call("close_db"); return {}
	if not bool(database.call("query", "CREATE TABLE IF NOT EXISTS entity_state (collection TEXT NOT NULL, ordinal INTEGER NOT NULL, entity_id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(collection, ordinal));")):
		database.call("close_db"); return {}
	if bool(database.call("query", "SELECT schema_version, world_meta, history_payload FROM save_meta WHERE slot = 1;")):
		var meta_rows = database.get("query_result")
		if typeof(meta_rows) == TYPE_ARRAY and not meta_rows.is_empty():
			var meta = _decode(String(meta_rows[0].get("world_meta", "")))
			var history = _decode(String(meta_rows[0].get("history_payload", "")))
			if typeof(meta) == TYPE_DICTIONARY and typeof(history) == TYPE_ARRAY:
				var world: Dictionary = meta
				for collection in NORMALIZED_COLLECTIONS: world[collection] = []
				if bool(database.call("query", "SELECT collection, ordinal, payload FROM entity_state ORDER BY collection ASC, ordinal ASC;")):
					var entity_rows = database.get("query_result")
					if typeof(entity_rows) == TYPE_ARRAY:
						for row in entity_rows:
							var collection := String(row.get("collection", ""))
							if collection not in NORMALIZED_COLLECTIONS: continue
							var value = _decode(String(row.get("payload", "")))
							if value != null: world[collection].append(value)
						database.call("close_db")
						return _migrate({"schema_version":int(meta_rows[0].get("schema_version", CURRENT_SCHEMA_VERSION)),"world":world,"history":history})

	var legacy := _load_legacy(database)
	database.call("close_db")
	return legacy

func _load_legacy(database) -> Dictionary:
	if not bool(database.call("query", "CREATE TABLE IF NOT EXISTS save_state (slot INTEGER PRIMARY KEY CHECK(slot = 1), schema_version INTEGER NOT NULL, payload TEXT NOT NULL);")): return {}
	if not bool(database.call("query", "SELECT schema_version, payload FROM save_state WHERE slot = 1;")): return {}
	var rows = database.get("query_result")
	if typeof(rows) != TYPE_ARRAY or rows.is_empty(): return {}
	var parsed = _decode(String(rows[0].get("payload", "")))
	if typeof(parsed) != TYPE_DICTIONARY: return {}
	return _migrate(parsed)

func _encode(value) -> String:
	return Marshalls.raw_to_base64(var_to_bytes(value))

func _decode(text: String):
	if text.is_empty(): return null
	var raw := Marshalls.base64_to_raw(text)
	if raw.is_empty(): return null
	return bytes_to_var(raw)
