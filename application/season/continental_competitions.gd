class_name ContinentalCompetitions
extends RefCounted

const REGIONS := {
	"europe": ["eng", "esp", "deu", "fra", "ita", "prt", "nld", "bel", "tur"],
	"africa": ["nga", "gha", "zaf", "egy", "mar", "sen"],
	"south_america": ["bra", "arg", "uru", "col"],
	"asia": ["jpn", "kor", "aus"],
	"north_america": ["usa", "mex"],
}

const TIERS := [
	{"suffix": "champions", "label": "Champions Cup", "places": [0, 4], "tier": 1},
	{"suffix": "shield", "label": "Shield Cup", "places": [4, 8], "tier": 2},
	{"suffix": "plate", "label": "Plate Cup", "places": [8, 12], "tier": 3},
]

const CLUB_WORLD_CUP_ID := "global-club-world-cup"

func prepare(world: Dictionary, records: Array = []) -> void:
	for region in REGIONS:
		var ranked_all: Array = _ranked_region_clubs(world, String(region), records)
		if ranked_all.is_empty():
			continue
		for tier_def in TIERS:
			var lo: int = int(tier_def.places[0])
			var hi: int = int(tier_def.places[1])
			var entrants: Array = ranked_all.slice(lo, hi)
			# Require at least 4 clubs and 2 nations for a tier to launch.
			if entrants.size() < 4:
				continue
			var nations := {}
			for club_id in entrants:
				var club := _club(world, String(club_id))
				nations[String(club.get("country_id", ""))] = true
			if nations.size() < 2 and ranked_all.size() >= 4:
				continue
			var id := "continental-%s-%s" % [region, String(tier_def.suffix)]
			var target: Dictionary = {}
			for competition in world.competitions:
				if String(competition.id) == id: target = competition; break
			if target.is_empty():
				target = {"id": id, "name": "%s %s" % [String(region).replace("_", " ").capitalize(), String(tier_def.label)], "competition_type": "knockout", "country_id": "", "tier": int(tier_def.tier), "continental": true, "continental_region": region, "continental_tier": int(tier_def.tier), "registration_rules": {"max_squad": 25, "min_goalkeepers": 2, "max_foreign": 25}}
				world.competitions.append(target)
			target["club_ids"] = entrants
			target["continental"] = true
			target["continental_region"] = region
			target["continental_tier"] = int(tier_def.tier)
			target["qualification"] = "Tier %d: league places %d-%d per region; reputation used for the first season, table position afterwards." % [int(tier_def.tier), lo + 1, hi]
	_ensure_club_world_cup(world)

func club_world_cup_entrants(world: Dictionary) -> Array:
	var entrants: Array = []
	for competition in world.get("competitions", []):
		if not bool(competition.get("continental", false)):
			continue
		if int(competition.get("continental_tier", 1)) != 1:
			continue
		var champion := String(competition.get("champion_club_id", ""))
		if champion != "" and champion not in entrants:
			entrants.append(champion)
	if entrants.is_empty():
		# Pre-first-completion fallback: top champions-tier entrants per region.
		for competition in world.get("competitions", []):
			if String(competition.get("id", "")).ends_with("-champions") and bool(competition.get("continental", false)):
				var ids: Array = competition.get("club_ids", [])
				if not ids.is_empty() and String(ids[0]) not in entrants:
					entrants.append(String(ids[0]))
	entrants.sort()
	return entrants

func refresh_club_world_cup(world: Dictionary) -> Dictionary:
	return _ensure_club_world_cup(world)

func _ensure_club_world_cup(world: Dictionary) -> Dictionary:
	var entrants := club_world_cup_entrants(world)
	var target: Dictionary = {}
	for competition in world.get("competitions", []):
		if String(competition.get("id", "")) == CLUB_WORLD_CUP_ID: target = competition; break
	if target.is_empty() and entrants.size() < 2:
		# Single-nation/soak worlds stay single-competition: no CWC shell.
		return {}
	if target.is_empty():
		target = {"id": CLUB_WORLD_CUP_ID, "name": "Club World Cup", "competition_type": "knockout", "country_id": "", "tier": 0, "continental": true, "continental_region": "global", "continental_tier": 0, "club_world_cup": true, "registration_rules": {"max_squad": 25, "min_goalkeepers": 2, "max_foreign": 25}}
		world["competitions"].append(target)
	target["club_ids"] = entrants
	target["continental"] = true
	target["club_world_cup"] = true
	target["qualification"] = "Continental champions-tier winners qualify; pre-completion fallback uses top seeds."
	return target

func _ranked_region_clubs(world: Dictionary, region: String, records: Array) -> Array:
	var by_country := {}
	for competition in world.get("competitions", []).duplicate():
		if String(competition.get("competition_type", "league")) != "league" or int(competition.get("tier", 1)) != 1: continue
		if String(competition.get("country_id", "")) not in REGIONS[region]: continue
		var ranked: Array = []
		for record in records:
			if String(record.get("competition_id", "")) == String(competition.id):
				for row in record.get("table", []): ranked.append(String(row.get("club_id", row.get("club_id", "")) if row is Dictionary else row))
		if ranked.is_empty():
			var clubs: Array = []
			for club in world.get("clubs", []):
				if String(club.id) in competition.get("club_ids", []): clubs.append(club)
			clubs.sort_custom(func(a: Dictionary, b: Dictionary):
				if int(a.get("reputation", 0)) == int(b.get("reputation", 0)): return String(a.id) < String(b.id)
				return int(a.get("reputation", 0)) > int(b.get("reputation", 0))
			)
			for club in clubs: ranked.append(String(club.id))
		if not by_country.has(String(competition.get("country_id", ""))):
			by_country[String(competition.get("country_id", ""))] = []
		by_country[String(competition.get("country_id", ""))].append_array(ranked)
	# Interleave nations so small leagues still place clubs in tiers 2-3.
	var ordered: Array = []
	var per_nation: Array = by_country.values()
	var depth := 0
	var added := true
	while added:
		added = false
		for nation_list in per_nation:
			if depth < nation_list.size():
				ordered.append(String(nation_list[depth]))
				added = true
		depth += 1
		if depth > 12:
			break
	return ordered

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return club
	return {}
