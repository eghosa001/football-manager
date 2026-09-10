class_name SeasonRunner
extends RefCounted

const AbstractMatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")
const TacticalMatchEngineClass = preload("res://simulation/match/tactical_match_engine.gd")
const LeagueTableClass = preload("res://simulation/competitions/league_table.gd")
const CalendarClass = preload("res://core/calendar/calendar_service.gd")
const LeagueSystemClass = preload("res://application/season/league_system.gd")
const KnockoutSeasonClass = preload("res://application/season/knockout_season.gd")

var _abstract_match_engine = AbstractMatchEngineClass.new()
var _tactical_match_engine = TacticalMatchEngineClass.new()
var _league_system = LeagueSystemClass.new()
var _knockout = KnockoutSeasonClass.new()

func play_next_fixture(world: Dictionary, competition_id: String, season_seed: int) -> Dictionary:
	for fixture in world.fixtures:
		if String(fixture.get("competition_id", "")) != competition_id or bool(fixture.get("played", false)): continue
		var row := _play_fixture(world, fixture, season_seed)
		_knockout.advance_ready(world, competition_id, String(fixture.get("date", world.get("date", "2026-07-01"))))
		return row
	return {}

func play_date(world: Dictionary, date_string: String, season_seed: int) -> Array:
	assign_fixture_dates(world)
	var results: Array = []
	var touched := {}
	for fixture in world.fixtures:
		if bool(fixture.get("played", false)) or String(fixture.get("date", "")) != date_string: continue
		results.append(_play_fixture(world, fixture, season_seed))
		touched[String(fixture.get("competition_id", ""))] = true
	for competition_id in touched.keys(): _knockout.advance_ready(world, String(competition_id), date_string)
	world["date"] = date_string
	return results

func advance_to_next_matchday(world: Dictionary, season_seed: int) -> Array:
	assign_fixture_dates(world)
	var next_date := ""
	for fixture in world.fixtures:
		if bool(fixture.get("played", false)): continue
		var fixture_date := String(fixture.get("date", ""))
		if next_date == "" or fixture_date < next_date: next_date = fixture_date
	if next_date == "": return []
	return play_date(world, next_date, season_seed)

func assign_fixture_dates(world: Dictionary, season_start_month: int = 8, season_start_day: int = 1) -> void:
	var year: int = int(world.get("season_year", _year_from_date(String(world.get("date", "2026-07-01")))))
	for fixture in world.fixtures:
		if String(fixture.get("date", "")) != "": continue
		var calendar = CalendarClass.new(); calendar.set_date(year, season_start_month, season_start_day); calendar.advance_days((int(fixture.get("round",1))-1)*7)
		fixture["date"] = calendar.get_date_string(); fixture["season_year"] = year

func complete_competition(world: Dictionary, competition_id: String, season_seed: int) -> Dictionary:
	while true:
		var played: Dictionary = play_next_fixture(world, competition_id, season_seed)
		if played.is_empty(): break
	return build_season_record(world, competition_id)

func complete_world_season(world: Dictionary, season_seed: int) -> Array:
	assign_fixture_dates(world)
	while true:
		var results: Array = advance_to_next_matchday(world, season_seed)
		if results.is_empty(): break
	var records: Array = []
	for competition in world.competitions: records.append(build_season_record(world, String(competition.id)))
	return records

func complete_and_rollover(world: Dictionary, history: Array, season_seed: int, promotion_places: int = 3) -> Dictionary:
	var records: Array = complete_world_season(world, season_seed)
	for record in records: history.append(record.duplicate(true))
	var movements: Array = _league_system.apply_promotion_relegation(world, records, promotion_places)
	var current_year: int = int(world.get("season_year", _year_from_date(String(world.get("date", "2026-07-01")))))
	_league_system.rollover(world, current_year + 1)
	preload("res://application/season/continental_competitions.gd").new().prepare(world, records)
	_knockout.initialize_all(world, current_year + 1)
	return {"records":records,"movements":movements,"next_season_year":current_year+1}

func build_season_record(world: Dictionary, competition_id: String) -> Dictionary:
	var competition: Dictionary = _find_competition(world.competitions, competition_id)
	if String(competition.get("competition_type", "league")) == "knockout": return _knockout.record(world, competition)
	var fixtures: Array = []
	for fixture in world.fixtures:
		if String(fixture.get("competition_id", "")) == competition_id: fixtures.append(fixture)
	var table: Array = LeagueTableClass.build(competition.club_ids, fixtures, int(competition.get("points_win",3)), int(competition.get("points_draw",1)))
	var complete := true
	for fixture in fixtures:
		if not bool(fixture.get("played", false)): complete = false; break
	var season_year: int = int(world.get("season_year", _year_from_date(String(world.get("date", "2026-07-01")))))
	return {"competition_id":competition_id,"competition_name":competition.name,"season_start_year":season_year,"tier":int(competition.get("tier",1)),"complete":complete,"fixture_count":fixtures.size(),"table":table,"champion_club_id":table[0].club_id if complete and not table.is_empty() else "","competition_type":"league"}

func _play_fixture(world: Dictionary, fixture: Dictionary, season_seed: int) -> Dictionary:
	var match_seed: int = _fixture_seed(season_seed, fixture)
	var home_club: Dictionary = _find_club(world.clubs, String(fixture.home_club_id)); var away_club: Dictionary = _find_club(world.clubs, String(fixture.away_club_id))
	var engine = _tactical_match_engine if home_club.has("tactic") or away_club.has("tactic") else _abstract_match_engine
	var result: Dictionary = engine.simulate_match(home_club, away_club, world.players, match_seed)
	engine.apply_to_fixture(fixture, result)
	return {"fixture":fixture,"result":result,"match_seed":match_seed}

func _fixture_seed(season_seed: int, fixture: Dictionary) -> int:
	var hash_value: int = season_seed
	for character in String(fixture.id).to_utf8_buffer(): hash_value = posmod(hash_value*31+int(character),2_147_483_647)
	return hash_value if hash_value != 0 else 1

func _year_from_date(date_string: String) -> int:
	var pieces := date_string.split("-")
	return int(pieces[0]) if not pieces.is_empty() else 2026

func _find_club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.id) == club_id: return club
	assert(false, "Club not found: %s" % club_id)
	return {}

func _find_competition(competitions: Array, competition_id: String) -> Dictionary:
	for competition in competitions:
		if String(competition.id) == competition_id: return competition
	assert(false, "Competition not found: %s" % competition_id)
	return {}
