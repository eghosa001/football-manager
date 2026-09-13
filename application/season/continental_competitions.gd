class_name ContinentalCompetitions
extends RefCounted

const LeaguePhaseClass = preload("res://application/season/continental_league_phase.gd")
const RegionalEngineClass = preload("res://application/season/regional_continental_engine.gd")
const ClubWorldCupClass = preload("res://application/season/club_world_cup.gd")
const ModernRulesClass = preload("res://simulation/competitions/modern_rules_catalog.gd")

const REGIONS := {
	"europe":["eng","esp","deu","fra","ita","prt","nld","bel","tur"],
	"africa":["nga","gha","zaf","egy","mar","sen"],
	"south_america":["bra","arg","uru","col"],
	"asia":["jpn","kor","aus"],
	"north_america":["usa","mex"]
}

const EUROPE_TIERS := [
	{"suffix":"champions","label":"Champions Cup","tier":1,"offset":0},
	{"suffix":"shield","label":"Shield Cup","tier":2,"offset":36},
	{"suffix":"plate","label":"Plate Cup","tier":3,"offset":72}
]

const REGIONAL_TIERS := [
	{"suffix":"champions","label":"Champions Cup","places":[0,8],"tier":1},
	{"suffix":"shield","label":"Shield Cup","places":[8,16],"tier":2},
	{"suffix":"plate","label":"Plate Cup","places":[16,24],"tier":3}
]

const CLUB_WORLD_CUP_ID := "global-club-world-cup"
const CWC_ALLOCATIONS := {"europe":12,"south_america":6,"north_america":4,"africa":4,"asia":4}

func prepare(world: Dictionary, records: Array = []) -> void:
	for region_key in REGIONS.keys():
		var region := String(region_key)
		var ranked_all: Array = _ranked_region_clubs(world,region,records)
		if ranked_all.is_empty(): continue
		if region == "europe": _prepare_europe(world,ranked_all)
		else: _prepare_regional_competitions(world,region,ranked_all)
	_ensure_club_world_cup(world,records)
	_apply_qualification_cascade(world,records)
	ModernRulesClass.new().apply_to_world(world)

func initialize_formats(world: Dictionary, season_year: int, force: bool = false) -> void:
	var phase = LeaguePhaseClass.new()
	var regional = RegionalEngineClass.new()
	var cwc = ClubWorldCupClass.new()
	for competition in world.get("competitions",[]):
		var competition_type := String(competition.get("competition_type",""))
		if competition_type == "continental_league_phase":
			var has_current := _has_current_fixtures(world,String(competition.get("id","")),season_year)
			if force or not has_current: phase.initialize(world,competition,season_year)
		elif competition_type == "regional_continental":
			var has_current := _has_current_fixtures(world,String(competition.get("id","")),season_year)
			if force or not has_current: regional.initialize(world,competition,season_year)
		elif competition_type == "club_world_cup":
			var has_current := _has_current_fixtures(world,String(competition.get("id","")),season_year)
			if force or not has_current: cwc.initialize(world,competition,season_year)

func _prepare_europe(world: Dictionary, ranked_all: Array) -> void:
	for tier_def in EUROPE_TIERS:
		var offset := int(tier_def.offset)
		if ranked_all.size() < offset+36: continue
		var entrants := ranked_all.slice(offset,offset+36)
		var id := "continental-europe-%s" % String(tier_def.suffix)
		var target := _competition(world,id)
		if target.is_empty():
			target={"id":id,"name":"Europe %s" % String(tier_def.label),"country_id":"","registration_rules":{"max_squad":25,"min_goalkeepers":2,"max_foreign":25}}
			world.competitions.append(target)
		target["competition_type"]="continental_league_phase"
		target["club_ids"]=entrants
		target["tier"]=int(tier_def.tier)
		target["continental"]=true
		target["continental_region"]="europe"
		target["continental_tier"]=int(tier_def.tier)
		target["modern_league_phase"]=ModernRulesClass.EUROPEAN_LEAGUE_PHASES[int(tier_def.tier)].duplicate(true)
		target["qualification"]="36-club league phase; top eight advance directly, positions 9-24 enter the knockout playoff, positions 25-36 are eliminated."
		target["away_goals"]=false; target["extra_time"]=true; target["penalties"]=true
	var keep: Array=[]
	for competition in world.get("competitions",[]):
		if String(competition.get("id","")) == "continental-europe-plate_qualifying": continue
		keep.append(competition)
	world["competitions"]=keep

func _prepare_regional_competitions(world: Dictionary, region: String, ranked_all: Array) -> void:
	# Tier-one formats are modeled on the current confederation structure where
	# the loaded database has enough clubs. Lower tiers remain compact fictional
	# continental cups so every region still provides secondary pathways.
	if region == "south_america" and ranked_all.size() >= 32:
		_upsert_regional(world,region,"champions","Champions Cup",1,ranked_all.slice(0,32),"group_knockout",{
			"teams":32,"groups":8,"group_size":4,"group_matches_per_club":6,"qualifiers_per_group":2,"first_knockout":"round_of_16",
			"two_leg_stages":["round_of_16","quarterfinal","semifinal"],"final_two_leg":false
		},"32-club group stage: eight groups of four, home and away; top two advance to two-legged knockouts and a single final.")
	elif region == "africa" and ranked_all.size() >= 16:
		_upsert_regional(world,region,"champions","Champions Cup",1,ranked_all.slice(0,16),"group_knockout",{
			"teams":16,"groups":4,"group_size":4,"group_matches_per_club":6,"qualifiers_per_group":2,"first_knockout":"quarterfinal",
			"two_leg_stages":["quarterfinal","semifinal","final"],"final_two_leg":true
		},"16-club group stage: four groups of four, home and away; top two advance to two-legged quarter-finals, semi-finals and final.")
	elif region == "north_america" and ranked_all.size() >= 27:
		_upsert_regional(world,region,"champions","Champions Cup",1,ranked_all.slice(0,27),"concacaf_27",{
			"teams":27,"round_one_clubs":22,"round_of_16_byes":5,"two_leg_stages":["round_one","round_of_16","quarterfinal","semifinal"],"final_two_leg":false
		},"27-club direct elimination: 22 begin in Round One, five receive Round-of-16 byes; first four rounds are two-legged and the final is single-leg.")
	else:
		_prepare_generic_top_tier(world,region,ranked_all)
	for tier_def in REGIONAL_TIERS:
		if int(tier_def.tier) == 1: continue
		var lo := int(tier_def.places[0]); var hi := int(tier_def.places[1]); var entrants := ranked_all.slice(lo,mini(hi,ranked_all.size()))
		if entrants.size() < 4: continue
		var id := "continental-%s-%s" % [region,String(tier_def.suffix)]
		var target := _competition(world,id)
		if target.is_empty():
			target={"id":id,"name":"%s %s" % [region.replace("_"," ").capitalize(),String(tier_def.label)],"registration_rules":{"max_squad":25,"min_goalkeepers":2,"max_foreign":25}}
			world.competitions.append(target)
		target["competition_type"]="knockout"; target["club_ids"]=entrants; target["country_id"]=""; target["tier"]=int(tier_def.tier)
		target["continental"]=true; target["continental_region"]=region; target["continental_tier"]=int(tier_def.tier)
		target["away_goals"]=false; target["extra_time"]=true; target["penalties"]=true

func _prepare_generic_top_tier(world: Dictionary, region: String, ranked_all: Array) -> void:
	var entrants:=ranked_all.slice(0,mini(8,ranked_all.size()))
	if entrants.size()<4: return
	var id:="continental-%s-champions"%region; var target:=_competition(world,id)
	if target.is_empty():
		target={"id":id,"name":"%s Champions Cup"%region.replace("_"," ").capitalize(),"registration_rules":{"max_squad":25,"min_goalkeepers":2,"max_foreign":25}}
		world.competitions.append(target)
	target["competition_type"]="knockout"; target["club_ids"]=entrants; target["country_id"]=""; target["tier"]=1
	target["continental"]=true; target["continental_region"]=region; target["continental_tier"]=1; target["season_profiled_rules"]=true
	target["away_goals"]=false; target["extra_time"]=true; target["penalties"]=true

func _upsert_regional(world: Dictionary, region: String, suffix: String, label: String, tier: int, entrants: Array, format_kind: String, format: Dictionary, qualification: String) -> void:
	var id:="continental-%s-%s"%[region,suffix]; var target:=_competition(world,id)
	if target.is_empty():
		target={"id":id,"name":"%s %s"%[region.replace("_"," ").capitalize(),label],"registration_rules":{"max_squad":25,"min_goalkeepers":2,"max_foreign":25}}
		world.competitions.append(target)
	target["competition_type"]="regional_continental"; target["format_kind"]=format_kind; target["format"]=format.duplicate(true)
	target["club_ids"]=entrants; target["country_id"]=""; target["tier"]=tier; target["continental"]=true; target["continental_region"]=region; target["continental_tier"]=tier
	target["group_tie_breakers"]=["points","head_to_head_points","head_to_head_goal_difference","head_to_head_goals","goal_difference","goals_scored"]
	target["qualification"]=qualification; target["away_goals"]=false; target["extra_time"]=true; target["penalties"]=true

func club_world_cup_entrants(world: Dictionary, records: Array = []) -> Array:
	var entrants: Array=[]; var used := {}
	for region in CWC_ALLOCATIONS.keys():
		var allocation := int(CWC_ALLOCATIONS[region]); var regional: Array=[]; var champion_id := _regional_champion(world,String(region))
		if champion_id != "": regional.append(champion_id)
		for club_id in _ranked_region_clubs(world,String(region),records):
			if String(club_id) not in regional: regional.append(String(club_id))
		for club_id in regional:
			if entrants.size() >= 30: break
			if int(_count_region_entries(world,entrants,String(region))) >= allocation: break
			if not used.has(String(club_id)): entrants.append(String(club_id)); used[String(club_id)]=true
	var global_ranked := _rank_all_clubs(world)
	for club_id in global_ranked:
		if entrants.size() >= 32: break
		if not used.has(String(club_id)): entrants.append(String(club_id)); used[String(club_id)]=true
	return entrants

func refresh_club_world_cup(world: Dictionary) -> Dictionary:
	return _ensure_club_world_cup(world,[])

func _apply_qualification_cascade(world: Dictionary, _records: Array) -> void:
	var cascade: Array=[]
	for competition in world.get("competitions",[]):
		if not bool(competition.get("continental",false)): continue
		var champion := String(competition.get("champion_club_id",""))
		if champion == "": continue
		cascade.append({"competition_id":String(competition.get("id","")),"champion_club_id":champion,"tier":int(competition.get("continental_tier",1))})
	world["qualification_cascade"]=cascade

func _ensure_club_world_cup(world: Dictionary, records: Array) -> Dictionary:
	var entrants := club_world_cup_entrants(world,records); var target := _competition(world,CLUB_WORLD_CUP_ID)
	if target.is_empty():
		target={"id":CLUB_WORLD_CUP_ID,"name":"Club World Cup","competition_type":"club_world_cup","country_id":"","tier":0,"continental":true,"continental_region":"global","continental_tier":0,"club_world_cup":true,"registration_rules":{"max_squad":26,"min_goalkeepers":2,"max_foreign":26}}
		world.competitions.append(target)
	target["competition_type"]="club_world_cup"; target["club_ids"]=entrants.slice(0,mini(32,entrants.size())); target["continental"]=true; target["club_world_cup"]=true
	target["cycle_years"]=4; target["next_cycle_rule"]="summer after seasons ending in years congruent to 1 mod 4"
	target["format"]={"teams":32,"groups":8,"group_size":4,"group_matches_per_club":3,"qualifiers_per_group":2,"knockout_from":"round_of_16","third_place_match":false}
	target["allocation"]={"europe":12,"south_america":6,"north_america":4,"africa":4,"asia":4,"wildcards":2}
	target["away_goals"]=false; target["extra_time"]=true; target["penalties"]=true
	target["qualification"]="32 clubs; confederation allocations plus host/OFC fallback wildcards. Eight groups of four, top two to a single-leg round of 16."
	return target

func _ranked_region_clubs(world: Dictionary, region: String, records: Array) -> Array:
	var by_country := {}
	for competition in world.get("competitions",[]).duplicate():
		if String(competition.get("competition_type","league")) != "league" or int(competition.get("tier",1)) != 1: continue
		if String(competition.get("country_id","")) not in REGIONS[region]: continue
		var ranked: Array=[]
		for record in records:
			if String(record.get("competition_id","")) != String(competition.id): continue
			for row in record.get("table",[]): ranked.append(String(row.get("club_id","") if row is Dictionary else row))
		if ranked.is_empty():
			var clubs: Array=[]
			for club in world.get("clubs",[]):
				if String(club.id) in competition.get("club_ids",[]): clubs.append(club)
			clubs.sort_custom(func(a: Dictionary,b: Dictionary):
				if int(a.get("reputation",0)) == int(b.get("reputation",0)): return String(a.id) < String(b.id)
				return int(a.get("reputation",0)) > int(b.get("reputation",0)))
			for club in clubs: ranked.append(String(club.id))
		var country_id := String(competition.get("country_id",""))
		if not by_country.has(country_id): by_country[country_id]=[]
		by_country[country_id].append_array(ranked)
	var ordered: Array=[]; var per_nation: Array=by_country.values(); var depth:=0; var added:=true
	while added:
		added=false
		for nation_list in per_nation:
			if depth < nation_list.size(): ordered.append(String(nation_list[depth])); added=true
		depth += 1
		if depth > 30: break
	return ordered

func _regional_champion(world: Dictionary, region: String) -> String:
	for competition in world.get("competitions",[]):
		if String(competition.get("continental_region","")) == region and int(competition.get("continental_tier",1)) == 1:
			var champion := String(competition.get("champion_club_id",""))
			if champion != "": return champion
	return ""

func _count_region_entries(world: Dictionary, entrants: Array, region: String) -> int:
	var countries: Array = REGIONS.get(region,[]); var count:=0
	for club_id in entrants:
		var country := _club_country(world,String(club_id))
		if country in countries: count += 1
	return count

func _rank_all_clubs(world: Dictionary) -> Array:
	var clubs: Array = world.get("clubs",[]).duplicate()
	clubs.sort_custom(func(a: Dictionary,b: Dictionary):
		if int(a.get("reputation",0)) == int(b.get("reputation",0)): return String(a.get("id","")) < String(b.get("id",""))
		return int(a.get("reputation",0)) > int(b.get("reputation",0)))
	var ids: Array=[]
	for club in clubs: ids.append(String(club.get("id","")))
	return ids

func _club_country(world: Dictionary, club_id: String) -> String:
	for club in world.get("clubs",[]):
		if String(club.get("id","")) == club_id: return String(club.get("country_id",""))
	return ""

func _has_current_fixtures(world: Dictionary, competition_id: String, season_year: int) -> bool:
	for fixture in world.get("fixtures",[]):
		if String(fixture.get("competition_id","")) == competition_id and int(fixture.get("season_year",season_year)) == season_year: return true
	return false

func _competition(world: Dictionary, id: String) -> Dictionary:
	for competition in world.get("competitions",[]):
		if String(competition.get("id","")) == id: return competition
	return {}
