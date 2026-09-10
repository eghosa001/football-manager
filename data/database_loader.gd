class_name DatabaseLoader
extends RefCounted

func load_seed(path: String = "res://data/seed/launch_database.json") -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if int(parsed.get("schema_version", 0)) != 1:
		return {}
	return parsed

func validate_seed(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var ids := {}
	for country in data.get("countries", []):
		var id := String(country.get("id", ""))
		if id == "" or ids.has(id):
			errors.append("invalid/duplicate country id: %s" % id)
		ids[id] = true
	for template in data.get("competition_templates", []):
		if int(template.get("teams", 0)) < 2:
			errors.append("competition template requires at least two teams")
	return errors
