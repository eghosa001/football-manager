class_name LeagueSystem
extends RefCounted

const Models = preload("res://simulation/world/domain_models.gd")
const BackgroundMatchEngineClass = preload("res://simulation/match/background_aggregate_engine.gd")

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
	var playoff_matches: Array = []
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
			var playoff: Dictionary = _domestic_playoff(world, playoff_pool, String(lower.id), playoff_index)
			playoff_matches.append_array(playoff.get("matches", []))
			var winner := String(playoff.get("winner", ""))
			if winner == "" or winner in promoted: continue
			var upper_index := upper_table.size() - 1 - automatic - playoff_index
			if upper_index < 0: break
			promoted.append(winner)
			relegated.append(String(upper_table[upper_index].club_id))
			playoff_pool.erase(winner)

	var survival_playoff := mini(int(upper.get("relegation_playoff_places", 0)), int(lower.get("promotion_playoff_vs_upper", 0)))
	var survival_results: Array = []
	for playoff_index in range(survival_playoff):
		var upper_index := upper_table.size() - 1 - int(upper.get("relegation_places", automatic)) - playoff_index
		var lower_index := automatic + playoff_index
		if upper_index < 0 or lower_index >= lower_table.size(): continue
		var incumbent := String(upper_table[upper_index].club_id)
		var challenger := String(lower_table[lower_index].club_id)
		var match: Dictionary = _playoff_fixture(world, incumbent, challenger, String(upper.id), 10_000 + playoff_index)
		playoff_matches.append(match)
		var winner := String(match.get("winner", ""))
		var row := {"incumbent":incumbent,"challenger":challenger,"winner":winner,"promoted":false,"match":match}
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
		"playoff_matches":playoff_matches,
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

func _domestic_playoff(world: Dictionary, pool: Array, competition_id: String, salt: int) -> Dictionary:
	if pool.is_empty(): return {"winner":"","matches":[]}
	var entrants: Array = pool.duplicate()
	var matches: Array = []
	var round_index := 0
	while entrants.size() > 1 and round_index < 8:
		var next_round: Array = []
		# Preserve league seeding: highest remaining seed faces lowest. An odd
		# highest seed receives a bye rather than being discarded.
		var left := 0
		var right := entrants.size() - 1
		while left < right:
			var home := String(entrants[left])
			var away := String(entrants[right])
			var match := _playoff_fixture(world, home, away, competition_id, salt * 100 + round_index * 10 + left)
			match["round"] = round_index + 1
			matches.append(match)
			next_round.append(String(match.winner))
			left += 1
			right -= 1
		if left == right:
			next_round.append(String(entrants[left]))
		entrants = next_round
		round_index += 1
	return {"winner":String(entrants[0]) if entrants.size() == 1 else "", "matches":matches}

func _playoff_fixture(world: Dictionary, home_id: String, away_id: String, competition_id: String, salt: int) -> Dictionary:
	var home := _club(world, home_id)
	var away := _club(world, away_id)
	if home.is_empty(): home = {"id":home_id,"reputation":50}
	if away.is_empty(): away = {"id":away_id,"reputation":50}
	var year := int(world.get("season_year", 2026))
	var seed := _stable_hash("%s:%s:%s:%d:%d" % [competition_id,home_id,away_id,year,salt])
	var result: Dictionary = BackgroundMatchEngineClass.new().simulate_match(home, away, world.get("players", []), seed, {"competition_id":competition_id,"stage":"promotion_playoff"})
	var home_goals := int(result.get("home_goals", 0))
	var away_goals := int(result.get("away_goals", 0))
	var winner := ""
	var shootout_winner := ""
	if home_goals > away_goals:
		winner = home_id
	elif away_goals > home_goals:
		winner = away_id
	else:
		shootout_winner = home_id if posmod(_stable_hash("shootout:%s:%s:%d" % [home_id,away_id,seed]), 2) == 0 else away_id
		winner = shootout_winner
	return {"competition_id":competition_id,"season_year":year,"home_club_id":home_id,"away_club_id":away_id,"home_goals":home_goals,"away_goals":away_goals,"winner":winner,"shootout_winner":shootout_winner,"played":true,"model":String(result.get("model","inactive_aggregate")),"stats":result.get("stats",{})}

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return club
	return {}

func _club_reputation(world: Dictionary, club_id: String) -> int:
	var club := _club(world, club_id)
	return int(club.get("reputation", 50)) if not club.is_empty() else 50

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
	var teams: Array = input_club_ids.duplicate()
	var fixtures: Array = []
	var real_team_count := teams.size()
	assert(real_team_count >= 2)
	# Odd-sized divisions are valid in real football and can also arise after
	# sanctions/restructures. Add a deterministic bye slot instead of crashing.
	if teams.size() % 2 != 0:
		teams.append("")
	var schedule_count: int = teams.size()
	for leg in range(2):
		for round_index in range(schedule_count - 1):
			for pair_index in range(int(schedule_count / 2)):
				var a: String = String(teams[pair_index]); var b: String = String(teams[schedule_count-1-pair_index])
				if a == "" or b == "": continue
				var home: String = a if (round_index+pair_index+leg)%2==0 else b; var away: String = b if home==a else a
				var fixture_id := "fixture-%s-%d-%d-%d-%d" % [competition_id,season_year,leg,round_index,pair_index]
				var fixture: Dictionary = Models.fixture(fixture_id,competition_id,leg*(schedule_count-1)+round_index+1,home,away)
				fixture["season_year"] = season_year
				fixtures.append(fixture)
			var fixed_team: String = String(teams[0]); var rotating: Array = teams.slice(1); rotating.push_front(rotating.pop_back()); teams=[fixed_team]; teams.append_array(rotating)
	# A double round-robin always gives each real club 2*(N-1) matches,
	# regardless of whether the schedule required a bye slot.
	assert(fixtures.size() == real_team_count * (real_team_count - 1))
	return fixtures

func _stable_hash(text: String) -> int:
	var value := 97
	for c in text.to_utf8_buffer(): value = posmod(value * 191 + int(c), 2147483647)
	return value
