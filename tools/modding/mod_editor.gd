class_name ModEditor
extends RefCounted

const ModLoaderClass = preload("res://tools/modding/mod_loader.gd")

var _loader = ModLoaderClass.new()

func create_mod(id: String, name: String, version: String = "1.0") -> Dictionary:
	return {
		"metadata": {
			"id": id.strip_edges(),
			"name": name.strip_edges(),
			"version": version.strip_edges(),
		},
		"patches": {},
	}

func add_patch(mod: Dictionary, collection: String, entity_id: String, values: Dictionary) -> Dictionary:
	var candidate: Dictionary = mod.duplicate(true)
	if not candidate.has("patches") or typeof(candidate.patches) != TYPE_DICTIONARY:
		candidate["patches"] = {}
	if not candidate.patches.has(collection):
		candidate.patches[collection] = []
	var patch := {"id": entity_id}
	for key in values.keys():
		patch[String(key)] = values[key]
	candidate.patches[collection].append(patch)
	var validation: Dictionary = _loader.validate_mod(candidate)
	if not validation.ok:
		return {"ok": false, "error": validation.error, "mod": mod.duplicate(true)}
	return {"ok": true, "error": "", "mod": candidate}

func export_mod(path: String, mod: Dictionary) -> Error:
	var validation: Dictionary = _loader.validate_mod(mod)
	if not validation.ok:
		return ERR_INVALID_DATA
	var metadata: Dictionary = mod.get("metadata", {})
	if String(metadata.get("id", "")).strip_edges() == "" or String(metadata.get("version", "")).strip_edges() == "":
		return ERR_INVALID_DATA
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(mod, "\t", false))
	file.flush()
	file.close()
	return OK

func import_mod(path: String) -> Dictionary:
	return _loader.load_mod(path)
