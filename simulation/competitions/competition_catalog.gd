class_name CompetitionCatalog
extends RefCounted

const DatabaseLoaderClass = preload("res://data/database_loader.gd")
const CompetitionRulesClass = preload("res://simulation/competitions/competition_rules.gd")

func build_for_country(data: Dictionary, country_id: String, club_ids_by_tier: Array) -> Array:
	var loader = DatabaseLoaderClass.new()
	var system: Dictionary = loader.league_system(data, country_id)
	if system.is_empty():
		return []
	var competitions: Array = []
	var tiers: Array = system.get("tiers", [])
	for i in range(tiers.size()):
		var tier: Dictionary = tiers[i]
		var template: Dictionary = loader.template_by_id(data, String(tier.get("template", "")))
		var raw := template.duplicate(true)
		raw["promotion_places"] = int(tier.get("promotion", 0))
		raw["relegation_places"] = int(tier.get("relegation", 0))
		var rules: Dictionary = CompetitionRulesClass.new().normalize(raw)
		competitions.append({
			"id":"%s-tier-%d" % [country_id, i + 1],
			"country_id":country_id,
			"name":String(tier.get("name", "Division %d" % (i + 1))),
			"tier":i + 1,
			"club_ids":club_ids_by_tier[i].duplicate() if i < club_ids_by_tier.size() else [],
			"rules":rules,
		})
	var cup: Dictionary = system.get("cup", {})
	if not cup.is_empty():
		var cup_template: Dictionary = loader.template_by_id(data, String(cup.get("template", "")))
		var all_clubs: Array = []
		for tier_clubs in club_ids_by_tier:
			all_clubs.append_array(tier_clubs)
		competitions.append({"id":"%s-cup" % country_id,"country_id":country_id,"name":String(cup.get("name","National Cup")),"tier":0,"club_ids":all_clubs,"rules":CompetitionRulesClass.new().normalize(cup_template)})
	return competitions

func registration_rules(data: Dictionary) -> Dictionary:
	var defaults: Dictionary = data.get("registration_defaults", {})
	return {
		"max_squad":int(defaults.get("max_squad", 25)),
		"min_goalkeepers":int(defaults.get("min_goalkeepers", 2)),
		"max_foreign":int(defaults.get("max_foreign", -1)),
		"homegrown_required":int(defaults.get("homegrown_required", 0)),
	}
