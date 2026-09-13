extends RefCounted

const MATCHDAY_SERVICE_PATH = "res://application/career/career_matchday_service.gd"
const PLAYER_STATS_PATH = "res://application/career/player_stats_service.gd"
const DAILY_SERVICES_PATH = "res://application/career/daily_services.gd"
const RECRUITMENT_DAILY_PATH = "res://application/career/recruitment_daily.gd"
const INBOX_PATH = "res://application/career/inbox_service.gd"
const NEWS_CONSUMER_PATH = "res://application/career/news_event_consumer.gd"
const KNOCKOUT_PATH = "res://application/season/knockout_season.gd"

func commit(world, fixture, result, home, away, managed_club_id, target_date, season_seed, fixture_seed):
	if not world is Dictionary or not fixture is Dictionary or not result is Dictionary:
		return {"error": ERR_INVALID_DATA}
	var service = _instance(MATCHDAY_SERVICE_PATH)
	if service == null:
		return {"error": ERR_CANT_CREATE, "message": "Matchday service unavailable."}
	service.call("_build_indexes", world)
	fixture["played"] = true
	fixture["home_goals"] = int(result.get("home_goals", 0))
	fixture["away_goals"] = int(result.get("away_goals", 0))
	var stats = _instance(PLAYER_STATS_PATH)
	if stats != null:
		stats.call("record_match", world, fixture, result)
	service.call("_apply_dressing_room_result", world, home, away, result)
	service.call("_apply_match_load", world, result)
	service.call("_apply_suspensions", world, fixture, result, String(target_date))
	service.call("_update_club_form", world, home, away, result)
	var user_tier = 0
	result["injuries"] = service.call("_apply_match_injuries", world, fixture, result, user_tier, int(fixture_seed), String(managed_club_id))
	service.call("_emit_match_events", world, fixture, result, user_tier, "managed_incremental_2d", String(target_date))
	service.call("_add_match_message", world, home, away, result, String(managed_club_id))
	world["last_managed_match"] = {
		"fixture": fixture.duplicate(true),
		"result": result.duplicate(true),
		"date": String(target_date),
		"model": "managed_incremental_2d",
		"simulation_tier": user_tier
	}
	var knockout = _instance(KNOCKOUT_PATH)
	if knockout != null:
		knockout.call("advance_ready", world, String(fixture.get("competition_id", "")), String(target_date))
	# The managed fixture is already played, so the normal service processes only
	# the other fixtures scheduled on this date.
	var background = service.call("play_date", world, String(target_date), String(managed_club_id), int(season_seed))
	if not background is Array:
		background = []
	var all_results = [{
		"fixture": fixture,
		"result": result,
		"match_seed": int(fixture_seed),
		"detailed": true,
		"model": "managed_incremental_2d",
		"simulation_tier": user_tier
	}]
	all_results.append_array(background)
	var services = {}
	var daily = _instance(DAILY_SERVICES_PATH)
	if daily != null:
		var daily_result = daily.call("run", world, String(managed_club_id), int(season_seed))
		if daily_result is Dictionary:
			services = daily_result
	var recruitment = _instance(RECRUITMENT_DAILY_PATH)
	if recruitment != null:
		services["recruitment"] = recruitment.call("run", world, String(managed_club_id), int(season_seed) + 41003)
	var messages = []
	var inbox = _instance(INBOX_PATH)
	if inbox != null:
		var message_result = inbox.call("generate_daily", world, all_results)
		if message_result is Array:
			messages = message_result
	var news = {}
	var consumer = _instance(NEWS_CONSUMER_PATH)
	if consumer != null:
		var news_result = consumer.call("consume", world)
		if news_result is Dictionary:
			news = news_result
	return {
		"date": String(target_date),
		"fixtures_played": all_results.size(),
		"results": all_results,
		"services": services,
		"messages": messages,
		"news": news,
		"managed_result": result
	}

func _instance(path):
	var script = load(String(path))
	return null if script == null else script.new()
