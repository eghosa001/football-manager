class_name SaveStore
extends "res://persistence/save_repository.gd"

const CURRENT_SCHEMA_VERSION := 3
const MAGIC := 1_179_016_753 # "FDN1"
const HEADER_BYTES := 8

func save_atomic(path: String, world: Dictionary, history: Array = []) -> Error:
	var payload := {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"save_metadata": _save_metadata(),
		"world": world,
		"history": history,
	}
	var raw: PackedByteArray = var_to_bytes(payload)
	var temp_path := path + ".tmp"
	var backup_path := path + ".bak"
	var temp_global := ProjectSettings.globalize_path(temp_path)
	var save_global := ProjectSettings.globalize_path(path)
	var backup_global := ProjectSettings.globalize_path(backup_path)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_32(MAGIC)
	file.store_32(raw.size())
	file.store_buffer(raw)
	file.flush()
	file.close()
	if _load_path(temp_path).is_empty():
		DirAccess.remove_absolute(temp_global)
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(path):
		var backup_error: Error = OK
		if _load_path(path).is_empty():
			backup_error = DirAccess.remove_absolute(save_global)
		else:
			if FileAccess.file_exists(backup_path): backup_error = DirAccess.remove_absolute(backup_global)
			if backup_error == OK: backup_error = DirAccess.rename_absolute(save_global, backup_global)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_global)
			return backup_error
	var promote_error := DirAccess.rename_absolute(temp_global, save_global)
	if promote_error != OK:
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(path): DirAccess.rename_absolute(backup_global, save_global)
		return promote_error
	return OK

func load_save(path: String) -> Dictionary:
	var primary := _load_path(path)
	if not primary.is_empty(): return primary
	return _load_path(path + ".bak")

func _load_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < HEADER_BYTES:
		if file != null: file.close()
		return {}
	if file.get_32() != MAGIC:
		file.close(); return {}
	var payload_length: int = file.get_32()
	if payload_length <= 0 or payload_length > file.get_length() - HEADER_BYTES:
		file.close(); return {}
	var raw: PackedByteArray = file.get_buffer(payload_length)
	file.close()
	if raw.size() != payload_length: return {}
	var parsed = bytes_to_var(raw)
	if typeof(parsed) != TYPE_DICTIONARY: return {}
	return _migrate(parsed)

func _migrate(payload: Dictionary) -> Dictionary:
	if not payload.get("world") is Dictionary or not payload.get("history", []) is Array: return {}
	if not payload.get("schema_version", 0) is int: return {}
	var version: int = int(payload.get("schema_version", 0))
	if version < 0 or version > CURRENT_SCHEMA_VERSION: return {}
	if version == 0:
		payload["history"] = payload.get("history", [])
		payload["schema_version"] = 1
		version = 1
	if version == 1:
		var world_v1: Dictionary = payload.get("world", {})
		world_v1["relationships"] = world_v1.get("relationships", [])
		world_v1["rivalries"] = world_v1.get("rivalries", [])
		world_v1["awards"] = world_v1.get("awards", [])
		world_v1["legends"] = world_v1.get("legends", [])
		world_v1["news"] = world_v1.get("news", [])
		world_v1["manager_careers"] = world_v1.get("manager_careers", [])
		world_v1["active_mods"] = world_v1.get("active_mods", [])
		payload["world"] = world_v1
		payload["schema_version"] = 2
		version = 2
	if version == 2:
		var world_v2: Dictionary = payload.get("world", {})
		for player in world_v2.get("players", []):
			player["individual_training_focus"] = String(player.get("individual_training_focus", "none"))
		world_v2["save_capabilities"] = world_v2.get("save_capabilities", ["desktop", "android", "ios", "offline"])
		payload["world"] = world_v2
		payload["save_metadata"] = payload.get("save_metadata", _legacy_metadata())
		payload["schema_version"] = 3
		version = 3
	if version != CURRENT_SCHEMA_VERSION: return {}
	if not payload.get("save_metadata", {}) is Dictionary: return {}
	var world: Dictionary = payload.world
	for player in world.get("players", []):
		if not player.has("individual_training_focus"): player["individual_training_focus"] = "none"
	world["save_capabilities"] = world.get("save_capabilities", ["desktop", "android", "ios", "offline"])
	payload["world"] = world
	return payload

func _save_metadata() -> Dictionary:
	return {
		"format":"football-dynasty-portable",
		"format_version":1,
		"application_version":String(ProjectSettings.get_setting("application/config/version", "unknown")),
		"godot_version":Engine.get_version_info().get("string", "unknown"),
		"platform":OS.get_name(),
		"portable":true,
	}

func _legacy_metadata() -> Dictionary:
	return {"format":"football-dynasty-portable","format_version":1,"application_version":"pre-v3","godot_version":"unknown","platform":"unknown","portable":true}
