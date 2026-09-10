extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const MatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")
const LeagueTableClass = preload("res://simulation/competitions/league_table.gd")
const CalendarClass = preload("res://core/calendar/calendar_service.gd")

var failures := 0
var checks := 0

func _init() -> void:
	print("[TEST] Football Dynasty Phase 1/2")
	_test_calendar()
	var world: Dictionary = _test_world_generation()
	_test_fixtures(world)
	_test_match_engine(world)
	_test_league_table(world)
	_test_match_distribution(world)
	if "--full-match-validation" in OS.get_cmdline_user_args():
		_test_match_distribution(world, 100_000)
	if failures == 0:
		print("[TEST] PASS — %d checks" % checks)
		quit(0)
	else:
		push_error("[TEST] FAIL — %d failures across %d checks" % [failures, checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[TEST] %s" % message)

func _test_calendar() -> void:
	var calendar = CalendarClass.new()
	calendar.set_date(2028, 2, 28)
	calendar.advance_days()
	_expect(calendar.get_date_string() == "2028-02-29", "Leap year handling")
	calendar.advance_days()
	_expect(calendar.get_date_string() == "2028-03-01", "Month rollover")

func _test_world_generation() -> Dictionary:
	var generator = WorldGeneratorClass.new()
	var a: Dictionary = generator.create_world(12345)
	var b: Dictionary = generator.create_world(12345)
	var c: Dictionary = generator.create_world(54321)
	_expect(a.countries.size() == 4, "Expected 4 countries")
	_expect(a.clubs.size() == 80, "Expected 80 clubs")
	_expect(a.players.size() == 2000, "Expected 2,000 players")
	_expect(a.staff.size() == 400, "Expected five staff per club")
	_expect(a.contracts.size() == 2000, "Expected one basic contract per player")
	_expect(a.competitions.size() == 4, "Expected one competition per country")
	_expect(_world_signature(a) == _world_signature(b), "Same seed must generate identical world")
	_expect(_world_signature(a) != _world_signature(c), "Different seed must generate a different world")
	return a

func _test_fixtures(world: Dictionary) -> void:
	_expect(world.fixtures.size() == 1520, "Four 20-club double round robins should create 1,520 fixtures")
	var pair_counts := {}
	for fixture in world.fixtures:
		var pair := [fixture.home_club_id, fixture.away_club_id]
		pair.sort()
		var key := "%s|%s" % [pair[0], pair[1]]
		pair_counts[key] = pair_counts.get(key, 0) + 1
	for count in pair_counts.values():
		_expect(count == 2, "Every league pairing should occur twice")

func _test_match_engine(world: Dictionary) -> void:
	var engine = MatchEngineClass.new()
	var home: Dictionary = world.clubs[0]
	var away: Dictionary = world.clubs[1]
	var first: Dictionary = engine.simulate_match(home, away, world.players, 827183927)
	var second: Dictionary = engine.simulate_match(home, away, world.players, 827183927)
	_expect(_match_signature(first) == _match_signature(second), "Match seed must reproduce identical event stream")
	_expect(first.lineups.home.size() == 11 and first.lineups.away.size() == 11, "Each starting lineup must contain 11 players")
	_expect(first.substitutions.size() <= 6, "Default match must not exceed three substitutions per side")
	_expect(first.stats.home.possession + first.stats.away.possession >= 99.9, "Possession should sum to approximately 100")
	_expect(first.home_goals == first.stats.home.goals, "Home goals must derive from shot events")
	_expect(first.away_goals == first.stats.away.goals, "Away goals must derive from shot events")

func _test_league_table(world: Dictionary) -> void:
	var engine = MatchEngineClass.new()
	var competition: Dictionary = world.competitions[0]
	var competition_fixtures: Array = []
	for fixture in world.fixtures:
		if fixture.competition_id == competition.id:
			competition_fixtures.append(fixture)
	for i in range(10):
		var fixture: Dictionary = competition_fixtures[i]
		var result: Dictionary = engine.simulate_match(_club(world.clubs, fixture.home_club_id), _club(world.clubs, fixture.away_club_id), world.players, 10_000 + i)
		engine.apply_to_fixture(fixture, result)
	var table: Array = LeagueTableClass.build(competition.club_ids, competition_fixtures)
	_expect(table.size() == 20, "League table should contain all 20 clubs")
	var previous_points := 999
	for row in table:
		_expect(row.points <= previous_points, "League table must sort by points first")
		_expect(row.points == row.won * 3 + row.drawn, "Points must equal wins×3 + draws")
		previous_points = row.points

func _test_match_distribution(world: Dictionary, sample_size: int = 2_000) -> void:
	var engine = MatchEngineClass.new()
	var total_goals := 0.0
	var total_shots := 0.0
	var total_cards := 0.0
	var home_wins := 0
	for i in range(sample_size):
		var home_index: int = (i * 2) % world.clubs.size()
		var away_index: int = (home_index + 1 + (i % 7)) % world.clubs.size()
		if away_index == home_index:
			away_index = (away_index + 1) % world.clubs.size()
		var result: Dictionary = engine.simulate_match(world.clubs[home_index], world.clubs[away_index], world.players, 900_000 + i)
		total_goals += result.home_goals + result.away_goals
		total_shots += result.stats.home.shots + result.stats.away.shots
		total_cards += result.stats.home.cards + result.stats.away.cards
		if result.home_goals > result.away_goals:
			home_wins += 1
	var avg_goals: float = total_goals / sample_size
	var avg_shots: float = total_shots / sample_size
	var avg_cards: float = total_cards / sample_size
	var home_win_rate: float = float(home_wins) / sample_size
	print("[MATCH VALIDATION] n=%d goals=%.2f shots=%.2f cards=%.2f home_win=%.3f" % [sample_size, avg_goals, avg_shots, avg_cards, home_win_rate])
	_expect(avg_goals >= 1.5 and avg_goals <= 4.0, "Average goals outside broad football range")
	_expect(avg_shots >= 8.0 and avg_shots <= 30.0, "Average shots outside broad football range")
	_expect(avg_cards >= 0.5 and avg_cards <= 6.0, "Average cards outside broad football range")
	_expect(home_win_rate >= 0.25 and home_win_rate <= 0.65, "Home win rate outside broad range")

func _world_signature(world: Dictionary) -> String:
	var parts: Array[String] = [str(world.seed), world.date]
	for country in world.countries:
		parts.append("C:%s:%s:%s:%d" % [country.id, country.name, country.code, country.youth_rating])
	for club in world.clubs:
		parts.append("B:%s:%s:%s:%d" % [club.id, club.country_id, club.name, club.reputation])
	for player in world.players:
		parts.append("P:%s:%s:%s:%s:%d:%s:%d:%d" % [player.id, player.club_id, player.first_name, player.last_name, player.age, player.position, player.current_ability, player.potential])
	for staff_member in world.staff:
		parts.append("S:%s:%s:%s:%s:%d" % [staff_member.id, staff_member.club_id, staff_member.name, staff_member.role, staff_member.ability])
	for competition in world.competitions:
		parts.append("L:%s:%s:%s:%s" % [competition.id, competition.country_id, competition.name, ",".join(competition.club_ids)])
	for contract in world.contracts:
		parts.append("K:%s:%s:%s:%d:%d:%d" % [contract.id, contract.player_id, contract.club_id, contract.start_year, contract.end_year, contract.weekly_wage])
	for fixture in world.fixtures:
		parts.append("F:%s:%s:%d:%s:%s" % [fixture.id, fixture.competition_id, fixture.round, fixture.home_club_id, fixture.away_club_id])
	return "|".join(parts)

func _match_signature(result: Dictionary) -> String:
	var parts: Array[String] = [
		str(result.seed), result.home_club_id, result.away_club_id,
		str(result.home_goals), str(result.away_goals),
		",".join(result.lineups.home), ",".join(result.lineups.away)
	]
	for event in result.events:
		parts.append("E:%d:%s:%s:%s:%s:%s:%s:%.3f" % [
			event.get("minute", 0), event.get("type", ""), event.get("side", ""),
			event.get("player_id", ""), event.get("outcome", ""), event.get("card", ""),
			event.get("player_in", ""), float(event.get("xg", 0.0))
		])
	return "|".join(parts)

func _club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if club.id == club_id:
			return club
	assert(false, "Club not found: %s" % club_id)
	return {}
