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

func create_world(seed: int, country_count: int = 4, clubs_per_country: int = 20, players_per_club: int = 25) -> Dictionary:
	assert(country_count > 0 and country_count <= COUNTRY_NAMES.size())
	assert(clubs_per_country >= 2 and clubs_per_country % 2 == 0)
	assert(players_per_club >= 11)
	var rng = SeededRngClass.new(seed)
	var world := {
		"seed": seed,
		"date": "2026-07-01",
		"countries": [],
		"clubs": [],
		"players": [],
		"staff": [],
		"competitions": [],
		"contracts": [],
		"fixtures": [],
	}

	for country_index in range(country_count):
		var country_id: String = rng.stable_id("country")
		var country = Models.country(country_id, COUNTRY_NAMES[country_index], COUNTRY_CODES[country_index], rng.randi_range(45, 82))
		world.countries.append(country)
		var club_ids: Array = []
		for club_index in range(clubs_per_country):
			var club_id: String = rng.stable_id("club")
			var club_name := "%s %s" % [COUNTRY_NAMES[country_index].split(" ")[0], CITY_WORDS[club_index % CITY_WORDS.size()]]
			if club_index >= CITY_WORDS.size():
				club_name += " %d" % (club_index + 1)
			var club = Models.club(club_id, country_id, club_name, rng.randi_range(35, 75))
			world.clubs.append(club)
			club_ids.append(club_id)
			_generate_staff(world, rng, club_id)
			_generate_players(world, rng, club_id, players_per_club)

		var competition_id: String = rng.stable_id("competition")
		world.competitions.append(Models.competition(competition_id, country_id, "%s Premier Division" % COUNTRY_NAMES[country_index], club_ids))
		world.fixtures.append_array(_round_robin_fixtures(rng, competition_id, club_ids))

	_validate_references(world)
	return world

func _generate_staff(world: Dictionary, rng, club_id: String) -> void:
	for role in ["manager", "assistant", "coach", "scout", "physio"]:
		var name := "%s %s" % [rng.pick(FIRST_NAMES), rng.pick(LAST_NAMES)]
		world.staff.append(Models.staff(rng.stable_id("staff"), club_id, name, role, rng.randi_range(35, 80)))

func _generate_players(world: Dictionary, rng, club_id: String, count: int) -> void:
	for player_index in range(count):
		var age := rng.randi_range(17, 33)
		var ca := rng.randi_range(35, 78)
		var potential := mini(100, ca + rng.randi_range(0, 25))
		var position: String = POSITIONS[player_index % POSITIONS.size()]
		var player = Models.player(
			rng.stable_id("player"), club_id,
			rng.pick(FIRST_NAMES), rng.pick(LAST_NAMES), age, position, ca, potential
		)
		world.players.append(player)
		world.contracts.append(Models.contract(rng.stable_id("contract"), player.id, club_id, 2026, rng.randi_range(2027, 2031), rng.randi_range(500, 25_000)))

func _round_robin_fixtures(rng, competition_id: String, input_club_ids: Array) -> Array:
	var teams := input_club_ids.duplicate()
	var fixtures: Array = []
	var team_count := teams.size()
	for leg in range(2):
		for round_index in range(team_count - 1):
			for pair_index in range(int(team_count / 2)):
				var a: String = teams[pair_index]
				var b: String = teams[team_count - 1 - pair_index]
				var home := a if (round_index + pair_index + leg) % 2 == 0 else b
				var away := b if home == a else a
				fixtures.append(Models.fixture(rng.stable_id("fixture"), competition_id, leg * (team_count - 1) + round_index + 1, home, away))
			var fixed = teams[0]
			var rotating := teams.slice(1)
			rotating.push_front(rotating.pop_back())
			teams = [fixed]
			teams.append_array(rotating)
	return fixtures

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
