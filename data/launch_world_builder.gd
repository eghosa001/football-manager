class_name LaunchWorldBuilder
extends RefCounted

const DatabaseLoaderClass = preload("res://data/database_loader.gd")
const DomainModelsClass = preload("res://simulation/world/domain_models.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

const FIRST_NAMES := ["Daniel","Victor","Samuel","David","Ibrahim","Michael","Joseph","Emmanuel","Tobi","Kelvin","Musa","Peter","Ahmed","John","Chinedu","Seyi"]
const LAST_NAMES := ["Okoro","Mensah","Diallo","Banda","Mokoena","Abdullahi","Adeyemi","Kamara","Ndlovu","Boateng","Ibrahim","Dlamini","Osei","Eze","Sow","Yusuf"]
const POSITIONS := ["GK","GK","DR","DC","DC","DC","DL","DM","MC","MC","AMC","AMR","AML","ST","ST"]
const STAFF_ROLES := ["manager","assistant","coach","scout","physio"]

func build(seed: int = 12345, max_countries: int = 0, players_per_club: int = 25) -> Dictionary:
	var loader = DatabaseLoaderClass.new()
	var data: Dictionary = loader.load_seed()
	if data.is_empty() or not loader.validate_seed(data).is_empty(): return {}
	var world := {"seed":seed,"date":"2026-07-01","season_year":2026,"countries":[],"clubs":[],"players":[],"staff":[],"competitions":[],"contracts":[],"fixtures":[],"launch_database_schema":int(data.schema_version)}
	var countries: Array = data.countries
	var count: int = countries.size() if max_countries <= 0 else mini(max_countries, countries.size())
	for country_index in range(count):
		var raw_country: Dictionary = countries[country_index]
		var country_id := String(raw_country.id)
		world.countries.append(DomainModelsClass.country(country_id, String(raw_country.name), String(raw_country.code), int(raw_country.youth_rating)))
		var system: Dictionary = loader.league_system(data, country_id)
		for tier_index in range(system.get("tiers", []).size()):
			var tier: Dictionary = system.tiers[tier_index]
			var template: Dictionary = loader.template_by_id(data, String(tier.template))
			var team_count := int(template.get("teams", 20))
			var club_ids: Array = []
			for club_index in range(team_count):
				var club_id := "%s-t%d-c%02d" % [country_id, tier_index + 1, club_index + 1]
				var club_name := "%s %s %d" % [String(raw_country.name), _club_word(club_index), club_index + 1]
				var rep := _range(seed, _key(club_id), 28 + maxi(0, 3-tier_index)*4, 78 - tier_index*5)
				var club: Dictionary = DomainModelsClass.club(club_id, country_id, club_name, rep)
				club["tier"] = tier_index + 1
				club["stadium_capacity"] = _range(seed, _key(club_id)+1, 5000, 55000)
				club["training_facilities"] = _range(seed, _key(club_id)+2, 30, 80)
				club["homegrown_country_id"] = country_id
				world.clubs.append(club)
				club_ids.append(club_id)
				_generate_staff(world, club, seed)
				_generate_players(world, club, country_id, players_per_club, seed)
			var competition_id := "%s-league-%d" % [country_id, tier_index + 1]
			var competition: Dictionary = DomainModelsClass.competition(competition_id, country_id, String(tier.name), club_ids)
			competition["tier"] = tier_index + 1
			competition["promotion_places"] = int(tier.get("promotion", 0))
			competition["relegation_places"] = int(tier.get("relegation", 0))
			competition["registration_rules"] = _registration_rules(data)
			competition["competition_type"] = "league"
			world.competitions.append(competition)
			world.fixtures.append_array(_round_robin(competition_id, club_ids))
		_add_domestic_cup(world, data, system, country_id)
	world["transfer_windows"] = _transfer_windows(data)
	return world

func _add_domestic_cup(world: Dictionary, data: Dictionary, system: Dictionary, country_id: String) -> void:
	var cup: Dictionary = system.get("cup", {})
	if cup.is_empty(): return
	var all_clubs: Array = []
	for club in world.clubs:
		if String(club.get("country_id", "")) == country_id: all_clubs.append(String(club.id))
	if all_clubs.size() < 2: return
	var template: Dictionary = DatabaseLoaderClass.new().template_by_id(data, String(cup.get("template", "")))
	var max_teams := mini(int(template.get("teams", all_clubs.size())), all_clubs.size())
	all_clubs.sort(); all_clubs.resize(max_teams)
	world.competitions.append({"id":"%s-cup" % country_id,"country_id":country_id,"name":String(cup.get("name","National Cup")),"club_ids":all_clubs,"competition_type":"knockout","rules":template.duplicate(true),"registration_rules":_registration_rules(data),"points_win":3,"points_draw":1})

func _registration_rules(data: Dictionary) -> Dictionary:
	var defaults: Dictionary = data.get("registration_defaults", {})
	return {"max_squad":int(defaults.get("max_squad",25)),"min_goalkeepers":int(defaults.get("min_goalkeepers",2)),"max_foreign":int(defaults.get("max_foreign",99)),"min_homegrown":int(defaults.get("homegrown_required",0)),"min_age":15}

func _transfer_windows(data: Dictionary) -> Array:
	var result: Array = []
	for value in data.get("registration_defaults", {}).get("transfer_windows", ["summer","winter"]):
		if String(value) == "summer": result.append({"start_month":6,"start_day":15,"end_month":9,"end_day":1})
		elif String(value) == "winter": result.append({"start_month":1,"start_day":1,"end_month":1,"end_day":31})
	return result

func _generate_staff(world: Dictionary, club: Dictionary, seed: int) -> void:
	for role_index in range(STAFF_ROLES.size()):
		var id := "staff-%s-%d" % [String(club.id), role_index]
		var key := _key(id)
		var name := "%s %s" % [FIRST_NAMES[_range(seed,key+1,0,FIRST_NAMES.size()-1)], LAST_NAMES[_range(seed,key+2,0,LAST_NAMES.size()-1)]]
		world.staff.append(DomainModelsClass.staff(id, String(club.id), name, STAFF_ROLES[role_index], _range(seed,key+3,30,85)))

func _generate_players(world: Dictionary, club: Dictionary, country_id: String, count: int, seed: int) -> void:
	for i in range(maxi(15, count)):
		var id := "player-%s-%02d" % [String(club.id), i + 1]
		var key := _key(id)
		var ca := _range(seed,key+1,28 + maxi(0, 3-int(club.tier))*4,76 - (int(club.tier)-1)*5)
		var pa := mini(100, ca + _range(seed,key+2,0,28))
		var player: Dictionary = DomainModelsClass.player(id, String(club.id), FIRST_NAMES[_range(seed,key+3,0,FIRST_NAMES.size()-1)], LAST_NAMES[_range(seed,key+4,0,LAST_NAMES.size()-1)], _range(seed,key+5,17,33), POSITIONS[i % POSITIONS.size()], ca, pa)
		player["country_id"] = country_id
		player["homegrown"] = true
		world.players.append(player)
		world.contracts.append(DomainModelsClass.contract("contract-"+id,id,String(club.id),2026,_range(seed,key+6,2027,2031),_range(seed,key+7,300,30000)))

func _round_robin(competition_id: String, club_ids: Array) -> Array:
	var teams: Array = club_ids.duplicate(); var fixtures: Array = []; var n: int = teams.size()
	for leg in range(2):
		for round_index in range(n - 1):
			for pair in range(int(n / 2)):
				var a: String = String(teams[pair]); var b: String = String(teams[n-1-pair])
				var home: String = a if (round_index+pair+leg)%2 == 0 else b
				var away: String = b if home == a else a
				fixtures.append(DomainModelsClass.fixture("fixture-%s-%d-%d-%d" % [competition_id,leg,round_index,pair],competition_id,leg*(n-1)+round_index+1,home,away))
			var fixed_team: String = String(teams[0]); var rotating: Array = teams.slice(1); rotating.push_front(rotating.pop_back()); teams=[fixed_team]; teams.append_array(rotating)
	return fixtures

func _club_word(index: int) -> String:
	return ["United","City","Athletic","Rovers","Stars","Dynamos","Warriors","Sporting","Rangers","Lions"][index % 10]

func _range(seed: int, key: int, lo: int, hi: int) -> int:
	return lo + int(SeededRngClass.value_for(seed,key) % (hi-lo+1))

func _key(text: String) -> int:
	var value := 71
	for c in text.to_utf8_buffer(): value = posmod(value*173+int(c),2147483647)
	return value
