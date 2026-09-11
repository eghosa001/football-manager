class_name SaveStore
extends "res://persistence/save_repository.gd"

const CURRENT_SCHEMA_VERSION := 4
const MAGIC := 1_179_016_753 # "FDN1"
const LEGACY_HEADER_BYTES := 8
const HEADER_BYTES := 12

func save_atomic(path: String, world: Dictionary, history: Array = []) -> Error:
	var payload := {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"world": world,
		"history": history,
	}
	var raw: PackedByteArray = var_to_bytes(payload)
	var checksum := int(hash(raw))
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
	file.store_32(checksum)
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
			if FileAccess.file_exists(backup_path):
				backup_error = DirAccess.remove_absolute(backup_global)
			if backup_error == OK:
				backup_error = DirAccess.rename_absolute(save_global, backup_global)
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
	if file == null or file.get_length() < LEGACY_HEADER_BYTES:
		if file != null: file.close()
		return {}
	if file.get_32() != MAGIC:
		file.close()
		return {}
	var payload_length: int = file.get_32()
	if payload_length <= 0:
		file.close()
		return {}
	var remaining := int(file.get_length() - LEGACY_HEADER_BYTES)
	var expected_checksum := -1
	if remaining == payload_length + 4:
		expected_checksum = int(file.get_32())
	elif remaining != payload_length:
		file.close()
		return {}
	var raw: PackedByteArray = file.get_buffer(payload_length)
	file.close()
	if raw.size() != payload_length:
		return {}
	if expected_checksum >= 0 and int(hash(raw)) != expected_checksum:
		return {}
	var parsed = bytes_to_var(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return _migrate(parsed)

func _migrate(payload: Dictionary) -> Dictionary:
	if not payload.get("world") is Dictionary or not payload.get("history", []) is Array:
		return {}
	if not payload.get("schema_version", 0) is int:
		return {}
	var version: int = int(payload.get("schema_version", 0))
	if version > CURRENT_SCHEMA_VERSION:
		return {}
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
		world_v2["discipline"] = world_v2.get("discipline", {})
		world_v2["manager_job_market"] = world_v2.get("manager_job_market", [])
		world_v2["international_history"] = world_v2.get("international_history", [])
		world_v2["cities"] = world_v2.get("cities", [])
		world_v2["regions"] = world_v2.get("regions", [])
		world_v2["fixture_changes"] = world_v2.get("fixture_changes", [])
		world_v2["economic_indices"] = world_v2.get("economic_indices", {"wage":1.0,"transfer":1.0,"broadcast":1.0})
		payload["world"] = world_v2
		payload["schema_version"] = 3
		version = 3
	if version == 3:
		var world_v3: Dictionary = payload.get("world", {})
		world_v3["default_country_id"] = world_v3.get("default_country_id", "eng")
		world_v3["featured_country_ids"] = world_v3.get("featured_country_ids", ["eng", "esp"])
		var manager_ability := {}
		for staff_member in world_v3.get("staff", []):
			if String(staff_member.get("role", "")) == "manager":
				manager_ability[String(staff_member.get("club_id", ""))] = int(staff_member.get("ability", 50))
		for club in world_v3.get("clubs", []):
			club["recent_results"] = club.get("recent_results", [])
			club["form_points"] = club.get("form_points", 7.5)
			club["injured_count"] = club.get("injured_count", 0)
			if not club.has("manager_ability"):
				club["manager_ability"] = int(manager_ability.get(String(club.get("id", "")), 50))
		for competition in world_v3.get("competitions", []):
			if bool(competition.get("continental", false)) and not competition.has("continental_tier"):
				competition["continental_tier"] = 1
		payload["world"] = world_v3
		payload["schema_version"] = 4
		version = 4
	if version != CURRENT_SCHEMA_VERSION:
		return {}
	return payload
