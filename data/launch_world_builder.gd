class_name LaunchWorldBuilder
extends RefCounted

const DatabaseLoaderClass = preload("res://data/database_loader.gd")
const DomainModelsClass = preload("res://simulation/world/domain_models.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const RealismProfileClass = preload("res://data/realism_profile.gd")

const FIRST_NAMES := ["Daniel","Victor","Samuel","David","Ibrahim","Michael","Joseph","Emmanuel","Tobi","Kelvin","Musa","Peter","Ahmed","John","Chinedu","Seyi"]
const LAST_NAMES := ["Okoro","Mensah","Diallo","Banda","Mokoena","Abdullahi","Adeyemi","Kamara","Ndlovu","Boateng","Ibrahim","Dlamini","Osei","Eze","Sow","Yusuf"]
const POSITIONS := ["GK","GK","DR","DC","DC","DC","DL","DM","MC","MC","AMC","AMR","AML","ST","ST"]
const STAFF_ROLES := ["manager","assistant","coach","scout","physio"]

func build(seed: int = 12345, max_countries: int = 0, players_per_club: int = 25, expanded: bool = false) -> Dictionary:
	var loader = DatabaseLoaderClass.new()
	var realism = RealismProfileClass.new()
	var data: Dictionary = loader.load_seed("res://data/seed/launch_database.json", expanded)
	if data.is_empty() or not loader.validate_seed(data).is_empty(): return {}
	var world := {"seed":seed,"date":"2026-07-01","season_year":2026,"countries":[],"clubs":[],"players":[],"staff":[],"competitions":[],"contracts":[],"fixtures":[],"launch_database_schema":int(data.schema_version)}
	var countries: Array = data.countries
	var count: int = countries.size() if max_countries <= 0 else mini(max_countries, countries.size())
	var loaded_country_ids: Array = []
	for country_index in range(count): loaded_country_ids.append(String(countries[country_index].id))
	var used_names: Dictionary = {}
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
				var profile: Dictionary = realism.club_profile(raw_country, club_index, tier_index + 1, seed, club_id)
				var club: Dictionary = DomainModelsClass.club(club_id, country_id, String(profile.name), int(profile.reputation))
				club["city"] = String(profile.city)
				club["tier"] = tier_index + 1
				club["stadium_capacity"] = int(profile.stadium_capacity)
				club["training_facilities"] = int(profile.training_facilities)
				club["homegrown_country_id"] = country_id
				club["fictional_identity"] = true
				world.clubs.append(club)
				club_ids.append(club_id)
				_generate_staff(world, club, country_id, data, seed, used_names, realism)
				_generate_players(world, club, country_id, loaded_country_ids, data, players_per_club, seed, used_names, realism)
			var competition_id := "%s-league-%d" % [country_id, tier_index + 1]
			var competition: Dictionary = DomainModelsClass.competition(competition_id, country_id, String(tier.name), club_ids)
			competition["tier"] = tier_index + 1
			competition["promotion_places"] = int(tier.get("promotion", 0))
			competition["automatic_promotion_places"] = int(tier.get("automatic_promotion", tier.get("promotion", 0)))
			competition["playoff_promotion_places"] = int(tier.get("playoff_promotion", 0))
			competition["playoff_places"] = tier.get("playoff_places", []).duplicate(true)
			competition["promotion_playoff_vs_upper"] = int(tier.get("promotion_playoff_vs_upper", 0))
			competition["relegation_places"] = int(tier.get("relegation", 0))
			competition["relegation_playoff_places"] = int(tier.get("relegation_playoff", 0))
			competition["registration_rules"] = _registration_rules(data, country_id)
			competition["competition_type"] = "league"
			competition["rules_profile"] = tier.duplicate(true)
			world.competitions.append(competition)
			world.fixtures.append_array(_round_robin(competition_id, club_ids))
		_add_domestic_cup(world, data, system, country_id)
		_add_domestic_cup(world, data, {"cup": system.get("league_cup", {})}, country_id, "league-cup")
	world["transfer_windows_by_country"] = {}
	for country_id in loaded_country_ids:
		world.transfer_windows_by_country[country_id] = _transfer_windows(data, String(country_id))
	world["default_country_id"] = loader.default_country_id(data)
	world["featured_country_ids"] = loader.featured_country_ids(data)
	world["transfer_windows"] = world.transfer_windows_by_country.get(String(world.default_country_id), [])
	return world

func _add_domestic_cup(world: Dictionary, data: Dictionary, system: Dictionary, country_id: String, suffix: String = "cup") -> void:
	var cup: Dictionary = system.get("cup", {})
	if cup.is_empty(): return
	var all_clubs: Array = []
	for club in world.clubs:
		if String(club.get("country_id", "")) == country_id: all_clubs.append(String(club.id))
	if all_clubs.size() < 2: return
	var template: Dictionary = DatabaseLoaderClass.new().template_by_id(data, String(cup.get("template", "")))
	var max_teams := mini(int(template.get("teams", all_clubs.size())), all_clubs.size())
	all_clubs.sort(); all_clubs.resize(max_teams)
	var cup_id := "%s-%s" % [country_id, suffix]
	world.competitions.append({"id":cup_id,"country_id":country_id,"name":String(cup.get("name","National Cup")),"club_ids":all_clubs,"competition_type":"knockout","rules":template.duplicate(true),"registration_rules":_registration_rules(data, country_id),"points_win":3,"points_draw":1,"fictional_branding":true})

func _registration_rules(data: Dictionary, country_id: String) -> Dictionary:
	var defaults: Dictionary = DatabaseLoaderClass.new().registration_rules_for_country(data, country_id)
	return {"max_squad":int(defaults.get("max_squad",25)),"min_goalkeepers":int(defaults.get("min_goalkeepers",2)),"max_foreign":int(defaults.get("max_foreign",99)),"min_homegrown":int(defaults.get("homegrown_required",0)),"min_age":15}

func _transfer_windows(data: Dictionary, country_id: String) -> Array:
	var result: Array = []
	for value in DatabaseLoaderClass.new().transfer_windows_for_country(data, country_id):
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
		elif String(value) == "summer": result.append({"start_month":6,"start_day":15,"end_month":9,"end_day":1})
		elif String(value) == "winter": result.append({"start_month":1,"start_day":1,"end_month":1,"end_day":31})
	return result

func _generate_staff(world: Dictionary, club: Dictionary, country_id: String, data: Dictionary, seed: int, used_names: Dictionary, realism: RealismProfile) -> void:
	var band: Vector2i = realism.staff_ability_band(int(club.reputation))
	for role_index in range(STAFF_ROLES.size()):
		var id := "staff-%s-%d" % [String(club.id), role_index]
		var key := _key(id)
		var generated: Dictionary = realism.generated_name(data, country_id, seed, key + 1, used_names, id)
		var member: Dictionary = DomainModelsClass.staff(id, String(club.id), String(generated.full_name), STAFF_ROLES[role_index], _range(seed,key+3,band.x,band.y))
		member["country_id"] = country_id
		member["fictional_identity"] = true
		world.staff.append(member)

func _generate_players(world: Dictionary, club: Dictionary, country_id: String, loaded_country_ids: Array, data: Dictionary, count: int, seed: int, used_names: Dictionary, realism: RealismProfile) -> void:
	var club_rep := int(club.reputation)
	var band: Vector2i = realism.ability_band(club_rep)
	var wage_band: Vector2i = realism.wage_band(club_rep)
	for i in range(maxi(15, count)):
		var id := "player-%s-%02d" % [String(club.id), i + 1]
		var key := _key(id)
		var nationality := String(realism.nationality(country_id, loaded_country_ids, club_rep, seed, key + 40))
		var ca := _range(seed,key+1,band.x,band.y)
		var age := _range(seed,key+5,17,34)
		var growth_cap := 34 if age <= 21 else (18 if age <= 25 else 8)
		var pa := mini(100, ca + _range(seed,key+2,0,growth_cap))
		var generated: Dictionary = realism.generated_name(data, nationality, seed, key + 3, used_names, id)
		var position: String = String(POSITIONS[i % POSITIONS.size()])
		var player: Dictionary = DomainModelsClass.player(id, String(club.id), String(generated.first_name), String(generated.last_name), age, position, ca, pa)
		player["country_id"] = nationality
		player["homegrown"] = nationality == country_id and age <= 24
		player["fictional_identity"] = true
		player["preferred_foot"] = "left" if i % 7 == 0 else "right"
		player["role_profile"] = realism.role_profile(position, key)
		world.players.append(player)
		world.contracts.append(DomainModelsClass.contract("contract-"+id,id,String(club.id),2026,_range(seed,key+6,2027,2031),_range(seed,key+7,wage_band.x,wage_band.y)))

func _round_robin(competition_id: String, club_ids: Array) -> Array:
	var teams: Array = club_ids.duplicate(); var fixtures: Array = []; var n: int = teams.size()
	assert(n >= 2 and n % 2 == 0)
	for leg in range(2):
		for round_index in range(n - 1):
			for pair in range(int(n / 2)):
				var a: String = String(teams[pair]); var b: String = String(teams[n-1-pair])
				var home: String = a if (round_index+pair+leg)%2 == 0 else b
				var away: String = b if home == a else a
				fixtures.append(DomainModelsClass.fixture("fixture-%s-%d-%d-%d" % [competition_id,leg,round_index,pair],competition_id,leg*(n-1)+round_index+1,home,away))
			var fixed_team: String = String(teams[0]); var rotating: Array = teams.slice(1); rotating.push_front(rotating.pop_back()); teams=[fixed_team]; teams.append_array(rotating)
	return fixtures

func _range(seed: int, key: int, lo: int, hi: int) -> int:
	if hi <= lo: return lo
	return lo + int(SeededRngClass.value_for(seed,key) % (hi-lo+1))

func _key(text: String) -> int:
	var value := 71
	for c in text.to_utf8_buffer(): value = posmod(value*173+int(c),2147483647)
	return value
