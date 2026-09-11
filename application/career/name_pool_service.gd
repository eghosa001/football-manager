class_name NamePoolService
extends RefCounted

const DEFAULT_FIRST := ["Daniel","Victor","Samuel","David","Ibrahim","Michael","Joseph","Emmanuel","Tobi","Kelvin","Musa","Peter","Ahmed","John","Chinedu","Seyi","Kwame","Kofi","Amadou","Youssef","Thabo","Sipho","Omar","Idris"]
const DEFAULT_LAST := ["Okoro","Mensah","Diallo","Banda","Mokoena","Abdullahi","Adeyemi","Kamara","Ndlovu","Boateng","Ibrahim","Dlamini","Osei","Eze","Sow","Yusuf","Traore","Benali","Nkosi","Abebe"]

func apply_mod_names(world: Dictionary, mods: Array) -> Dictionary:
	world["name_pools"] = world.get("name_pools", {})
	var applied := 0
	for mod in mods:
		if typeof(mod) != TYPE_DICTIONARY: continue
		var names = mod.get("names", {})
		if typeof(names) != TYPE_DICTIONARY: continue
		for country_id in names.keys():
			var pool = names[country_id]
			if typeof(pool) != TYPE_DICTIONARY: continue
			var first := _clean(pool.get("first", pool.get("first_names", [])))
			var last := _clean(pool.get("last", pool.get("last_names", [])))
			if first.is_empty() and last.is_empty(): continue
			world.name_pools[String(country_id)] = {"first":first,"last":last}
			applied += 1
	return {"applied":applied}

func rename_youth(world: Dictionary, player_ids: Array, seed: int) -> void:
	world["name_pools"] = world.get("name_pools", {})
	for player_id in player_ids:
		var player := _player(world, String(player_id))
		if player.is_empty(): continue
		var country_id := String(player.get("country_id", "default"))
		var pool: Dictionary = world.name_pools.get(country_id, world.name_pools.get("default", {}))
		var first: Array = pool.get("first", DEFAULT_FIRST)
		var last: Array = pool.get("last", DEFAULT_LAST)
		if first.is_empty(): first = DEFAULT_FIRST
		if last.is_empty(): last = DEFAULT_LAST
		var key := _stable_key(String(player.id))
		player["first_name"] = String(first[posmod(seed + key * 17, first.size())])
		player["last_name"] = String(last[posmod(seed * 3 + key * 31, last.size())])

func validate_names(names) -> Dictionary:
	if typeof(names) != TYPE_DICTIONARY: return {"ok":false,"error":"names_must_be_dictionary"}
	for country_id in names.keys():
		if String(country_id).strip_edges().is_empty() or typeof(names[country_id]) != TYPE_DICTIONARY: return {"ok":false,"error":"invalid_name_pool"}
		for key in ["first","first_names","last","last_names"]:
			if not names[country_id].has(key): continue
			if typeof(names[country_id][key]) != TYPE_ARRAY: return {"ok":false,"error":"name_pool_array_required"}
			for value in names[country_id][key]:
				if not value is String or String(value).strip_edges().is_empty(): return {"ok":false,"error":"invalid_name"}
	return {"ok":true,"error":""}

func _clean(values) -> Array:
	var out: Array = []
	if typeof(values) != TYPE_ARRAY: return out
	for value in values:
		if value is String and not String(value).strip_edges().is_empty(): out.append(String(value).strip_edges())
	return out

func _player(world: Dictionary, id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == id: return player
	return {}

func _stable_key(text: String) -> int:
	var value := 47
	for character in text.to_utf8_buffer(): value = posmod(value * 167 + int(character), 2_147_483_647)
	return value
