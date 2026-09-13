class_name ManagedMatchdayCoordinator
extends RefCounted

const Calendar = preload("res://core/calendar/calendar_service.gd")
const SeasonRunner = preload("res://application/season/season_runner.gd")
const MatchdayService = preload("res://application/career/career_matchday_service.gd")
const MatchSession = preload("res://simulation/match/managed_match_session.gd")
const DetailedEngine = preload("res://simulation/match/full_match_engine_v2.gd")
const PlayerStats = preload("res://application/career/player_stats_service.gd")
const DailyServices = preload("res://application/career/daily_services.gd")
const RecruitmentDaily = preload("res://application/career/recruitment_daily.gd")
const Inbox = preload("res://application/career/inbox_service.gd")
const NewsConsumer = preload("res://application/career/news_event_consumer.gd")
const KnockoutSeason = preload("res://application/season/knockout_season.gd")
const TierPolicy = preload("res://application/performance/simulation_tier_policy.gd")

var fixture: Dictionary = {}
var target_date := ""
var managed_club_id := ""
var season_seed := 1
var fixture_seed := 1
var service
var match
var home: Dictionary = {}
var away: Dictionary = {}
var eligible_players: Array = []
var context: Dictionary = {}

func has_live_match_tomorrow(world: Dictionary, club_id: String) -> bool:
	return not next_managed_fixture(world,club_id).is_empty()

func next_managed_fixture(world: Dictionary, club_id: String) -> Dictionary:
	if world.is_empty() or club_id == "": return {}
	SeasonRunner.new().assign_fixture_dates(world)
	var date := _next_date(String(world.get("date","2026-07-01")))
	if date == "": return {}
	var season_year := int(world.get("season_year",2026))
	# Let the normal DayRunner own season rollover validation and generation.
	if date >= "%04d-07-01" % (season_year + 1): return {}
	for row in world.get("fixtures",[]):
		if bool(row.get("played",false)) or String(row.get("date","")) != date: continue
		if String(row.get("home_club_id","")) == club_id or String(row.get("away_club_id","")) == club_id:
			return row
	return {}

func start(world: Dictionary, club_id: String, seed: int) -> Dictionary:
	managed_club_id = club_id
	season_seed = seed
	fixture = next_managed_fixture(world,club_id)
	if fixture.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	target_date = String(fixture.get("date",""))
	service = MatchdayService.new()
	service._build_indexes(world)
	home = service._club(world,String(fixture.get("home_club_id","")))
	away = service._club(world,String(fixture.get("away_club_id","")))
	if home.is_empty() or away.is_empty(): return {"error":ERR_INVALID_DATA}
	var competition_id := String(fixture.get("competition_id",""))
	eligible_players = service._eligible_match_players(world,String(home.id),String(away.id),competition_id)
	context = service._match_context(world,fixture,home,away)
	fixture_seed = service._fixture_seed(seed,String(fixture.get("id","")))
	match = MatchSession.new()
	var started: Dictionary = match.start_match(home,away,eligible_players,fixture_seed,context)
	started["fixture"] = fixture.duplicate(true)
	started["home_name"] = String(home.get("name","Home"))
	started["away_name"] = String(away.get("name","Away"))
	started["managed_side"] = "home" if String(home.id) == managed_club_id else "away"
	return started

func advance(target_minute: int) -> Dictionary:
	if match == null: return {"error":ERR_UNCONFIGURED}
	return match.advance_to_minute(target_minute)

func substitute(player_out: String, player_in: String) -> Error:
	if match == null: return ERR_UNCONFIGURED
	var side := "home" if String(home.get("id","")) == managed_club_id else "away"
	return match.make_substitution(side,player_out,player_in)

func change_tactic(tactic: Dictionary) -> Error:
	if match == null: return ERR_UNCONFIGURED
	var side := "home" if String(home.get("id","")) == managed_club_id else "away"
	return match.change_tactic(side,tactic)

func snapshot() -> Dictionary:
	if match == null: return {"error":ERR_UNCONFIGURED}
	var data: Dictionary = match.snapshot()
	data["fixture"] = fixture.duplicate(true)
	data["home_name"] = String(home.get("name","Home"))
	data["away_name"] = String(away.get("name","Away"))
	data["managed_side"] = "home" if String(home.get("id","")) == managed_club_id else "away"
	return data

func commit(world: Dictionary) -> Dictionary:
	if match == null or fixture.is_empty(): return {"error":ERR_UNCONFIGURED}
	var result: Dictionary = match.finish_match()
	if result.has("error"): return result
	service._build_indexes(world)
	DetailedEngine.new().apply_to_fixture(fixture,result)
	PlayerStats.new().record_match(world,fixture,result)
	service._apply_dressing_room_result(world,home,away,result)
	service._apply_match_load(world,result)
	service._apply_suspensions(world,fixture,result,target_date)
	service._update_club_form(world,home,away,result)
	result["injuries"] = service._apply_match_injuries(world,fixture,result,TierPolicy.USER_LEAGUE,fixture_seed,managed_club_id)
	service._emit_match_events(world,fixture,result,TierPolicy.USER_LEAGUE,"managed_incremental_2d",target_date)
	service._add_match_message(world,home,away,result,managed_club_id)
	world["last_managed_match"] = {"fixture":fixture.duplicate(true),"result":result.duplicate(true),"date":target_date,"model":"managed_incremental_2d","simulation_tier":TierPolicy.USER_LEAGUE}
	KnockoutSeason.new().advance_ready(world,String(fixture.get("competition_id","")),target_date)
	# The managed fixture is already marked played, so the normal service now
	# simulates only the other fixtures scheduled for the same date.
	var background: Array = service.play_date(world,target_date,managed_club_id,season_seed)
	var all_results: Array = [{"fixture":fixture,"result":result,"match_seed":fixture_seed,"detailed":true,"model":"managed_incremental_2d","simulation_tier":TierPolicy.USER_LEAGUE}]
	all_results.append_array(background)
	var services: Dictionary = DailyServices.new().run(world,managed_club_id,season_seed)
	services["recruitment"] = RecruitmentDaily.new().run(world,managed_club_id,season_seed+41_003)
	var messages: Array = Inbox.new().generate_daily(world,all_results)
	var news: Dictionary = NewsConsumer.new().consume(world)
	return {"date":target_date,"fixtures_played":all_results.size(),"results":all_results,"services":services,"messages":messages,"news":news,"managed_result":result}

func _next_date(date_string: String) -> String:
	var parts := date_string.split("-")
	if parts.size() != 3: return ""
	var calendar = Calendar.new()
	calendar.set_date(int(parts[0]),int(parts[1]),int(parts[2]))
	calendar.advance_days(1)
	return calendar.get_date_string()
