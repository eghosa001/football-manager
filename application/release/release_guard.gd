class_name ReleaseGuard
extends RefCounted

const PRODUCT_NAME := "Football Dynasty"
const RELEASE_CHANNEL := "rc"
const SAVE_SCHEMA_VERSION := 2

func manifest() -> Dictionary:
	return {
		"product": PRODUCT_NAME,
		"channel": RELEASE_CHANNEL,
		"engine": "4.7.2",
		"save_schema": SAVE_SCHEMA_VERSION,
		"offline_required": true,
		"platforms": ["windows", "linux"],
	}

func validate_world(world: Dictionary) -> Array:
	var errors: Array = []
	for key in ["countries", "clubs", "players", "staff", "competitions", "contracts", "fixtures"]:
		if not world.has(key) or typeof(world[key]) != TYPE_ARRAY:
			errors.append("missing_or_invalid:%s" % key)
	var ids := {}
	for collection_name in ["countries", "clubs", "players", "staff", "competitions", "contracts", "fixtures"]:
		for item in world.get(collection_name, []):
			var id := String(item.get("id", ""))
			if id == "":
				errors.append("missing_id:%s" % collection_name)
			elif ids.has(id):
				errors.append("duplicate_id:%s" % id)
			else:
				ids[id] = true
	return errors

func validate_release_files() -> Array:
	var errors: Array = []
	for path in ["res://project.godot", "res://export_presets.cfg", "res://game/scenes/main.tscn", "res://README.md"]:
		if not FileAccess.file_exists(path):
			errors.append("missing_release_file:%s" % path)
	return errors

func offline_contract() -> Dictionary:
	return {
		"requires_network": false,
		"save_backend": "local",
		"external_service_required": false,
	}
