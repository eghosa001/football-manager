extends RefCounted

const CALENDAR_PATH = "res://core/calendar/calendar_service.gd"
const SEASON_RUNNER_PATH = "res://application/season/season_runner.gd"
const MATCHDAY_SERVICE_PATH = "res://application/career/career_matchday_service.gd"
const MATCH_SESSION_PATH = "res://simulation/match/managed_match_session.gd"
const PLAYER_STATS_PATH = "res://application/career/player_stats_service.gd"
const DAILY_SERVICES_PATH = "res://application/career/daily_services.gd"
const RECRUITMENT_DAILY_PATH = "res://application/career/recruitment_daily.gd"
const INBOX_PATH = "res://application/career/inbox_service.gd"
const NEWS_CONSUMER_PATH = "res://application/career/news_event_consumer.gd"
const KNOCKOUT_PATH = "res://application/season/knockout_season.gd"
const TIER_POLICY_PATH = "res://application/performance/simulation_tier_policy.gd"

var fixture = {}
var target_date = ""
var managed_club_id = ""
var season_seed = 1
var fixture_seed = 1
var service = null
var match = null
var home = {}
var away = {}
var eligible_players = []
var context = {}

func has_live_match_tomorrow(world, club_id):
	return not next_managed_fixture(world, club_id).is_empty()

func next_managed_fixture(world, club_id):
	if world.is_empty() or String(club_id) == "":
		return {}
	var season_runner = _instance(SEASON_RUNNER_PATH)
	if season_runner == null:
		return {}
	season_runner.call("assign_fixture_dates", world)
	var date = _next_date(String(world.get("date", "2026-07-01")))
	if date == "":
		return {}
	var season_year = int(world.get("season_year", 2026))
	if date >= "%04d-07-01" % (season_year + 1):
		return {}
	for row in world.get("fixtures", []):
		if bool(row.get("played", false)) or String(row.get("date", "")) != date:
			continue
		if String(row.get("home_club_id", "")) == String(club_id) or String(row.get("away_club_id", "")) == String(club_id):
			return row
	return {}

func start(world, club_id, seed):
	managed_club_id = String(club_id)
	season_seed = int(seed)
	fixture = next_managed_fixture(world, managed_club_id)
	if fixture.is_empty():
		return {"error": ERR_DOES_NOT_EXIST}
	target_date = String(fixture.get("date", ""))
	service = _instance(MATCHDAY_SERVICE_PATH)
	if service == null:
		return {"error": ERR_CANT_CREATE, "message": "Matchday service unavailable."}
	service.call("_build_indexes", world)
	home = service.call("_club", world, String(fixture.get("home_club_id", "")))
	away = service.call("_club", world, String(fixture.get("away_club_id", "")))
	if home.is_empty() or away.is_empty():
		return {"error": ERR_INVALID_DATA}
	var competition_id = String(fixture.get("competition_id", ""))
	eligible_players = service.call("_eligible_match_players", world, String(home.get("id", "")), String(away.get("id", "")), competition_id)
	context = service.call("_match_context", world, fixture, home, away)
	fixture_seed = int(service.call("_fixture_seed", season_seed, String(fixture.get("id", ""))))
	match = _instance(MATCH_SESSION_PATH)
	if match == null:
		return {"error": ERR_CANT_CREATE, "message": "Managed match session unavailable."}
	var started = match.call("start_match", home, away, eligible_players, fixture_seed, context)
	if not started is Dictionary:
		return {"error": ERR_INVALID_DATA}
	started["fixture"] = fixture.duplicate(true)
	started["home_name"] = String(home.get("name", "Home"))
	started["away_name"] = String(away.get("name", "Away"))
	started["managed_side"] = "home" if String(home.get("id", "")) == managed_club_id else "away"
	return started

func advance(target_minute):
	if match == null:
		return {"error": ERR_UNCONFIGURED}
	return match.call("advance_to_minute", int(target_minute))

func substitute(player_out, player_in):
	if match == null:
		return ERR_UNCONFIGURED
	var side = "home" if String(home.get("id", "")) == managed_club_id else "away"
	return int(match.call("make_substitution", side, String(player_out), String(player_in)))

func change_tactic(tactic):
	if match == null:
		return ERR_UNCONFIGURED
	var side = "home" if String(home.get("id", "")) == managed_club_id else "away"
	return int(match.call("change_tactic", side, tactic))

func snapshot():
	if match == null:
		return {"error": ERR_UNCONFIGURED}
	var data = match.call("snapshot")
	if not data is Dictionary:
		return {"error": ERR_INVALID_DATA}
	data["fixture"] = fixture.duplicate(true)
	data["home_name"] = String(home.get("name", "Home"))
	data["away_name"] = String(away.get("name", "Away"))
	data["managed_side"] = "home" if String(home.get("id", "")) == managed_club_id else "away"
	return data

func commit(world):
	if match == null or fixture.is_empty() or service == null:
		return {"error": ERR_UNCONFIGURED}
	var result = match.call("finish_match")
	if not result is Dictionary:
		return {"error": ERR_INVALID_DATA}
	if result.has("error"):
		return result
	service.call("_build_indexes", world)
	fixture["played"] = true
	fixture["home_goals"] = int(result.get("home_goals", 0))
	fixture["away_goals"] = int(result.get("away_goals", 0))
	var stats_service = _instance(PLAYER_STATS_PATH)
	if stats_service != null:
		stats_service.call("record_match", world, fixture, result)
	service.call("_apply_dressing_room_result", world, home, away, result)
	service.call("_apply_match_load", world, result)
	service.call("_apply_suspensions", world, fixture, result, target_date)
	service.call("_update_club_form", world, home, away, result)
	var tier_policy = load(TIER_POLICY_PATH)
	var user_tier = 0
	if tier_policy != null:
		var tier_value = tier_policy.get("USER_LEAGUE")
		if tier_value != null:
			user_tier = int(tier_value)
	result["injuries"] = service.call("_apply_match_injuries", world, fixture, result, user_tier, fixture_seed, managed_club_id)
	service.call("_emit_match_events", world, fixture, result, user_tier, "managed_incremental_2d", target_date)
	service.call("_add_match_message", world, home, away, result, managed_club_id)
	world["last_managed_match"] = {"fixture": fixture.duplicate(true), "result": result.duplicate(true), "date": target_date, "model": "managed_incremental_2d", "simulation_tier": user_tier}
	var knockout = _instance(KNOCKOUT_PATH)
	if knockout != null:
		knockout.call("advance_ready", world, String(fixture.get("competition_id", "")), target_date)
	var background = service.call("play_date", world, target_date, managed_club_id, season_seed)
	if not background is Array:
		background = []
	var all_results = [{"fixture": fixture, "result": result, "match_seed": fixture_seed, "detailed": true, "model": "managed_incremental_2d", "simulation_tier": user_tier}]
	all_results.append_array(background)
	var services = {}
	var daily = _instance(DAILY_SERVICES_PATH)
	if daily != null:
		var daily_result = daily.call("run", world, managed_club_id, season_seed)
		if daily_result is Dictionary:
			services = daily_result
	var recruitment = _instance(RECRUITMENT_DAILY_PATH)
	if recruitment != null:
		services["recruitment"] = recruitment.call("run", world, managed_club_id, season_seed + 41003)
	var messages = []
	var inbox = _instance(INBOX_PATH)
	if inbox != null:
		var message_result = inbox.call("generate_daily", world, all_results)
		if message_result is Array:
			messages = message_result
	var news = {}
	var news_consumer = _instance(NEWS_CONSUMER_PATH)
	if news_consumer != null:
		var news_result = news_consumer.call("consume", world)
		if news_result is Dictionary:
			news = news_result
	return {"date": target_date, "fixtures_played": all_results.size(), "results": all_results, "services": services, "messages": messages, "news": news, "managed_result": result}

func _next_date(date_string):
	var parts = String(date_string).split("-")
	if parts.size() != 3:
		return ""
	var calendar = _instance(CALENDAR_PATH)
	if calendar == null:
		return ""
	calendar.call("set_date", int(parts[0]), int(parts[1]), int(parts[2]))
	calendar.call("advance_days", 1)
	return String(calendar.call("get_date_string"))

func _instance(path):
	var script = load(String(path))
	if script == null:
		return null
	return script.new()
