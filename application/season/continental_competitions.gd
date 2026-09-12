class_name ContinentalCompetitions
extends RefCounted

const LeaguePhaseClass = preload("res://application/season/continental_league_phase.gd")
const ModernRulesClass = preload("res://simulation/competitions/modern_rules_catalog.gd")

const REGIONS := {
	"europe": ["eng", "esp", "deu", "fra", "ita", "prt", "nld", "bel", "tur"],
	"africa": ["nga", "gha", "zaf", "egy", "mar", "sen"],
	"south_america": ["bra", "arg", "uru", "col"],
	"asia": ["jpn", "kor", "aus"],
	"north_america": ["usa", "mex"],
}

const EUROPE_TIERS := [
	{"suffix":"champions","label":"Champions Cup","tier":1,"offset":0},
	{"suffix":"shield","label":"Shield Cup","tier":2,"offset":36},
	{"suffix":"plate","label":"Plate Cup","tier":3,"offset":72},
]

const REGIONAL_TIERS := [
	{"suffix": "champions", "label": "Champions Cup", "places": [0, 8], "tier": 1},
	{"suffix": "shield", "label": "Shield Cup", "places": [8, 16], "tier": 2},
	{"suffix": "plate", "label": "Plate Cup", "places": [16, 24], "tier": 3},
]

const CLUB_WORLD_CUP_ID := "global-club-world-cup"

func prepare(world: Dictionary, records: Array = []) -> void:
	for region_key in REGIONS.keys():
		var region := String(region_key)
		var ranked_all: Array = _ranked_region_clubs(world, region, records)
		if ranked_all.is_empty(): continue
		if region == "europe": _prepare_europe(world,ranked_all)
		else: _prepare_regional_knockouts(world,region,ranked_all)
	_ensure_club_world_cup(world)
	_apply_qualification_cascade(world, records)
	ModernRulesClass.new().apply_to_world(world)

func initialize_formats(world: Dictionary, season_year: int, force: bool = false) -> void:
	var phase = LeaguePhaseClass.new()
	for competition in world.get("competitions",[]):
		if String(competition.get("competition_type","")) != "continental_league_phase": continue
		var has_current := false
		for fixture in world.get("fixtures",[]):
			if String(fixture.get("competition_id","")) == String(competition.get("id","")) and int(fixture.get("season_year",season_year)) == season_year:
				has_current = true; break
		if force or not has_current: phase.initialize(world,competition,season_year)

func _prepare_europe(world: Dictionary, ranked_all: Array) -> void:
	# The modern three-tier UEFA-style ecosystem requires 36 clubs per league
	# phase. The launch database contains enough top-flight clubs to provide
	# three disjoint fields while preserving broad national representation.
	for tier_def in EUROPE_TIERS:
		var offset := int(tier_def.offset)
		if ranked_all.size() < offset + 36: continue
		var entrants := ranked_all.slice(offset,offset+36)
		var id := "continental-europe-%s" % String(tier_def.suffix)
		var target := _competition(world,id)
		if target.is_empty():
			target = {"id":id,"name":"Europe %s" % String(tier_def.label),"country_id":"","registration_rules":{"max_squad":25,"min_goalkeepers":2,"max_foreign":25}}
			world.competitions.append(target)
		target["competition_type"] = "continental_league_phase"
		target["club_ids"] = entrants
		target["tier"] = int(tier_def.tier)
		target["continental"] = true
		target["continental_region"] = "europe"
		target["continental_tier"] = int(tier_def.tier)
		target["modern_league_phase"] = ModernRulesClass.EUROPEAN_LEAGUE_PHASES[int(tier_def.tier)].duplicate(true)
		target["qualification"] = "36-club league phase; top eight advance directly, positions 9-24 enter the knockout playoff, positions 25-36 are eliminated."
		target["away_goals"] = false
		target["extra_time"] = true
		target["penalties"] = true
	# Remove the obsolete fourth European qualifying shell from older saves.
	var keep: Array = []
	for competition in world.get("competitions",[]):
		if String(competition.get("id","")) == "continental-europe-plate_qualifying": continue
		keep.append(competition)
	world["competitions"] = keep

func _prepare_regional_knockouts(world: Dictionary, region: String, ranked_all: Array) -> void:
	# Confederations outside Europe retain data-driven regional cups for now;
	# their exact field sizes depend on the countries loaded into the career.
	# Modern universal match laws still apply: five substitutions, no away goals,
	# extra time and penalties in decisive ties.
	for tier_def in REGIONAL_TIERS:
		var lo := int(tier_def.places[0]); var hi := int(tier_def.places[1])
		var entrants := ranked_all.slice(lo,mini(hi,ranked_all.size()))
		if entrants.size() < 4: continue
		var id := "continental-%s-%s" % [region,String(tier_def.suffix)]
		var target := _competition(world,id)
		if target.is_empty():
			target = {"id":id,"name":"%s %s" % [region.replace("_"," ").capitalize(),String(tier_def.label)],"registration_rules":{"max_squad":25,"min_goalkeepers":2,"max_foreign":25}}
			world.competitions.append(target)
		target["competition_type"] = "knockout"
		target["club_ids"] = entrants
		target["country_id"] = ""
		target["tier"] = int(tier_def.tier)
		target["continental"] = true
		target["continental_region"] = region
		target["continental_tier"] = int(tier_def.tier)
		target["away_goals"] = false
		target["extra_time"] = true
		target["penalties"] = true

func club_world_cup_entrants(world: Dictionary) -> Array:
	var entrants: Array = []
	for competition in world.get("competitions", []):
		if not bool(competition.get("continental", false)) or int(competition.get("continental_tier",1)) != 1: continue
		var champion := String(competition.get("champion_club_id", ""))
		if champion != "" and champion not in entrants: entrants.append(champion)
	if entrants.is_empty():
		for competition in world.get("competitions", []):
			if String(competition.get("id", "")).ends_with("-champions") and bool(competition.get("continental", false)):
				var ids: Array = competition.get("club_ids", [])
				if not ids.is_empty() and String(ids[0]) not in entrants: entrants.append(String(ids[0]))
	entrants.sort()
	return entrants

func refresh_club_world_cup(world: Dictionary) -> Dictionary:
	return _ensure_club_world_cup(world)

func _apply_qualification_cascade(world: Dictionary, records: Array) -> void:
	var cascade: Array = []
	for competition in world.get("competitions", []):
		if not bool(competition.get("continental", false)): continue
		var champion := String(competition.get("champion_club_id", ""))
		if champion == "": continue
		cascade.append({"competition_id":String(competition.get("id","")),"champion_club_id":champion,"tier":int(competition.get("continental_tier",1))})
	world["qualification_cascade"] = cascade

func _ensure_club_world_cup(world: Dictionary) -> Dictionary:
	var entrants := club_world_cup_entrants(world)
	var target := _competition(world,CLUB_WORLD_CUP_ID)
	if target.is_empty() and entrants.size() < 2: return {}
	if target.is_empty():
		target = {"id":CLUB_WORLD_CUP_ID,"name":"Club World Cup","competition_type":"knockout","country_id":"","tier":0,"continental":true,"continental_region":"global","continental_tier":0,"club_world_cup":true,"registration_rules":{"max_squad":26,"min_goalkeepers":2,"max_foreign":26}}
		world.competitions.append(target)
	target["club_ids"] = entrants
	target["continental"] = true
	target["club_world_cup"] = true
	target["away_goals"] = false
	target["extra_time"] = true
	target["penalties"] = true
	target["qualification"] = "Continental champions qualify; pre-completion fallback uses top seeds when required."
	return target

func _ranked_region_clubs(world: Dictionary, region: String, records: Array) -> Array:
	var by_country := {}
	for competition in world.get("competitions", []).duplicate():
		if String(competition.get("competition_type", "league")) != "league" or int(competition.get("tier", 1)) != 1: continue
		if String(competition.get("country_id", "")) not in REGIONS[region]: continue
		var ranked: Array = []
		for record in records:
			if String(record.get("competition_id", "")) != String(competition.id): continue
			for row in record.get("table", []): ranked.append(String(row.get("club_id","") if row is Dictionary else row))
		if ranked.is_empty():
			var clubs: Array = []
			for club in world.get("clubs", []):
				if String(club.id) in competition.get("club_ids", []): clubs.append(club)
			clubs.sort_custom(func(a: Dictionary,b: Dictionary):
				if int(a.get("reputation",0)) == int(b.get("reputation",0)): return String(a.id) < String(b.id)
				return int(a.get("reputation",0)) > int(b.get("reputation",0))
			)
			for club in clubs: ranked.append(String(club.id))
		var country_id := String(competition.get("country_id",""))
		if not by_country.has(country_id): by_country[country_id] = []
		by_country[country_id].append_array(ranked)
	var ordered: Array = []
	var per_nation: Array = by_country.values()
	var depth := 0
	var added := true
	while added:
		added = false
		for nation_list in per_nation:
			if depth < nation_list.size(): ordered.append(String(nation_list[depth])); added = true
		depth += 1
		if depth > 20: break
	return ordered

func _competition(world: Dictionary, id: String) -> Dictionary:
	for competition in world.get("competitions",[]):
		if String(competition.get("id","")) == id: return competition
	return {}
