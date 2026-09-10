extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const MatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")
const LeagueTableClass = preload("res://simulation/competitions/league_table.gd")
const CalendarClass = preload("res://core/calendar/calendar_service.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

var failures := 0
var checks := 0

func _init() -> void:
	print("[TEST] Football Dynasty Phase 1/2")
	_test_rng()
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

func _deep_equal(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if left is Dictionary:
		if left.size() != right.size():
			return false
		for key in left.keys():
			if not right.has(key) or not _deep_equal(left[key], right[key]):
				return false
		return true
	if left is Array:
		if left.size() != right.size():
			return false
		for i in range(left.size()):
			if not _deep_equal(left[i], right[i]):
				return false
		return true
	return left == right

func _test_rng() -> void:
	var a = SeededRngClass.new(12345)
	var b = SeededRngClass.new(12345)
	var c = SeededRngClass.new(54321)
	var same := true
	var different := false
	for _i in range(100):
		var av: int = a.randi_range(0, 1_000_000)
		var bv: int = b.randi_range(0, 1_000_000)
		var cv: int = c.randi_range(0, 1_000_000)
		if av != bv:
			same = false
		if av != cv:
			different = true
	_expect(same, "Same RNG seed must reproduce the same sequence")
	_expect(different, "Different RNG seed must produce a different sequence")

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
	_expect(_deep_equal(a, b), "Same seed must generate identical world")
	_expect(not _deep_equal(a, c), "Different seed must generate a different world")
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
	_expect(_deep_equal(first, second), "Match seed must reproduce identical match state and event stream")
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

func _club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if club.id == club_id:
			return club
	assert(false, "Club not found: %s" % club_id)
	return {}
