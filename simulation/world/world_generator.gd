class_name WorldGenerator
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const Models = preload("res://simulation/world/domain_models.gd")

const COUNTRY_NAMES := ["Nigeria", "Ghana", "South Africa", "Egypt", "Senegal", "Morocco", "Kenya", "Cameroon"]
const COUNTRY_CODES := ["NGA", "GHA", "RSA", "EGY", "SEN", "MAR", "KEN", "CMR"]
const CITY_WORDS := ["United", "City", "Athletic", "Rovers", "Stars", "Dynamos", "Warriors", "Sporting", "Rangers", "Lions"]
const FIRST_NAMES := ["Daniel", "Victor", "Samuel", "David", "Ibrahim", "Michael", "Joseph", "Emmanuel", "Tobi", "Kelvin", "Musa", "Peter", "Ahmed", "John", "Chinedu", "Seyi"]
const LAST_NAMES := ["Okoro", "Mensah", "Diallo", "Banda", "Mokoena", "Abdullahi", "Adeyemi", "Kamara", "Ndlovu", "Boateng", "Ibrahim", "Dlamini", "Osei", "Eze", "Sow", "Yusuf"]
const POSITIONS := ["GK", "DR", "DC", "DC", "DL", "DM", "MC", "MC", "AMR", "AML", "ST", "ST"]
const STAFF_ROLES := ["manager", "assistant", "coach", "scout", "physio"]

func create_world(seed: int, country_count: int = 4, clubs_per_country: int = 20, players_per_club: int = 25) -> Dictionary:
	assert(country_count > 0 and country_count <= COUNTRY_NAMES.size())
	assert(clubs_per_country >= 2 and clubs_per_country % 2 == 0)
	assert(players_per_club >= 11)
	var world := {
		"seed": seed,
		"date": "2026-07-01",
		"season_year": 2026,
		"countries": [],
		"clubs": [],
		"players": [],
		"staff": [],
		"competitions": [],
		"contracts": [],
		"fixtures": [],
	}

	for country_index in range(country_count):
		var country_id := _id("country", seed, [country_index])
		var youth_rating := _rand_int(seed, 10_000 + country_index, 45, 82)
		world.countries.append(Models.country(country_id, COUNTRY_NAMES[country_index], COUNTRY_CODES[country_index], youth_rating))

		var club_ids: Array = []
		for club_index in range(clubs_per_country):
			var club_id := _id("club", seed, [country_index, club_index])
			var club_name: String = "%s %s" % [COUNTRY_NAMES[country_index].split(" ")[0], CITY_WORDS[club_index % CITY_WORDS.size()]]
			if club_index >= CITY_WORDS.size():
				club_name += " %d" % (club_index + 1)
			var reputation_key := 100_000 + country_index * 100 + club_index
			var reputation := _rand_int(seed, reputation_key, 35, 75)
			world.clubs.append(Models.club(club_id, country_id, club_name, reputation))
			club_ids.append(club_id)
			_generate_staff(world, seed, country_index, club_index, club_id)
			_generate_players(world, seed, country_index, club_index, club_id, players_per_club)

		var competition_id := _id("competition", seed, [country_index])
		var competition_name := "%s Premier Division" % COUNTRY_NAMES[country_index]
		var competition: Dictionary = Models.competition(competition_id, country_id, competition_name, club_ids)
		competition["tier"] = 1
		world.competitions.append(competition)
		world.fixtures.append_array(_round_robin_fixtures(seed, country_index, competition_id, club_ids))

	_validate_references(world)
	return world

func _generate_staff(world: Dictionary, seed: int, country_index: int, club_index: int, club_id: String) -> void:
	for role_index in range(STAFF_ROLES.size()):
		var base_key := 1_000_000 + country_index * 100_000 + club_index * 1_000 + role_index * 10
		var first_name := FIRST_NAMES[_rand_int(seed, base_key + 1, 0, FIRST_NAMES.size() - 1)]
		var last_name := LAST_NAMES[_rand_int(seed, base_key + 2, 0, LAST_NAMES.size() - 1)]
		var ability := _rand_int(seed, base_key + 3, 35, 80)
		var staff_id := _id("staff", seed, [country_index, club_index, role_index])
		world.staff.append(Models.staff(staff_id, club_id, first_name + " " + last_name, STAFF_ROLES[role_index], ability))

func _generate_players(world: Dictionary, seed: int, country_index: int, club_index: int, club_id: String, count: int) -> void:
	for player_index in range(count):
		var base_key := 10_000_000 + country_index * 1_000_000 + club_index * 10_000 + player_index * 10
		var age := _rand_int(seed, base_key + 1, 17, 33)
		var ca := _rand_int(seed, base_key + 2, 35, 78)
		var potential_gain := _rand_int(seed, base_key + 3, 0, 25)
		var potential := mini(100, ca + potential_gain)
		var first_name := FIRST_NAMES[_rand_int(seed, base_key + 4, 0, FIRST_NAMES.size() - 1)]
		var last_name := LAST_NAMES[_rand_int(seed, base_key + 5, 0, LAST_NAMES.size() - 1)]
		var position: String = POSITIONS[player_index % POSITIONS.size()]
		var player_id := _id("player", seed, [country_index, club_index, player_index])
		var player: Dictionary = Models.player(player_id, club_id, first_name, last_name, age, position, ca, potential)
		world.players.append(player)

		var contract_id := _id("contract", seed, [country_index, club_index, player_index])
		var end_year := _rand_int(seed, base_key + 6, 2027, 2031)
		var weekly_wage := _rand_int(seed, base_key + 7, 500, 25_000)
		world.contracts.append(Models.contract(contract_id, player.id, club_id, 2026, end_year, weekly_wage))

func _round_robin_fixtures(seed: int, country_index: int, competition_id: String, input_club_ids: Array) -> Array:
	var teams: Array = input_club_ids.duplicate()
	var fixtures: Array = []
	var team_count: int = teams.size()
	for leg in range(2):
		for round_index in range(team_count - 1):
			for pair_index in range(int(team_count / 2)):
				var a: String = teams[pair_index]
				var b: String = teams[team_count - 1 - pair_index]
				var home: String = a if (round_index + pair_index + leg) % 2 == 0 else b
				var away: String = b if home == a else a
				var fixture_id := _id("fixture", seed, [country_index, leg, round_index, pair_index])
				var fixture: Dictionary = Models.fixture(fixture_id, competition_id, leg * (team_count - 1) + round_index + 1, home, away)
				fixture["season_year"] = 2026
				fixtures.append(fixture)
			var fixed: String = teams[0]
			var rotating: Array = teams.slice(1)
			rotating.push_front(rotating.pop_back())
			teams = [fixed]
			teams.append_array(rotating)
	return fixtures

func _rand_int(seed: int, key: int, min_value: int, max_value: int) -> int:
	assert(max_value >= min_value)
	var span := max_value - min_value + 1
	return min_value + (SeededRngClass.value_for(seed, key) % span)

func _id(prefix: String, seed: int, parts: Array) -> String:
	var result := prefix + "-" + str(seed)
	for part in parts:
		result += "-" + str(part)
	return result

func _validate_references(world: Dictionary) -> void:
	var country_ids := {}
	var club_ids := {}
	var player_ids := {}
	var competition_ids := {}
	for country in world.countries:
		assert(not country_ids.has(country.id))
		country_ids[country.id] = true
	for club in world.clubs:
		assert(country_ids.has(club.country_id))
		assert(not club_ids.has(club.id))
		club_ids[club.id] = true
	for player in world.players:
		assert(club_ids.has(player.club_id))
		assert(not player_ids.has(player.id))
		player_ids[player.id] = true
	for staff_member in world.staff:
		assert(club_ids.has(staff_member.club_id))
	for competition in world.competitions:
		assert(country_ids.has(competition.country_id))
		competition_ids[competition.id] = true
		for club_id in competition.club_ids:
			assert(club_ids.has(club_id))
	for contract in world.contracts:
		assert(player_ids.has(contract.player_id))
		assert(club_ids.has(contract.club_id))
	for fixture in world.fixtures:
		assert(competition_ids.has(fixture.competition_id))
		assert(club_ids.has(fixture.home_club_id))
		assert(club_ids.has(fixture.away_club_id))
		assert(fixture.home_club_id != fixture.away_club_id)
