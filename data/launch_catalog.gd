class_name LaunchCatalog
extends RefCounted

const DatabaseLoaderClass = preload("res://data/database_loader.gd")

func build(max_countries: int = 0, expanded: bool = false) -> Dictionary:
	var loader = DatabaseLoaderClass.new()
	var data: Dictionary = loader.load_seed("res://data/seed/launch_database.json", expanded)
	if data.is_empty() or not loader.validate_seed(data).is_empty(): return {"countries":[],"clubs":[],"default_country_id":"","featured_country_ids":[]}
	var countries: Array = []
	var clubs: Array = []
	var source: Array = data.get("countries", [])
	var count := source.size() if max_countries <= 0 else mini(max_countries, source.size())
	for country_index in range(count):
		var country: Dictionary = source[country_index]
		var country_id := String(country.get("id", ""))
		countries.append({"id":country_id,"name":String(country.get("name", country_id)),"code":String(country.get("code", ""))})
		var system: Dictionary = loader.league_system(data, country_id)
		for tier_index in range(system.get("tiers", []).size()):
			var tier: Dictionary = system.tiers[tier_index]
			var template: Dictionary = loader.template_by_id(data, String(tier.get("template", "")))
			var team_count := int(template.get("teams", 20))
			for club_index in range(team_count):
				clubs.append({
					"id":"%s-t%d-c%02d" % [country_id, tier_index + 1, club_index + 1],
					"name":loader.club_name(country, club_index, tier_index + 1),
					"country_id":country_id,
					"tier":tier_index + 1,
					"competition_name":String(tier.get("name", "Division")),
				})
	var default_id := loader.default_country_id(data)
	var featured := loader.featured_country_ids(data)
	_sort_clubs_default_first(clubs, default_id, featured)
	return {"countries":countries,"clubs":clubs,"schema_version":int(data.get("schema_version", 0)),"default_country_id":default_id,"featured_country_ids":featured}

func clubs_for_country(catalog: Dictionary, country_id: String) -> Array:
	var result: Array = []
	for club in catalog.get("clubs", []):
		if String(club.get("country_id", "")) == country_id: result.append(club)
	return result

func default_club_id(catalog: Dictionary) -> String:
	var default_id := String(catalog.get("default_country_id", ""))
	var pool := clubs_for_country(catalog, default_id) if default_id != "" else []
	if pool.is_empty(): pool = catalog.get("clubs", [])
	if pool.is_empty(): return ""
	return String(pool[0].get("id", ""))

func _sort_clubs_default_first(clubs: Array, default_id: String, featured: Array) -> void:
	# Preserve seed-file order within each nation; England first, Spain second.
	# Non-featured nations keep their file order so catalog matches world builder.
	var order := {}
	for i in range(featured.size()): order[String(featured[i])] = i
	var index := {}
	for i in range(clubs.size()): index[String(clubs[i].get("id", ""))] = i
	clubs.sort_custom(func(a: Dictionary, b: Dictionary):
		var ao := int(order.get(String(a.get("country_id", "")), 900))
		var bo := int(order.get(String(b.get("country_id", "")), 900))
		if ao != bo: return ao < bo
		if String(a.get("country_id", "")) == default_id and String(b.get("country_id", "")) == default_id:
			if int(a.get("tier", 9)) != int(b.get("tier", 9)): return int(a.get("tier", 9)) < int(b.get("tier", 9))
		return int(index.get(String(a.get("id", "")), 0)) < int(index.get(String(b.get("id", "")), 0))
	)

func _club_word(index: int) -> String:
	return ["United","City","Athletic","Rovers","Stars","Dynamos","Warriors","Sporting","Rangers","Lions"][index % 10]
