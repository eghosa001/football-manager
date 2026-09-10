class_name SaveStore
extends RefCounted

const CURRENT_SCHEMA_VERSION := 1

func save_atomic(path: String, world: Dictionary, history: Array = []) -> Error:
	var payload := {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"world": world,
		"history": history,
	}
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	# store_var preserves integer/float types and nested Variant structure exactly,
	# which is important for deterministic save/reload continuation tests.
	file.store_var(payload, false)
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if remove_error != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
			return remove_error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))

func load_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = file.get_var(false)
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return _migrate(parsed)

func _migrate(payload: Dictionary) -> Dictionary:
	var version: int = int(payload.get("schema_version", 0))
	if version == 0:
		payload["history"] = payload.get("history", [])
		payload["schema_version"] = 1
		version = 1
	assert(version == CURRENT_SCHEMA_VERSION, "Unsupported save schema version: %d" % version)
	return payload
