class_name SeasonRunner
extends RefCounted

const AbstractMatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")
const TacticalMatchEngineClass = preload("res://simulation/match/tactical_match_engine.gd")
const LeagueTableClass = preload("res://simulation/competitions/league_table.gd")
const DisciplineServiceClass = preload("res://simulation/competitions/discipline_service.gd")
const ModernRulesClass = preload("res://simulation/competitions/modern_rules_catalog.gd")
const CalendarClass = preload("res://core/calendar/calendar_service.gd")
const LeagueSystemClass = preload("res://application/season/league_system.gd")
const KnockoutSeasonClass = preload("res://application/season/knockout_season.gd")
const ContinentalLeaguePhaseClass = preload("res://application/season/continental_league_phase.gd")
const RegionalContinentalEngineClass = preload("res://application/season/regional_continental_engine.gd")
const ContinentalCompetitionsClass = preload("res://application/season/continental_competitions.gd")
const ClubWorldCupClass = preload("res://application/season/club_world_cup.gd")

var _abstract_match_engine = AbstractMatchEngineClass.new()
var _tactical_match_engine = TacticalMatchEngineClass.new()
var _league_system = LeagueSystemClass.new()
var _knockout = KnockoutSeasonClass.new()
var _continental_phase = ContinentalLeaguePhaseClass.new()
var _regional_continental = RegionalContinentalEngineClass.new()
var _club_world_cup = ClubWorldCupClass.new()
var _discipline = DisciplineServiceClass.new()
var _modern_rules = ModernRulesClass.new()

func play_next_fixture(world: Dictionary, competition_id: String, season_seed: int) -> Dictionary:
	for fixture in world.fixtures:
		if String(fixture.get("competition_id", "")) != competition_id or bool(fixture.get("played", false)): continue
		var row := _play_fixture(world, fixture, season_seed)
		var date := String(fixture.get("date", world.get("date", "2026-07-01")))
		_advance_competition(world,competition_id,date)
		return row
	return {}

func play_date(world: Dictionary, date_string: String, season_seed: int, player_index: Dictionary = {}) -> Array:
	assign_fixture_dates(world)
	var results: Array = []
	var touched := {}
	for fixture in world.fixtures:
		if bool(fixture.get("played", false)) or String(fixture.get("date", "")) != date_string: continue
		results.append(_play_fixture(world, fixture, season_seed, player_index))
		touched[String(fixture.get("competition_id", ""))] = true
	for competition_id in touched.keys(): _advance_competition(world,String(competition_id),date_string)
	world["date"] = date_string
	return results

func advance_to_next_matchday(world: Dictionary, season_seed: int, player_index: Dictionary = {}) -> Array:
	assign_fixture_dates(world)
	var next_date := ""
	for fixture in world.fixtures:
		if bool(fixture.get("played", false)): continue
		var fixture_date := String(fixture.get("date", ""))
		if next_date == "" or fixture_date < next_date: next_date = fixture_date
	if next_date == "": return []
	return play_date(world, next_date, season_seed, player_index)

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
	var player_index := _index_players_by_club(world.get("players", []))
	while true:
		var results: Array = advance_to_next_matchday(world, season_seed, player_index)
		if results.is_empty(): break
	var records: Array = []
	for competition in world.competitions: records.append(build_season_record(world, String(competition.id)))
	return records

func complete_and_rollover(world: Dictionary, history: Array, season_seed: int, promotion_places: int = 3) -> Dictionary:
	var records: Array = complete_world_season(world, season_seed)
	for record in records: history.append(record.duplicate(true))
	var movements: Array = _league_system.apply_promotion_relegation(world, records, promotion_places)
	var current_year: int = int(world.get("season_year", _year_from_date(String(world.get("date", "2026-07-01")))))
	var next_year := current_year + 1
	_league_system.rollover(world, next_year)
	_discipline.reset_season(world,next_year,true)
	var continental = ContinentalCompetitionsClass.new()
	continental.prepare(world, records)
	continental.initialize_formats(world,next_year,true)
	_knockout.initialize_all(world, next_year)
	return {"records":records,"movements":movements,"next_season_year":next_year}

func build_season_record(world: Dictionary, competition_id: String) -> Dictionary:
	var competition: Dictionary = _find_competition(world.competitions, competition_id)
	var competition_type := String(competition.get("competition_type", "league"))
	if competition_type == "knockout": return _knockout.record(world, competition)
	if competition_type == "continental_league_phase": return _continental_phase.record(world,competition)
	if competition_type == "regional_continental": return _regional_continental.record(world,competition)
	if competition_type == "club_world_cup": return _club_world_cup.record(world,competition)
	var fixtures: Array = []
	for fixture in world.fixtures:
		if String(fixture.get("competition_id", "")) == competition_id: fixtures.append(fixture)
	var tie_breakers: Array = competition.get("tie_breakers",["points","goal_difference","goals_scored","wins","head_to_head_points"])
	var table: Array = LeagueTableClass.build(competition.club_ids, fixtures, int(competition.get("points_win",3)), int(competition.get("points_draw",1)),tie_breakers)
	var complete := true
	for fixture in fixtures:
		if not bool(fixture.get("played", false)): complete = false; break
	var season_year: int = int(world.get("season_year", _year_from_date(String(world.get("date", "2026-07-01")))))
	return {"competition_id":competition_id,"competition_name":competition.name,"season_start_year":season_year,"tier":int(competition.get("tier",1)),"complete":complete,"fixture_count":fixtures.size(),"table":table,"champion_club_id":table[0].club_id if complete and not table.is_empty() else "","competition_type":"league"}

func _play_fixture(world: Dictionary, fixture: Dictionary, season_seed: int, player_index: Dictionary = {}) -> Dictionary:
	var match_seed: int = _fixture_seed(season_seed, fixture)
	var home_club: Dictionary = _find_club(world.clubs, String(fixture.home_club_id)); var away_club: Dictionary = _find_club(world.clubs, String(fixture.away_club_id))
	var engine = _tactical_match_engine if home_club.has("tactic") or away_club.has("tactic") else _abstract_match_engine
	var competition := _find_competition(world.competitions,String(fixture.get("competition_id","")))
	var competition_id := String(competition.get("id",""))
	var home_suspended := _suspended_ids(world,competition_id,String(home_club.id),player_index)
	var away_suspended := _suspended_ids(world,competition_id,String(away_club.id),player_index)
	var match_players := _eligible_match_players(world,competition_id,String(home_club.id),String(away_club.id),player_index)
	if _count_club_players(match_players,String(home_club.id)) < 11 or _count_club_players(match_players,String(away_club.id)) < 11:
		fixture["emergency_selection"] = true
		match_players = _emergency_match_players(world,String(home_club.id),String(away_club.id),player_index)
	var context := {"importance":_importance(competition,fixture),"stage":String(fixture.get("stage","")),"knockout":bool(fixture.get("knockout",false)) or bool(fixture.get("continental_knockout",false)) or bool(fixture.get("regional_knockout",false))}
	var result: Dictionary = engine.simulate_match(home_club, away_club, match_players, match_seed, context)
	engine.apply_to_fixture(fixture, result)
	fixture["match_seed"] = match_seed
	fixture["regulation_result"] = {"home_goals":int(result.get("home_goals",0)),"away_goals":int(result.get("away_goals",0))}
	_discipline.serve_fixture(world,competition_id,home_suspended,String(fixture.get("id","")))
	_discipline.serve_fixture(world,competition_id,away_suspended,String(fixture.get("id","")))
	_discipline.apply_match(world,competition_id,String(fixture.get("id","")),result.get("events",[]),_modern_rules.modern_rules_for(competition))
	return {"fixture":fixture,"result":result,"match_seed":match_seed}

func _advance_competition(world: Dictionary, competition_id: String, date_string: String) -> void:
	var competition := _find_competition(world.get("competitions",[]),competition_id)
	match String(competition.get("competition_type","league")):
		"knockout": _knockout.advance_ready(world,competition_id,date_string)
		"continental_league_phase": _continental_phase.advance_ready(world,competition_id,date_string)
		"regional_continental": _regional_continental.advance_ready(world,competition_id,date_string)
		"club_world_cup": _club_world_cup.advance_ready(world,competition_id,date_string)

func _eligible_match_players(world: Dictionary, competition_id: String, home_id: String, away_id: String, player_index: Dictionary) -> Array:
	var source: Array = world.get("players",[])
	if not player_index.is_empty():
		source=[]; source.append_array(player_index.get(home_id,[])); source.append_array(player_index.get(away_id,[]))
	var result: Array=[]
	for player in source:
		var club_id := String(player.get("club_id",""))
		if club_id not in [home_id,away_id]: continue
		if bool(player.get("retired",false)) or int(player.get("injured_days",0)) > 0: continue
		if _discipline.is_suspended(world,competition_id,String(player.get("id",""))): continue
		result.append(player)
	return result

func _emergency_match_players(world: Dictionary, home_id: String, away_id: String, player_index: Dictionary) -> Array:
	var source: Array = world.get("players",[])
	if not player_index.is_empty():
		source=[]; source.append_array(player_index.get(home_id,[])); source.append_array(player_index.get(away_id,[]))
	var result: Array=[]
	for player in source:
		if String(player.get("club_id","")) in [home_id,away_id] and not bool(player.get("retired",false)): result.append(player)
	return result

func _suspended_ids(world: Dictionary, competition_id: String, club_id: String, player_index: Dictionary) -> Array:
	var source: Array = player_index.get(club_id,[]) if not player_index.is_empty() else world.get("players",[])
	var ids: Array=[]
	for player in source:
		if String(player.get("club_id","")) == club_id and _discipline.is_suspended(world,competition_id,String(player.get("id",""))): ids.append(String(player.get("id","")))
	return ids

func _count_club_players(players: Array, club_id: String) -> int:
	var count:=0
	for player in players:
		if String(player.get("club_id","")) == club_id: count += 1
	return count

func _importance(competition: Dictionary, fixture: Dictionary) -> float:
	var stage := String(fixture.get("stage",""))
	if stage == "final": return 1.0
	if stage in ["semifinal","quarterfinal","round_of_16","knockout_playoff"]: return 0.90
	if bool(competition.get("continental",false)): return 0.82
	if bool(fixture.get("knockout",false)): return 0.78
	return 0.55

func _index_players_by_club(players: Array) -> Dictionary:
	var index := {}
	for player in players:
		var club_id := String(player.get("club_id", ""))
		if club_id == "": continue
		if not index.has(club_id): index[club_id] = []
		index[club_id].append(player)
	return index

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
