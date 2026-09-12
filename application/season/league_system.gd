class_name LeagueSystem
extends RefCounted

const Models = preload("res://simulation/world/domain_models.gd")

func apply_promotion_relegation(world: Dictionary, season_records: Array, places: int = 3) -> Array:
	var movements: Array = []
	var records_by_competition := {}
	for record in season_records:
		records_by_competition[String(record.competition_id)] = record
	var by_country := {}
	for competition in world.competitions:
		if String(competition.get("competition_type", "league")) != "league": continue
		var country_id := String(competition.country_id)
		if not by_country.has(country_id): by_country[country_id] = []
		by_country[country_id].append(competition)
	for country_id in by_country.keys():
		var leagues: Array = by_country[country_id]
		leagues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("tier",1)) < int(b.get("tier",1)))
		for i in range(leagues.size() - 1):
			var upper: Dictionary = leagues[i]
			var lower: Dictionary = leagues[i+1]
			if not records_by_competition.has(String(upper.id)) or not records_by_competition.has(String(lower.id)): continue
			var upper_record: Dictionary = records_by_competition[String(upper.id)]
			var lower_record: Dictionary = records_by_competition[String(lower.id)]
			if not bool(upper_record.get("complete",false)) or not bool(lower_record.get("complete",false)): continue
			var movement := _movement_for_pair(world, country_id, upper, lower, upper_record, lower_record, places)
			if not movement.is_empty(): movements.append(movement)
	return movements

func _movement_for_pair(world: Dictionary, country_id: String, upper: Dictionary, lower: Dictionary, upper_record: Dictionary, lower_record: Dictionary, fallback_places: int) -> Dictionary:
	var upper_table: Array = upper_record.get("table", [])
	var lower_table: Array = lower_record.get("table", [])
	if upper_table.is_empty() or lower_table.is_empty(): return {}
	var total_promotion := int(lower.get("promotion_places", fallback_places))
	var automatic := int(lower.get("automatic_promotion_places", total_promotion))
	automatic = mini(automatic, int(upper.get("relegation_places", fallback_places)))
	automatic = mini(automatic, mini(upper_table.size(), lower_table.size()))
	var promoted: Array = []
	var relegated: Array = []
	var direct_promoted: Array = []
	var direct_relegated: Array = []
	for index in range(automatic):
		direct_promoted.append(String(lower_table[index].club_id))
		direct_relegated.append(String(upper_table[upper_table.size() - 1 - index].club_id))
	promoted.append_array(direct_promoted)
	relegated.append_array(direct_relegated)

	var playoff_count := int(lower.get("playoff_promotion_places", 0))
	if playoff_count > 0:
		var playoff_pool := _playoff_pool(lower_table, lower.get("playoff_places", []), automatic)
		for playoff_index in range(playoff_count):
			if playoff_pool.is_empty(): break
			var winner := _domestic_playoff_winner(world, playoff_pool, String(lower.id), playoff_index)
			if winner == "" or winner in promoted: continue
			var upper_index := upper_table.size() - 1 - automatic - playoff_index
			if upper_index < 0: break
			promoted.append(winner)
			relegated.append(String(upper_table[upper_index].club_id))

	var survival_playoff := mini(int(upper.get("relegation_playoff_places", 0)), int(lower.get("promotion_playoff_vs_upper", 0)))
	var survival_results: Array = []
	for playoff_index in range(survival_playoff):
		var upper_index := upper_table.size() - 1 - int(upper.get("relegation_places", automatic)) - playoff_index
		var lower_index := automatic + playoff_index
		if upper_index < 0 or lower_index >= lower_table.size(): continue
		var incumbent := String(upper_table[upper_index].club_id)
		var challenger := String(lower_table[lower_index].club_id)
		var winner := _two_club_playoff_winner(world, incumbent, challenger, String(upper.id), playoff_index)
		var row := {"incumbent":incumbent,"challenger":challenger,"winner":winner,"promoted":false}
		if winner == challenger:
			promoted.append(challenger)
			relegated.append(incumbent)
			row.promoted = true
		survival_results.append(row)

	if promoted.is_empty() and relegated.is_empty(): return {}
	for club_id in relegated:
		upper.club_ids.erase(club_id)
		if club_id not in lower.club_ids: lower.club_ids.append(club_id)
	for club_id in promoted:
		lower.club_ids.erase(club_id)
		if club_id not in upper.club_ids: upper.club_ids.append(club_id)
	return {
		"country_id":country_id,
		"upper_competition_id":upper.id,
		"lower_competition_id":lower.id,
		"promoted":promoted,
		"relegated":relegated,
		"automatic_promoted":direct_promoted,
		"automatic_relegated":direct_relegated,
		"playoff_promoted":promoted.filter(func(id): return id not in direct_promoted),
		"survival_playoffs":survival_results
	}

func _playoff_pool(table: Array, configured: Variant, automatic: int) -> Array:
	var result: Array = []
	var start := automatic
	var end := mini(table.size() - 1, automatic + 3)
	if configured is Array and (configured as Array).size() >= 2:
		start = maxi(0, int(configured[0]) - 1)
		end = mini(table.size() - 1, int(configured[1]) - 1)
	for index in range(start, end + 1): result.append(String(table[index].club_id))
	return result

func _domestic_playoff_winner(world: Dictionary, pool: Array, competition_id: String, salt: int) -> String:
	if pool.is_empty(): return ""
	var best := String(pool[0])
	var best_score := -1
	for index in range(pool.size()):
		var id := String(pool[index])
		var score := _club_reputation(world, id) * 10 + (pool.size() - index) * 6 + posmod(_stable_hash("%s:%s:%d" % [competition_id,id,salt]), 37)
		if score > best_score:
			best = id
			best_score = score
	return best

func _two_club_playoff_winner(world: Dictionary, incumbent: String, challenger: String, competition_id: String, salt: int) -> String:
	var incumbent_score := _club_reputation(world, incumbent) * 10 + posmod(_stable_hash("%s:%s:%d" % [competition_id,incumbent,salt]), 61)
	var challenger_score := _club_reputation(world, challenger) * 10 + posmod(_stable_hash("%s:%s:%d" % [competition_id,challenger,salt]), 61)
	return challenger if challenger_score > incumbent_score else incumbent

func _club_reputation(world: Dictionary, club_id: String) -> int:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return int(club.get("reputation", 50))
	return 50

func rollover(world: Dictionary, next_season_year: int, first_match_date: String = "") -> void:
	assert(next_season_year > 0)
	world["season_year"] = next_season_year
	world["date"] = first_match_date if first_match_date != "" else "%04d-07-01" % next_season_year
	world.fixtures = _build_league_fixtures(world, next_season_year)

func _build_league_fixtures(world: Dictionary, season_year: int) -> Array:
	var fixtures: Array = []
	for competition in world.competitions:
		if String(competition.get("competition_type", "league")) != "league": continue
		fixtures.append_array(_round_robin(String(competition.id), competition.club_ids, season_year))
	return fixtures

func _round_robin(competition_id: String, input_club_ids: Array, season_year: int) -> Array:
	var teams: Array = input_club_ids.duplicate(); var fixtures: Array = []; var team_count: int = teams.size()
	assert(team_count >= 2 and team_count % 2 == 0)
	for leg in range(2):
		for round_index in range(team_count - 1):
			for pair_index in range(int(team_count / 2)):
				var a: String = String(teams[pair_index]); var b: String = String(teams[team_count-1-pair_index])
				var home: String = a if (round_index+pair_index+leg)%2==0 else b; var away: String = b if home==a else a
				var fixture_id := "fixture-%s-%d-%d-%d-%d" % [competition_id,season_year,leg,round_index,pair_index]
				var fixture: Dictionary = Models.fixture(fixture_id,competition_id,leg*(team_count-1)+round_index+1,home,away)
				fixture["season_year"] = season_year
				fixtures.append(fixture)
			var fixed_team: String = String(teams[0]); var rotating: Array = teams.slice(1); rotating.push_front(rotating.pop_back()); teams=[fixed_team]; teams.append_array(rotating)
	return fixtures

func _stable_hash(text: String) -> int:
	var value := 97
	for c in text.to_utf8_buffer(): value = posmod(value * 191 + int(c), 2147483647)
	return value
