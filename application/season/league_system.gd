class_name LeagueSystem
extends RefCounted

const Models = preload("res://simulation/world/domain_models.gd")

# Applies movement between adjacent tiers in the same country. Competitions that
# do not define a tier are treated as tier 1 and remain unchanged when no lower
# tier exists. This keeps the Phase 1 single-division default world valid.
func apply_promotion_relegation(world: Dictionary, season_records: Array, places: int = 3) -> Array:
	var movements: Array = []
	var records_by_competition := {}
	for record in season_records:
		records_by_competition[String(record.competition_id)] = record

	var by_country := {}
	for competition in world.competitions:
		var country_id := String(competition.country_id)
		if not by_country.has(country_id):
			by_country[country_id] = []
		by_country[country_id].append(competition)

	for country_id in by_country.keys():
		var leagues: Array = by_country[country_id]
		leagues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("tier", 1)) < int(b.get("tier", 1))
		)
		for i in range(leagues.size() - 1):
			var upper: Dictionary = leagues[i]
			var lower: Dictionary = leagues[i + 1]
			if not records_by_competition.has(String(upper.id)) or not records_by_competition.has(String(lower.id)):
				continue
			var upper_record: Dictionary = records_by_competition[String(upper.id)]
			var lower_record: Dictionary = records_by_competition[String(lower.id)]
			if not bool(upper_record.get("complete", false)) or not bool(lower_record.get("complete", false)):
				continue
			var move_count: int = mini(places, mini(upper.club_ids.size(), lower.club_ids.size()))
			if move_count <= 0:
				continue
			var relegated: Array = []
			var promoted: Array = []
			for index in range(move_count):
				relegated.append(String(upper_record.table[upper_record.table.size() - 1 - index].club_id))
				promoted.append(String(lower_record.table[index].club_id))
			for club_id in relegated:
				upper.club_ids.erase(club_id)
				lower.club_ids.append(club_id)
			for club_id in promoted:
				lower.club_ids.erase(club_id)
				upper.club_ids.append(club_id)
			movements.append({
				"country_id": country_id,
				"upper_competition_id": upper.id,
				"lower_competition_id": lower.id,
				"promoted": promoted,
				"relegated": relegated,
			})
	return movements

func rollover(world: Dictionary, next_season_year: int, first_match_date: String = "") -> void:
	assert(next_season_year > 0)
	world["season_year"] = next_season_year
	world["date"] = first_match_date if first_match_date != "" else "%04d-07-01" % next_season_year
	world.fixtures = _build_all_fixtures(world, next_season_year)

func _build_all_fixtures(world: Dictionary, season_year: int) -> Array:
	var fixtures: Array = []
	for competition in world.competitions:
		fixtures.append_array(_round_robin(String(competition.id), competition.club_ids, season_year))
	return fixtures

func _round_robin(competition_id: String, input_club_ids: Array, season_year: int) -> Array:
	var teams: Array = input_club_ids.duplicate()
	var fixtures: Array = []
	var team_count: int = teams.size()
	assert(team_count >= 2 and team_count % 2 == 0)
	for leg in range(2):
		for round_index in range(team_count - 1):
			for pair_index in range(int(team_count / 2)):
				var a: String = String(teams[pair_index])
				var b: String = String(teams[team_count - 1 - pair_index])
				var home: String = a if (round_index + pair_index + leg) % 2 == 0 else b
				var away: String = b if home == a else a
				var fixture_id := "fixture-%s-%d-%d-%d-%d" % [competition_id, season_year, leg, round_index, pair_index]
				var fixture: Dictionary = Models.fixture(fixture_id, competition_id, leg * (team_count - 1) + round_index + 1, home, away)
				fixture["season_year"] = season_year
				fixtures.append(fixture)
			var fixed: String = String(teams[0])
			var rotating: Array = teams.slice(1)
			rotating.push_front(rotating.pop_back())
			teams = [fixed]
			teams.append_array(rotating)
	return fixtures
