class_name InternationalFootball
extends RefCounted

const GroupStageClass = preload("res://simulation/competitions/group_stage.gd")
const KnockoutClass = preload("res://simulation/competitions/knockout_competition.gd")

func ensure_world(world: Dictionary) -> void:
	world["national_teams"] = world.get("national_teams", _build_national_teams(world.get("countries", [])))
	world["international_callups"] = world.get("international_callups", [])
	world["international_competitions"] = world.get("international_competitions", [])
	world["international_history"] = world.get("international_history", [])
	world["international_player_records"] = world.get("international_player_records", {})
	world["international_managers"] = world.get("international_managers", {})
	world["international_calendar"] = world.get("international_calendar", [])

func eligible_countries(player: Dictionary) -> Array:
	var result: Array = []
	for key in ["country_id","nationality_id"]:
		var value := String(player.get(key,""))
		if value != "" and value not in result: result.append(value)
	for value in player.get("dual_nationalities",[]):
		var id := String(value)
		if id != "" and id not in result: result.append(id)
	var birth := String(player.get("birth_country_id",""))
	if birth != "" and birth not in result: result.append(birth)
	return result

func commit_nationality(player: Dictionary, country_id: String) -> bool:
	if country_id not in eligible_countries(player): return false
	if bool(player.get("international_committed",false)) and String(player.get("international_country_id","")) != country_id: return false
	player["international_committed"] = true
	player["international_country_id"] = country_id
	return true

func select_squad(world: Dictionary, country_id: String, size: int = 23) -> Array:
	return select_age_squad(world, country_id, size, 99)

func select_age_squad(world: Dictionary, country_id: String, size: int, max_age: int) -> Array:
	ensure_world(world)
	var eligible: Array = []
	for player in world.get("players", []):
		if bool(player.get("retired", false)) or int(player.get("injured_days", 0)) > 0:
			continue
		if int(player.get("age", 25)) > max_age:
			continue
		if bool(player.get("international_committed", false)) and String(player.get("international_country_id", "")) != country_id:
			continue
		if country_id in eligible_countries(player):
			eligible.append(player)
	eligible.sort_custom(func(a: Dictionary, b: Dictionary):
		var af := _selection_score(a); var bf := _selection_score(b)
		if is_equal_approx(af,bf): return String(a.id) < String(b.id)
		return af > bf
	)
	var selected: Array = []
	var quotas := {"GK":3,"DEF":7,"MID":7,"FWD":6}
	for group in ["GK","DEF","MID","FWD"]:
		for player in eligible:
			if selected.size() >= size or int(quotas[group]) <= 0: break
			if _position_group(String(player.get("position",""))) == group and String(player.id) not in selected:
				selected.append(String(player.id)); quotas[group] = int(quotas[group])-1
	for player in eligible:
		if selected.size() >= size: break
		if String(player.id) not in selected: selected.append(String(player.id))
	return selected

func register_callups(world: Dictionary, country_id: String, competition_id: String, size: int = 23, start_date: String = "", end_date: String = "") -> Dictionary:
	return register_age_callups(world, country_id, competition_id, size, 99, start_date, end_date)

func register_age_callups(world: Dictionary, country_id: String, competition_id: String, size: int, max_age: int, start_date: String = "", end_date: String = "") -> Dictionary:
	ensure_world(world)
	var record := {"country_id": country_id, "competition_id": competition_id, "player_ids": select_age_squad(world, country_id, size, max_age), "season_year": int(world.get("season_year", 2026)), "start_date": start_date, "end_date": end_date, "max_age": max_age, "level": _level_for_age(max_age)}
	world.international_callups.append(record)
	for id in record.player_ids:
		var player := _player(world.get("players", []), String(id))
		if not player.is_empty():
			player["on_international_duty"] = true
			player["international_release_until"] = end_date
			player["international_level"] = String(record.level)
	return record

func youth_pathway(world: Dictionary, country_id: String, season_year: int) -> Dictionary:
	# U23 -> U20 -> U17 pathway feeds the senior team. Youngsters gain caps,
	# development momentum and commitment without blocking senior selection.
	ensure_world(world)
	var u23 := register_age_callups(world, country_id, "youth-u23-%d" % season_year, 20, 23)
	var u20 := register_age_callups(world, country_id, "youth-u20-%d" % season_year, 20, 20)
	var u17 := register_age_callups(world, country_id, "youth-u17-%d" % season_year, 18, 17)
	for player_id in u23.player_ids + u20.player_ids + u17.player_ids:
		var player := _player(world.get("players", []), String(player_id))
		if player.is_empty():
			continue
		player["youth_caps"] = int(player.get("youth_caps", 0)) + 1
		player["development_trajectory"] = _boost_trajectory(player)
	return {"u23": u23.player_ids.size(), "u20": u20.player_ids.size(), "u17": u17.player_ids.size()}

func _level_for_age(max_age: int) -> String:
	if max_age <= 17:
		return "U17"
	if max_age <= 20:
		return "U20"
	if max_age <= 23:
		return "U23"
	return "senior"

func _boost_trajectory(player: Dictionary) -> Variant:
	var current = player.get("development_trajectory", 0.5)
	if current is String:
		return "normal" if String(current) == "late" else current
	return clampf(float(current) + 0.05, 0.0, 1.0)

func release_callups(world: Dictionary, country_id: String, competition_id: String) -> void:
	for record in world.get("international_callups",[]):
		if String(record.get("country_id","")) != country_id or String(record.get("competition_id","")) != competition_id: continue
		for id in record.get("player_ids",[]):
			var player := _player(world.get("players",[]),String(id))
			if not player.is_empty(): player["on_international_duty"] = false

func record_appearance(world: Dictionary, country_id: String, player_id: String, goals: int = 0, minutes: int = 90, injury_days: int = 0) -> Dictionary:
	ensure_world(world)
	var key := "%s:%s" % [country_id,player_id]
	var record: Dictionary = world.international_player_records.get(key,{"country_id":country_id,"player_id":player_id,"caps":0,"goals":0,"minutes":0,"debut_year":int(world.get("season_year",2026))})
	record.caps = int(record.caps)+1; record.goals = int(record.goals)+maxi(0,goals); record.minutes = int(record.minutes)+maxi(0,minutes)
	world.international_player_records[key] = record
	var player := _player(world.get("players",[]),player_id)
	if not player.is_empty():
		player["international_fatigue"] = clampf(float(player.get("international_fatigue",0.0)) + float(minutes)/900.0,0.0,1.0)
		if injury_days > 0: player["injured_days"] = maxi(int(player.get("injured_days",0)),injury_days)
	return record

func set_national_manager(world: Dictionary, country_id: String, manager_id: String) -> void:
	ensure_world(world)
	world.international_managers[country_id] = manager_id

func add_calendar_window(world: Dictionary, start_date: String, end_date: String, kind: String, competition_id: String = "") -> Dictionary:
	ensure_world(world)
	var window := {"start_date":start_date,"end_date":end_date,"kind":kind,"competition_id":competition_id}
	world.international_calendar.append(window)
	return window

const INTERNATIONAL_REGIONS := {
	"europe": ["eng", "esp", "deu", "fra", "ita", "prt", "nld", "bel", "tur"],
	"africa": ["nga", "gha", "zaf", "egy", "mar", "sen"],
	"south_america": ["bra", "arg", "uru", "col"],
	"asia": ["jpn", "kor", "aus"],
	"north_america": ["usa", "mex"],
}

const CONTINENTAL_CHAMPIONSHIPS := {
	"europe": "European Championship",
	"africa": "Africa Cup of Nations",
	"south_america": "Copa America",
	"asia": "Asian Cup",
	"north_america": "Gold Cup",
}

func region_for_country(country_id: String) -> String:
	for region in INTERNATIONAL_REGIONS:
		if country_id in INTERNATIONAL_REGIONS[region]: return String(region)
	return "world"

func continental_championship_name(region: String) -> String:
	return String(CONTINENTAL_CHAMPIONSHIPS.get(region, "Continental Championship"))

func world_cup_id(year: int) -> String:
	return "world-cup-%d" % year

func continental_championship_id(region: String, year: int) -> String:
	return "continental-%s-%d" % [region, year]

func create_qualifying_cycle(world: Dictionary, competition_id: String, group_count: int = 4) -> Dictionary:
	ensure_world(world)
	var country_ids: Array = []
	for country in world.get("countries", []): country_ids.append(String(country.get("id", "")))
	var groups := GroupStageClass.new().seed_groups(country_ids, mini(group_count, maxi(1,country_ids.size())))
	var cycle := {"id":competition_id,"season_year":int(world.get("season_year",2026)),"stage":"qualifying","groups":groups,"fixtures":GroupStageClass.new().fixtures_for_groups(groups,competition_id),"qualified":[],"winner":"","history":[],"kind":"qualifying"}
	world.international_competitions.append(cycle)
	return cycle

func create_continental_qualifying(world: Dictionary, region: String, competition_id: String, slots: int = 8) -> Dictionary:
	ensure_world(world)
	var members: Array = []
	for country in world.get("countries", []):
		if region_for_country(String(country.get("id", ""))) == region: members.append(String(country.get("id", "")))
	if members.size() < 2:
		for country in world.get("countries", []):
			if String(country.get("id", "")) not in members: members.append(String(country.get("id", "")))
	var group_count := maxi(1, int(ceil(float(members.size()) / 4.0)))
	var groups := GroupStageClass.new().seed_groups(members, mini(group_count, members.size()))
	var cycle := {"id": competition_id, "season_year": int(world.get("season_year", 2026)), "stage": "qualifying", "kind": "continental_qualifying", "region": region, "name": continental_championship_name(region), "slots": slots, "groups": groups, "fixtures": GroupStageClass.new().fixtures_for_groups(groups, competition_id), "qualified": [], "winner": "", "history": []}
	world.international_competitions.append(cycle)
	return cycle

func create_world_cup_qualifying(world: Dictionary, competition_id: String, slots: int = 8) -> Dictionary:
	ensure_world(world)
	var country_ids: Array = []
	for country in world.get("countries", []): country_ids.append(String(country.get("id", "")))
	# Regional pools keep qualification pathways realistic; small regions merge.
	var pools := _world_cup_pools(world)
	var cycle := {"id": competition_id, "season_year": int(world.get("season_year", 2026)), "stage": "qualifying", "kind": "world_cup_qualifying", "name": "World Cup", "slots": slots, "pools": pools, "groups": [], "fixtures": [], "qualified": [], "winner": "", "history": []}
	for pool in pools:
		var members: Array = pool.get("members", [])
		if members.size() < 2: continue
		var group_count := maxi(1, int(ceil(float(members.size()) / 4.0)))
		var groups := GroupStageClass.new().seed_groups(members, mini(group_count, members.size()))
		cycle.groups.append_array(groups)
		cycle.fixtures.append_array(GroupStageClass.new().fixtures_for_groups(groups, competition_id))
	world.international_competitions.append(cycle)
	return cycle

func qualify_from_groups(groups: Array, fixtures: Array, slots: int) -> Array:
	var qualifiers := GroupStageClass.new().qualifiers(groups, fixtures, 2)
	qualifiers.sort()
	if qualifiers.size() > slots: qualifiers.resize(slots)
	return qualifiers

func _world_cup_pools(world: Dictionary) -> Array:
	var pools: Array = []
	for region in INTERNATIONAL_REGIONS:
		var members: Array = []
		for country in world.get("countries", []):
			if String(country.get("id", "")) in INTERNATIONAL_REGIONS[region]: members.append(String(country.get("id", "")))
		if members.size() >= 2:
			pools.append({"region": region, "members": members})
	if pools.is_empty():
		var all: Array = []
		for country in world.get("countries", []): all.append(String(country.get("id", "")))
		pools.append({"region": "world", "members": all})
	return pools

func complete_qualifying(world: Dictionary, competition_id: String, qualified: Array) -> Dictionary:
	ensure_world(world)
	for cycle in world.international_competitions:
		if String(cycle.get("id","")) != competition_id: continue
		cycle.stage = "finals"
		cycle.qualified = qualified.duplicate()
		cycle.history.append({"year":int(world.get("season_year",2026)),"event":"qualification_complete","qualified":qualified.duplicate()})
		return cycle
	return {}

func complete_tournament(world: Dictionary, competition_id: String, winner: String, runner_up: String = "") -> void:
	ensure_world(world)
	world.international_history.append({"competition_id":competition_id,"season_year":int(world.get("season_year",2026)),"winner":winner,"runner_up":runner_up})
	for cycle in world.international_competitions:
		if String(cycle.get("id","")) == competition_id:
			cycle.stage = "complete"; cycle.winner = winner

func knockout_stage(qualified_country_ids: Array, seed: int) -> Dictionary:
	return KnockoutClass.new().create_bracket(qualified_country_ids, seed)

func _selection_score(player: Dictionary) -> float:
	var ability := float(player.get("current_ability",0))
	var form := float(player.get("form",player.get("morale",50)))
	var fitness := 100.0 - float(player.get("fatigue",0.0))*100.0 - float(player.get("international_fatigue",0.0))*35.0
	var tactical := float(player.get("national_tactical_fit",50))
	return ability*0.62 + form*0.14 + fitness*0.12 + tactical*0.12

func _position_group(position: String) -> String:
	if position == "GK": return "GK"
	if position in ["CB","LB","RB","LWB","RWB","DC","DL","DR"]: return "DEF"
	if position in ["DM","CM","AM","LM","RM","MC","AMC","DMC","ML","MR"]: return "MID"
	return "FWD"

func _build_national_teams(countries: Array) -> Array:
	var teams: Array = []
	for country in countries:
		teams.append({"id":"national-%s" % String(country.get("id","")),"country_id":String(country.get("id","")),"name":String(country.get("name","Nation")),"reputation":int(country.get("youth_rating",50))})
	return teams

func _club(clubs: Array, id: String) -> Dictionary:
	for club in clubs:
		if String(club.get("id", "")) == id: return club
	return {}

func _player(players: Array, id: String) -> Dictionary:
	for player in players:
		if String(player.get("id","")) == id: return player
	return {}
