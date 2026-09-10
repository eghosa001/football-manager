class_name ModLoader
extends RefCounted

const SUPPORTED_API_VERSION := 2
const ALLOWED_ROOT_KEYS := ["clubs", "players", "staff", "countries", "competitions"]
const ALLOWED_PATCH_KEYS := {
	"clubs": ["name", "reputation", "ticket_price", "training_facilities", "stadium_capacity", "tier", "facilities", "board", "supporters"],
	"players": ["first_name", "last_name", "current_ability", "potential", "position", "country_id", "preferred_foot", "weak_foot", "height_cm", "weight_kg", "traits", "position_familiarity", "attributes", "hidden_attributes"],
	"staff": ["name", "role", "ability", "reputation", "staff_attributes", "manager_profile"],
	"countries": ["name", "code", "youth_rating"],
	"competitions": ["name", "points_win", "points_draw", "tier", "promotion_places", "relegation_places", "registration_rules", "rules"],
}

func load_mod(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok":false,"error":"missing_file","patches":{}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok":false,"error":"open_failed","patches":{}}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY: return {"ok":false,"error":"invalid_json","patches":{}}
	var validation := validate_mod(parsed)
	if not validation.ok: return validation
	return {"ok":true,"error":"","patches":parsed.get("patches",{}).duplicate(true),"metadata":parsed.get("metadata",{}).duplicate(true)}

func validate_mod(data: Dictionary) -> Dictionary:
	var metadata = data.get("metadata", {})
	if typeof(metadata) != TYPE_DICTIONARY: return {"ok":false,"error":"metadata_must_be_dictionary","patches":{}}
	if String(metadata.get("id", "")).strip_edges() == "": return {"ok":false,"error":"metadata_id_required","patches":{}}
	if int(metadata.get("api_version", SUPPORTED_API_VERSION)) > SUPPORTED_API_VERSION: return {"ok":false,"error":"unsupported_api_version","patches":{}}
	for key in ["dependencies","conflicts"]:
		if metadata.has(key) and typeof(metadata[key]) != TYPE_ARRAY: return {"ok":false,"error":"metadata_%s_must_be_array" % key,"patches":{}}
	var patches = data.get("patches", {})
	if typeof(patches) != TYPE_DICTIONARY: return {"ok":false,"error":"patches_must_be_dictionary","patches":{}}
	for root_key in patches.keys():
		if String(root_key) not in ALLOWED_ROOT_KEYS: return {"ok":false,"error":"unsupported_root:%s" % String(root_key),"patches":{}}
		var rows = patches[root_key]
		if typeof(rows) != TYPE_ARRAY: return {"ok":false,"error":"patch_list_required:%s" % String(root_key),"patches":{}}
		for patch in rows:
			if typeof(patch) != TYPE_DICTIONARY or not patch.has("id"): return {"ok":false,"error":"patch_id_required:%s" % String(root_key),"patches":{}}
			for field in patch.keys():
				if String(field) != "id" and String(field) not in ALLOWED_PATCH_KEYS[root_key]: return {"ok":false,"error":"unsupported_field:%s.%s" % [String(root_key),String(field)],"patches":{}}
	return {"ok":true,"error":"","patches":patches.duplicate(true)}

func validate_load_order(mods: Array) -> Dictionary:
	var ids := {}
	for mod in mods:
		var metadata: Dictionary = mod.get("metadata", {})
		var id := String(metadata.get("id", ""))
		if id == "": return {"ok":false,"error":"metadata_id_required"}
		if ids.has(id): return {"ok":false,"error":"duplicate_mod:%s" % id}
		ids[id] = metadata
	for id in ids.keys():
		var metadata: Dictionary = ids[id]
		for dependency in metadata.get("dependencies", []):
			if not ids.has(String(dependency)): return {"ok":false,"error":"missing_dependency:%s:%s" % [String(id),String(dependency)]}
		for conflict in metadata.get("conflicts", []):
			if ids.has(String(conflict)): return {"ok":false,"error":"mod_conflict:%s:%s" % [String(id),String(conflict)]}
	return {"ok":true,"error":""}

func apply_mods(world: Dictionary, mods: Array) -> Dictionary:
	var order := validate_load_order(mods)
	if not order.ok: return {"ok":false,"applied":0,"error":order.error}
	var total := 0
	for mod in mods:
		var result := apply_mod(world, mod)
		if not result.ok: return {"ok":false,"applied":total,"error":result.error}
		total += int(result.applied)
	return {"ok":true,"applied":total,"error":""}

func apply_mod(world: Dictionary, data: Dictionary) -> Dictionary:
	var validation := validate_mod(data)
	if not validation.ok: return {"ok":false,"applied":0,"error":validation.error}
	var applied := 0
	var patches: Dictionary = data.get("patches", {})
	for root_key in patches.keys():
		var collection: Array = world.get(String(root_key), [])
		for patch in patches[root_key]:
			var target := _find(collection, String(patch.id))
			if target.is_empty(): continue
			for key in patch.keys():
				if String(key) == "id": continue
				target[key] = _sanitize_value(String(root_key), String(key), patch[key])
			applied += 1
	world["active_mods"] = world.get("active_mods", [])
	var metadata: Dictionary = data.get("metadata", {})
	if not metadata.is_empty(): world.active_mods.append(metadata.duplicate(true))
	return {"ok":true,"applied":applied,"error":""}

func _sanitize_value(root_key: String, key: String, value):
	if key in ["reputation","current_ability","potential","youth_rating","weak_foot","ability"]: return clampi(int(value),1,100)
	if key == "ticket_price": return clampi(int(value),1,1000)
	if key in ["points_win","points_draw","tier","promotion_places","relegation_places"]: return maxi(0,int(value))
	if key == "height_cm": return clampi(int(value),150,220)
	if key == "weight_kg": return clampi(int(value),45,140)
	if key in ["attributes","hidden_attributes"] and typeof(value) == TYPE_DICTIONARY:
		var clean := {}
		for attribute in value.keys(): clean[String(attribute)] = clampi(int(value[attribute]),1,100)
		return clean
	return value

func _find(values: Array, id: String) -> Dictionary:
	for value in values:
		if String(value.get("id", "")) == id: return value
	return {}
