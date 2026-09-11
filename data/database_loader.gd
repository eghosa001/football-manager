class_name DatabaseLoader
extends RefCounted

const DEFAULT_COUNTRY_ID := "eng"
const FEATURED_COUNTRY_IDS := ["eng", "esp"]

func load_seed(path: String = "res://data/seed/launch_database.json", expanded: bool = false) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version",0)) != 1: return {}
	if expanded:
		var extra = JSON.parse_string(FileAccess.get_file_as_string("res://data/seed/expanded_countries.json"))
		if not extra is Array: return {}
		for country in extra:
			parsed.countries.append(country)
			parsed.league_systems.append({"country_id":country.id,"tiers":[{"name":"Premier Division","template":"league-18","promotion":0,"relegation":3},{"name":"Second Division","template":"league-18","promotion":3,"relegation":0}],"cup":{"name":"National Cup","template":"cup-32"}})
	return parsed

func club_name(country: Dictionary, index: int, tier: int) -> String:
	var words := ["United","City","Athletic","Rovers","Stars","Dynamos","Warriors","Sporting","Rangers","Lions"]
	var cities: Array = country.get("cities", [])
	if not cities.is_empty(): return "%s %s" % [cities[index % cities.size()], words[(index / cities.size() + (tier - 1) * 2) % words.size()]]
	return "%s %s %d" % [String(country.name), words[index % words.size()], index + 1]

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

func default_country_id(data: Dictionary) -> String:
	var configured := String(data.get("default_country_id", ""))
	if configured != "" and has_country(data, configured): return configured
	if has_country(data, DEFAULT_COUNTRY_ID): return DEFAULT_COUNTRY_ID
	var countries: Array = data.get("countries", [])
	if countries.is_empty(): return ""
	return String(countries[0].get("id", ""))

func featured_country_ids(data: Dictionary) -> Array:
	var configured: Array = data.get("featured_country_ids", [])
	var result: Array = []
	for id in configured:
		if has_country(data, String(id)) and String(id) not in result: result.append(String(id))
	for id in FEATURED_COUNTRY_IDS:
		if has_country(data, String(id)) and String(id) not in result: result.append(String(id))
	var fallback := default_country_id(data)
	if fallback != "" and fallback not in result: result.push_front(fallback)
	return result

func has_country(data: Dictionary, country_id: String) -> bool:
	for country in data.get("countries", []):
		if String(country.get("id", "")) == country_id: return true
	return false

func ordered_countries(data: Dictionary) -> Array:
	var featured := featured_country_ids(data)
	var result: Array = []
	for id in featured:
		for country in data.get("countries", []):
			if String(country.get("id", "")) == id: result.append(country)
	for country in data.get("countries", []):
		if String(country.get("id", "")) not in featured: result.append(country)
	return result

func league_system(data: Dictionary, country_id: String) -> Dictionary:
	for system in data.get("league_systems", []):
		if String(system.get("country_id", "")) == country_id: return system
	return {}
