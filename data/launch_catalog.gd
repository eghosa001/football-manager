class_name LaunchCatalog
extends RefCounted

const DatabaseLoaderClass = preload("res://data/database_loader.gd")

func build(max_countries: int = 0) -> Dictionary:
	var loader = DatabaseLoaderClass.new()
	var data: Dictionary = loader.load_seed()
	if data.is_empty() or not loader.validate_seed(data).is_empty(): return {"countries":[],"clubs":[]}
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
					"name":"%s %s %d" % [String(country.get("name", "Nation")), _club_word(club_index), club_index + 1],
					"country_id":country_id,
					"tier":tier_index + 1,
					"competition_name":String(tier.get("name", "Division")),
				})
	return {"countries":countries,"clubs":clubs,"schema_version":int(data.get("schema_version", 0))}

func _club_word(index: int) -> String:
	return ["United","City","Athletic","Rovers","Stars","Dynamos","Warriors","Sporting","Rangers","Lions"][index % 10]
