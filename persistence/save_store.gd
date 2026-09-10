class_name SaveStore
extends "res://persistence/save_repository.gd"

const CURRENT_SCHEMA_VERSION := 1

func save_atomic(path: String, world: Dictionary, history: Array = []) -> Error:
	var payload := {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"world": world,
		"history": history,
	}
	var temp_path := path + ".tmp"
	var backup_path := path + ".bak"
	var temp_global := ProjectSettings.globalize_path(temp_path)
	var save_global := ProjectSettings.globalize_path(path)
	var backup_global := ProjectSettings.globalize_path(backup_path)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(payload, false)
	file.flush()
	file.close()
	if _load_path(temp_path).is_empty():
		DirAccess.remove_absolute(temp_global)
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_global)
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.rename_absolute(save_global, backup_global)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_global)
			return backup_error
	var promote_error := DirAccess.rename_absolute(temp_global, save_global)
	if promote_error != OK:
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(backup_global, save_global)
		return promote_error
	return OK

func load_save(path: String) -> Dictionary:
	var primary := _load_path(path)
	if not primary.is_empty():
		return primary
	return _load_path(path + ".bak")

func _load_path(path: String) -> Dictionary:
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
	if version != CURRENT_SCHEMA_VERSION:
		return {}
	return payload
