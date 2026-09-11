class_name SqliteSaveStore
extends "res://persistence/save_store.gd"

const EXTENSION_PATH := "res://addons/godot-sqlite/gdsqlite.gdextension"
const CORE_COLLECTIONS := ["countries","clubs","players","competitions","contracts","fixtures"]
const AUX_COLLECTIONS := [
	"staff", "transfers", "injuries", "relationships", "news", "news_events", "awards", "legends",
	"player_history", "player_match_stats", "manager_history", "club_honours", "discipline",
	"manager_careers", "manager_job_market", "international_history", "international_player_records",
	"regions", "cities", "fixture_changes"
]
const NORMALIZED_COLLECTIONS := CORE_COLLECTIONS + AUX_COLLECTIONS
var _extension_resource: Resource

func is_available() -> bool:
	if ClassDB.class_exists(&"SQLite"): return true
	if not ResourceLoader.exists(EXTENSION_PATH): return false
	_extension_resource = ResourceLoader.load(EXTENSION_PATH)
	return _extension_resource != null and ClassDB.class_exists(&"SQLite")

func save_atomic(path: String, world: Dictionary, history: Array = []) -> Error:
	if not is_available(): return ERR_UNAVAILABLE
	var database = ClassDB.instantiate(&"SQLite")
	if database == null: return ERR_CANT_CREATE
	database.set("path", path)
	if not bool(database.call("open_db")): return ERR_CANT_OPEN
	if not _ensure_schema(database): database.call("close_db"); return FAILED

	var meta := world.duplicate(true)
	for collection in NORMALIZED_COLLECTIONS: meta.erase(collection)
	var meta_payload := _encode(meta)
	var history_payload := _encode(history)
	var legacy_payload := _encode({"schema_version":CURRENT_SCHEMA_VERSION,"world":world,"history":history})

	var ok := bool(database.call("query", "BEGIN IMMEDIATE;"))
	if ok:
		ok = bool(database.call("query_with_bindings", "INSERT INTO save_meta(slot,schema_version,world_meta,history_payload) VALUES(1,?,?,?) ON CONFLICT(slot) DO UPDATE SET schema_version=excluded.schema_version, world_meta=excluded.world_meta, history_payload=excluded.history_payload;", [CURRENT_SCHEMA_VERSION,meta_payload,history_payload]))
	if ok: ok = _clear_relational(database)
	if ok: ok = _save_countries(database, world.get("countries",[]))
	if ok: ok = _save_clubs(database, world.get("clubs",[]))
	if ok: ok = _save_players(database, world.get("players",[]))
	if ok: ok = _save_competitions(database, world.get("competitions",[]))
	if ok: ok = _save_contracts(database, world.get("contracts",[]))
	if ok: ok = _save_fixtures(database, world.get("fixtures",[]))
	if ok: ok = _save_aux(database, world)
	if ok:
		ok = bool(database.call("query_with_bindings", "INSERT INTO save_state(slot,schema_version,payload) VALUES(1,?,?) ON CONFLICT(slot) DO UPDATE SET schema_version=excluded.schema_version,payload=excluded.payload;", [CURRENT_SCHEMA_VERSION,legacy_payload]))
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
	if not _ensure_schema(database): database.call("close_db"); return {}
	if bool(database.call("query", "SELECT schema_version,world_meta,history_payload FROM save_meta WHERE slot=1;")):
		var meta_rows = database.get("query_result")
		if typeof(meta_rows) == TYPE_ARRAY and not meta_rows.is_empty():
			var meta = _decode(String(meta_rows[0].get("world_meta","")))
			var history = _decode(String(meta_rows[0].get("history_payload","")))
			if typeof(meta) == TYPE_DICTIONARY and typeof(history) == TYPE_ARRAY:
				var world: Dictionary = meta
				world["countries"] = _load_typed(database,"countries")
				world["clubs"] = _load_typed(database,"clubs")
				world["players"] = _load_typed(database,"players")
				world["competitions"] = _load_typed(database,"competitions")
				world["contracts"] = _load_typed(database,"contracts")
				world["fixtures"] = _load_typed(database,"fixtures")
				_load_aux(database,world)
				database.call("close_db")
				return _migrate({"schema_version":int(meta_rows[0].get("schema_version",CURRENT_SCHEMA_VERSION)),"world":world,"history":history})
	var legacy := _load_legacy(database)
	database.call("close_db")
	return legacy

func _ensure_schema(database) -> bool:
	var statements := [
		"PRAGMA foreign_keys=ON;",
		"CREATE TABLE IF NOT EXISTS save_meta (slot INTEGER PRIMARY KEY CHECK(slot=1), schema_version INTEGER NOT NULL, world_meta TEXT NOT NULL, history_payload TEXT NOT NULL);",
		"CREATE TABLE IF NOT EXISTS countries (id TEXT PRIMARY KEY, name TEXT NOT NULL, youth_rating INTEGER NOT NULL DEFAULT 50 CHECK(youth_rating BETWEEN 0 AND 100), payload TEXT NOT NULL);",
		"CREATE TABLE IF NOT EXISTS clubs (id TEXT PRIMARY KEY, country_id TEXT, name TEXT NOT NULL, reputation REAL NOT NULL DEFAULT 50 CHECK(reputation BETWEEN 0 AND 100), cash INTEGER NOT NULL DEFAULT 0, city_id TEXT, payload TEXT NOT NULL, FOREIGN KEY(country_id) REFERENCES countries(id) ON UPDATE CASCADE ON DELETE SET NULL);",
		"CREATE INDEX IF NOT EXISTS idx_clubs_country ON clubs(country_id);",
		"CREATE TABLE IF NOT EXISTS players (id TEXT PRIMARY KEY, club_id TEXT, country_id TEXT, name TEXT NOT NULL, age INTEGER NOT NULL DEFAULT 18 CHECK(age BETWEEN 14 AND 60), position TEXT NOT NULL DEFAULT '', current_ability INTEGER NOT NULL DEFAULT 1 CHECK(current_ability BETWEEN 0 AND 200), potential INTEGER NOT NULL DEFAULT 1 CHECK(potential BETWEEN 0 AND 200), retired INTEGER NOT NULL DEFAULT 0 CHECK(retired IN (0,1)), payload TEXT NOT NULL, FOREIGN KEY(club_id) REFERENCES clubs(id) ON UPDATE CASCADE ON DELETE SET NULL, FOREIGN KEY(country_id) REFERENCES countries(id) ON UPDATE CASCADE ON DELETE SET NULL);",
		"CREATE INDEX IF NOT EXISTS idx_players_club ON players(club_id);",
		"CREATE INDEX IF NOT EXISTS idx_players_country ON players(country_id);",
		"CREATE TABLE IF NOT EXISTS competitions (id TEXT PRIMARY KEY, country_id TEXT, name TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'league', season_year INTEGER NOT NULL DEFAULT 0, payload TEXT NOT NULL, FOREIGN KEY(country_id) REFERENCES countries(id) ON UPDATE CASCADE ON DELETE SET NULL);",
		"CREATE TABLE IF NOT EXISTS contracts (id TEXT PRIMARY KEY, player_id TEXT NOT NULL, club_id TEXT NOT NULL, start_year INTEGER NOT NULL DEFAULT 0, end_year INTEGER NOT NULL DEFAULT 0, wage INTEGER NOT NULL DEFAULT 0 CHECK(wage>=0), squad_status TEXT NOT NULL DEFAULT '', payload TEXT NOT NULL, FOREIGN KEY(player_id) REFERENCES players(id) ON UPDATE CASCADE ON DELETE CASCADE, FOREIGN KEY(club_id) REFERENCES clubs(id) ON UPDATE CASCADE ON DELETE CASCADE);",
		"CREATE INDEX IF NOT EXISTS idx_contracts_player ON contracts(player_id);",
		"CREATE INDEX IF NOT EXISTS idx_contracts_club ON contracts(club_id);",
		"CREATE TABLE IF NOT EXISTS fixtures (id TEXT PRIMARY KEY, competition_id TEXT, home_club_id TEXT NOT NULL, away_club_id TEXT NOT NULL, match_date TEXT NOT NULL, played INTEGER NOT NULL DEFAULT 0 CHECK(played IN (0,1)), home_goals INTEGER NOT NULL DEFAULT 0 CHECK(home_goals>=0), away_goals INTEGER NOT NULL DEFAULT 0 CHECK(away_goals>=0), payload TEXT NOT NULL, CHECK(home_club_id<>away_club_id), FOREIGN KEY(competition_id) REFERENCES competitions(id) ON UPDATE CASCADE ON DELETE SET NULL, FOREIGN KEY(home_club_id) REFERENCES clubs(id) ON UPDATE CASCADE ON DELETE CASCADE, FOREIGN KEY(away_club_id) REFERENCES clubs(id) ON UPDATE CASCADE ON DELETE CASCADE);",
		"CREATE INDEX IF NOT EXISTS idx_fixtures_comp_date ON fixtures(competition_id,match_date);",
		"CREATE TABLE IF NOT EXISTS entity_state (collection TEXT NOT NULL, ordinal INTEGER NOT NULL, entity_id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(collection,ordinal));",
		"CREATE INDEX IF NOT EXISTS idx_entity_state_id ON entity_state(collection,entity_id);",
		"CREATE TABLE IF NOT EXISTS save_state (slot INTEGER PRIMARY KEY CHECK(slot=1), schema_version INTEGER NOT NULL, payload TEXT NOT NULL);"
	]
	for statement in statements:
		if not bool(database.call("query",statement)): return false
	return true

func _clear_relational(database) -> bool:
	for table in ["contracts","fixtures","players","clubs","competitions","countries","entity_state"]:
		if not bool(database.call("query","DELETE FROM %s;" % table)): return false
	return true

func _save_countries(database, values: Array) -> bool:
	for i in range(values.size()):
		var v: Dictionary = values[i]
		var id := _entity_id(v,"country",i)
		if not bool(database.call("query_with_bindings","INSERT INTO countries(id,name,youth_rating,payload) VALUES(?,?,?,?);",[id,String(v.get("name",id)),clampi(int(v.get("youth_rating",50)),0,100),_encode(v)])): return false
	return true

func _save_clubs(database, values: Array) -> bool:
	for i in range(values.size()):
		var v: Dictionary = values[i]
		var id := _entity_id(v,"club",i)
		var country := _nullable_existing_id(database,"countries",String(v.get("country_id","")))
		if not bool(database.call("query_with_bindings","INSERT INTO clubs(id,country_id,name,reputation,cash,city_id,payload) VALUES(?,?,?,?,?,?,?);",[id,country,String(v.get("name",id)),clampf(float(v.get("reputation",50)),0.0,100.0),int(v.get("cash",0)),String(v.get("city_id","")),_encode(v)])): return false
	return true

func _save_players(database, values: Array) -> bool:
	for i in range(values.size()):
		var v: Dictionary = values[i]
		var id := _entity_id(v,"player",i)
		var club := _nullable_existing_id(database,"clubs",String(v.get("club_id","")))
		var country := _nullable_existing_id(database,"countries",String(v.get("country_id",v.get("nationality_id",""))))
		var name := String(v.get("name",String(v.get("first_name",""))+" "+String(v.get("last_name","")))).strip_edges()
		if name == "": name = id
		if not bool(database.call("query_with_bindings","INSERT INTO players(id,club_id,country_id,name,age,position,current_ability,potential,retired,payload) VALUES(?,?,?,?,?,?,?,?,?,?);",[id,club,country,name,clampi(int(v.get("age",18)),14,60),String(v.get("position","")),clampi(int(v.get("current_ability",1)),0,200),clampi(int(v.get("potential",v.get("current_ability",1))),0,200),1 if bool(v.get("retired",false)) else 0,_encode(v)])): return false
	return true

func _save_competitions(database, values: Array) -> bool:
	for i in range(values.size()):
		var v: Dictionary = values[i]
		var id := _entity_id(v,"competition",i)
		var country := _nullable_existing_id(database,"countries",String(v.get("country_id","")))
		if not bool(database.call("query_with_bindings","INSERT INTO competitions(id,country_id,name,type,season_year,payload) VALUES(?,?,?,?,?,?);",[id,country,String(v.get("name",id)),String(v.get("type","league")),int(v.get("season_year",0)),_encode(v)])): return false
	return true

func _save_contracts(database, values: Array) -> bool:
	for i in range(values.size()):
		var v: Dictionary = values[i]
		var player_id := String(v.get("player_id","")); var club_id := String(v.get("club_id",""))
		if player_id == "" or club_id == "" or not _id_exists(database,"players",player_id) or not _id_exists(database,"clubs",club_id): continue
		var id := _entity_id(v,"contract",i)
		if not bool(database.call("query_with_bindings","INSERT INTO contracts(id,player_id,club_id,start_year,end_year,wage,squad_status,payload) VALUES(?,?,?,?,?,?,?,?);",[id,player_id,club_id,int(v.get("start_year",0)),int(v.get("end_year",v.get("expiry_year",0))),maxi(0,int(v.get("wage",0))),String(v.get("squad_status","")),_encode(v)])): return false
	return true

func _save_fixtures(database, values: Array) -> bool:
	for i in range(values.size()):
		var v: Dictionary = values[i]
		var home := String(v.get("home_club_id",v.get("home_id",""))); var away := String(v.get("away_club_id",v.get("away_id","")))
		if home == "" or away == "" or home == away or not _id_exists(database,"clubs",home) or not _id_exists(database,"clubs",away): continue
		var competition := _nullable_existing_id(database,"competitions",String(v.get("competition_id","")))
		var id := _entity_id(v,"fixture",i)
		if not bool(database.call("query_with_bindings","INSERT INTO fixtures(id,competition_id,home_club_id,away_club_id,match_date,played,home_goals,away_goals,payload) VALUES(?,?,?,?,?,?,?,?,?);",[id,competition,home,away,String(v.get("date",v.get("match_date",""))),1 if bool(v.get("played",false)) else 0,maxi(0,int(v.get("home_goals",0))),maxi(0,int(v.get("away_goals",0))),_encode(v)])): return false
	return true

func _save_aux(database, world: Dictionary) -> bool:
	for collection in AUX_COLLECTIONS:
		var values = world.get(collection,[])
		if typeof(values) == TYPE_DICTIONARY: values = [{"id":collection,"value":values}]
		if typeof(values) != TYPE_ARRAY: continue
		for ordinal in range(values.size()):
			var value = values[ordinal]
			var entity_id := String(value.get("id","%s:%d" % [collection,ordinal])) if typeof(value)==TYPE_DICTIONARY else "%s:%d" % [collection,ordinal]
			if not bool(database.call("query_with_bindings","INSERT INTO entity_state(collection,ordinal,entity_id,payload) VALUES(?,?,?,?);",[collection,ordinal,entity_id,_encode(value)])): return false
	return true

func _load_typed(database, table: String) -> Array:
	var result: Array = []
	if not bool(database.call("query","SELECT payload FROM %s ORDER BY rowid ASC;" % table)): return result
	var rows = database.get("query_result")
	if typeof(rows) != TYPE_ARRAY: return result
	for row in rows:
		var value = _decode(String(row.get("payload","")))
		if value != null: result.append(value)
	return result

func _load_aux(database, world: Dictionary) -> void:
	for collection in AUX_COLLECTIONS: world[collection] = []
	if not bool(database.call("query","SELECT collection,ordinal,payload FROM entity_state ORDER BY collection ASC,ordinal ASC;")): return
	var rows = database.get("query_result")
	if typeof(rows) != TYPE_ARRAY: return
	for row in rows:
		var collection := String(row.get("collection",""))
		if collection not in AUX_COLLECTIONS: continue
		var value = _decode(String(row.get("payload","")))
		if value != null: world[collection].append(value)
	for collection in ["discipline","international_player_records"]:
		if world.get(collection,[]).size() == 1:
			var wrapper = world[collection][0]
			if typeof(wrapper)==TYPE_DICTIONARY and wrapper.has("value"): world[collection] = wrapper.value

func _id_exists(database, table: String, id: String) -> bool:
	if id == "": return false
	if not bool(database.call("query_with_bindings","SELECT id FROM %s WHERE id=? LIMIT 1;" % table,[id])): return false
	var rows = database.get("query_result")
	return typeof(rows)==TYPE_ARRAY and not rows.is_empty()

func _nullable_existing_id(database, table: String, id: String):
	return id if _id_exists(database,table,id) else null

func _entity_id(value: Dictionary, prefix: String, ordinal: int) -> String:
	var id := String(value.get("id",""))
	return id if id != "" else "%s:%d" % [prefix,ordinal]

func _load_legacy(database) -> Dictionary:
	if not bool(database.call("query","SELECT schema_version,payload FROM save_state WHERE slot=1;")): return {}
	var rows = database.get("query_result")
	if typeof(rows) != TYPE_ARRAY or rows.is_empty(): return {}
	var parsed = _decode(String(rows[0].get("payload","")))
	if typeof(parsed) != TYPE_DICTIONARY: return {}
	return _migrate(parsed)

func _encode(value) -> String:
	return Marshalls.raw_to_base64(var_to_bytes(value))

func _decode(text: String):
	if text.is_empty(): return null
	var raw := Marshalls.base64_to_raw(text)
	if raw.is_empty(): return null
	return bytes_to_var(raw)
