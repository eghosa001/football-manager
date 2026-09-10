class_name ModLoader
extends RefCounted

const ALLOWED_ROOT_KEYS := ["clubs", "players", "countries", "competitions"]
const ALLOWED_PATCH_KEYS := {
	"clubs": ["name", "reputation", "ticket_price"],
	"players": ["first_name", "last_name", "current_ability", "potential", "position"],
	"countries": ["name", "code", "youth_rating"],
	"competitions": ["name", "points_win", "points_draw"],
}

func load_mod(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing_file", "patches": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "open_failed", "patches": {}}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_json", "patches": {}}
	var validation := validate_mod(parsed)
	if not validation.ok:
		return validation
	return {"ok": true, "error": "", "patches": parsed.get("patches", {}).duplicate(true), "metadata": parsed.get("metadata", {}).duplicate(true)}

func validate_mod(data: Dictionary) -> Dictionary:
	var patches = data.get("patches", {})
	if typeof(patches) != TYPE_DICTIONARY:
		return {"ok": false, "error": "patches_must_be_dictionary", "patches": {}}
	for root_key in patches.keys():
		if String(root_key) not in ALLOWED_ROOT_KEYS:
			return {"ok": false, "error": "unsupported_root:%s" % String(root_key), "patches": {}}
		var rows = patches[root_key]
		if typeof(rows) != TYPE_ARRAY:
			return {"ok": false, "error": "patch_list_required:%s" % String(root_key), "patches": {}}
		for patch in rows:
			if typeof(patch) != TYPE_DICTIONARY or not patch.has("id"):
				return {"ok": false, "error": "patch_id_required:%s" % String(root_key), "patches": {}}
			for key in patch.keys():
				if String(key) != "id" and String(key) not in ALLOWED_PATCH_KEYS[root_key]:
					return {"ok": false, "error": "unsupported_field:%s.%s" % [String(root_key), String(key)], "patches": {}}
	return {"ok": true, "error": "", "patches": patches.duplicate(true)}

func apply_mod(world: Dictionary, data: Dictionary) -> Dictionary:
	var validation := validate_mod(data)
	if not validation.ok:
		return {"ok": false, "applied": 0, "error": validation.error}
	var applied := 0
	var patches: Dictionary = data.get("patches", {})
	for root_key in patches.keys():
		var collection: Array = world.get(String(root_key), [])
		for patch in patches[root_key]:
			var target := _find(collection, String(patch.id))
			if target.is_empty():
				continue
			for key in patch.keys():
				if String(key) == "id":
					continue
				target[key] = _clamp_value(String(root_key), String(key), patch[key])
			applied += 1
	world["active_mods"] = world.get("active_mods", [])
	var metadata: Dictionary = data.get("metadata", {})
	if not metadata.is_empty():
		world.active_mods.append(metadata.duplicate(true))
	return {"ok": true, "applied": applied, "error": ""}

func _clamp_value(root_key: String, key: String, value):
	if key in ["reputation", "current_ability", "potential", "youth_rating"]:
		return clampi(int(value), 1, 100)
	if key == "ticket_price":
		return clampi(int(value), 1, 1000)
	if key in ["points_win", "points_draw"]:
		return clampi(int(value), 0, 10)
	return value

func _find(values: Array, id: String) -> Dictionary:
	for value in values:
		if String(value.get("id", "")) == id:
			return value
	return {}
