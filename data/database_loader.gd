class_name DatabaseLoader
extends RefCounted

func load_seed(path: String = "res://data/seed/launch_database.json") -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version",0)) != 1: return {}
	return parsed

func validate_seed(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var country_ids := {}
	for country in data.get("countries", []):
		var id := String(country.get("id", ""))
		if id == "" or country_ids.has(id): errors.append("invalid/duplicate country id: %s" % id)
		country_ids[id] = true
	var templates := {}
	for template in data.get("competition_templates", []):
		var template_id := String(template.get("id", ""))
		if template_id == "" or templates.has(template_id): errors.append("invalid/duplicate competition template: %s" % template_id)
		templates[template_id] = template
		if int(template.get("teams", 0)) < 2: errors.append("competition template requires at least two teams")
	for system in data.get("league_systems", []):
		var country_id := String(system.get("country_id", ""))
		if not country_ids.has(country_id): errors.append("league system references unknown country: %s" % country_id)
		var tier_names := {}
		for tier in system.get("tiers", []):
			var name := String(tier.get("name", ""))
			if name == "" or tier_names.has(name): errors.append("invalid/duplicate tier name for %s: %s" % [country_id,name])
			tier_names[name] = true
			if not templates.has(String(tier.get("template", ""))): errors.append("tier references unknown template: %s" % String(tier.get("template", "")))
		var cup: Dictionary = system.get("cup", {})
		if not cup.is_empty() and not templates.has(String(cup.get("template", ""))): errors.append("cup references unknown template: %s" % String(cup.get("template", "")))
	var registration: Dictionary = data.get("registration_defaults", {})
	if int(registration.get("max_squad",0)) < int(registration.get("homegrown_required",0)): errors.append("homegrown requirement exceeds maximum squad size")
	return errors

func template_by_id(data: Dictionary, template_id: String) -> Dictionary:
	for template in data.get("competition_templates", []):
		if String(template.get("id", "")) == template_id: return template
	return {}

func league_system(data: Dictionary, country_id: String) -> Dictionary:
	for system in data.get("league_systems", []):
		if String(system.get("country_id", "")) == country_id: return system
	return {}
